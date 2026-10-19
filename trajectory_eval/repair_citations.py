#!/usr/bin/env python3
"""Audit/recover citation serialization and location errors without another API call.

Never changes labels, outcomes, reasoning, methods or substantive claims. Corrected
annotations must pass the original strict validator. Original responses and failed
attempt metadata remain untouched. No fuzzy matching or independent grades are used.
"""
import argparse
import copy
from collections import Counter
import json
from pathlib import Path
import re

import run as pipeline


def parse_annotation(text, schema):
    """Recover only exact repeated field prefixes and a missing object delimiter."""
    try:
        return json.loads(text), []
    except json.JSONDecodeError:
        pass
    variants = [(text, [])]
    key = ',"final_version":'
    positions = [m.start() for m in re.finditer(re.escape(key), text)]
    for start, end in zip(positions, positions[1:]):
        repeated = text[start:end]
        if text.startswith(repeated, end):
            variants.append((text[:start] + text[end:], [{
                "rule": "remove_identical_unclosed_field_prefix", "offset": start,
                "removed": repeated, "identical_copy_offset": end}]))
    candidates = {}
    for candidate, changes in variants:
        choices = [(candidate, changes)]
        for match in re.finditer(r'\],\s*"self_check"\s*:', candidate):
            offset = match.start() + 1
            choices.append((candidate[:offset] + '}' + candidate[offset:], changes + [{
                "rule": "close_final_version_before_self_check", "offset": offset,
                "inserted": "}"}]))
        for repaired, edits in choices:
            try:
                value = json.loads(repaired)
                pipeline.jsonschema.validate(value, schema)
            except (ValueError, pipeline.jsonschema.ValidationError):
                continue
            candidates[pipeline.dump(value)] = (value, edits)
    if len(candidates) != 1:
        raise ValueError("JSON syntax has no unique schema-valid formatting recovery")
    return next(iter(candidates.values()))


def presentation_text(text):
    """Normalize presentation only, retaining offsets back to the exact source."""
    chars = [(char, i, i + 1) for i, char in enumerate(text)]

    def replace(pattern, replacement):
        nonlocal chars
        current = ''.join(c[0] for c in chars)
        result, cursor = [], 0
        for match in re.finditer(pattern, current, re.MULTILINE):
            result.extend(chars[cursor:match.start()])
            value = replacement(match)
            result.extend((c, chars[match.start()][1], chars[match.end() - 1][2]) for c in value)
            cursor = match.end()
        result.extend(chars[cursor:])
        chars = result

    # Remove paired Markdown delimiters, not arithmetic operators or arbitrary words.
    # Preserve per-character offsets within the enclosed text.
    while True:
        current = ''.join(c[0] for c in chars)
        remove = set()
        for match in re.finditer(r'(\*\*|`+)(?=\S)([^\n]*?\S)\1', current):
            first, last = match.start(2), match.end(2) - 1
            chars[first] = (chars[first][0], chars[match.start()][1], chars[first][2])
            chars[last] = (chars[last][0], chars[last][1], chars[match.end() - 1][2])
            remove.update(range(match.start(), first))
            remove.update(range(last + 1, match.end()))
        if not remove:
            break
        chars = [c for i, c in enumerate(chars) if i not in remove]
    replace(r'^\s*(?:\d+:\s*|[-*]\s+)', lambda m: '')
    replace('mm³', lambda m: 'mm^3')
    replace(r'\s+', lambda m: ' ')
    return ''.join(c[0] for c in chars), chars


def restore_presentation(text, quote):
    target, _ = presentation_text(quote)
    source, offsets = presentation_text(text)
    if not target.strip():
        return None
    matches = set()
    start = source.find(target)
    while start >= 0:
        literal = text[offsets[start][1]:offsets[start + len(target) - 1][2]]
        if presentation_text(literal)[0] == target:
            matches.add(literal)
        start = source.find(target, start + 1)
    return next(iter(matches)) if len(matches) == 1 else None


def citation_sections(annotation):
    for dim in annotation["dimensions"]:
        for field, citations in [("evidence", dim["evidence"]),
                                 ("final_version.evidence", dim["final_version"]["evidence"]),
                                 ("self_check.evidence", dim["self_check"]["evidence"])]:
            for i, citation in enumerate(citations):
                yield f"{dim['dimension']}.{field}[{i}]", citation


def without_evidence(value):
    if isinstance(value, dict):
        return {k: without_evidence(v) for k, v in value.items() if k != "evidence"}
    if isinstance(value, list):
        return [without_evidence(v) for v in value]
    return value


def restore_line_numbers(text, quote):
    """Map a unique quote back across numeric line prefixes, preserving content."""
    clean, offsets = [], []
    source_offset = 0
    for line in text.splitlines(keepends=True):
        match = re.match(r"^\d+: ", line)
        skip = match.end() if match else 0
        clean.append(line[skip:])
        offsets.extend(range(source_offset + skip, source_offset + len(line)))
        source_offset += len(line)
    stripped = "".join(clean)
    start = stripped.find(quote)
    if not quote or start < 0 or stripped.find(quote, start + 1) >= 0:
        return None
    original = text[offsets[start]:offsets[start + len(quote) - 1] + 1]
    return original if original != quote else None


def recover(annotation, packet):
    result = copy.deepcopy(annotation)
    events = {event["id"]: event for event in packet["events"]}
    changes, unresolved = [], []
    for location, citation in citation_sections(result):
        original = copy.deepcopy(citation)
        event = events.get(citation["event_id"])
        quote = citation["quote"]
        if event and quote in event["text"]:
            continue
        candidates = []
        if event:
            presented = restore_presentation(event["text"], quote)
            if presented and presented != quote:
                candidates.append(("restore_source_presentation", event, presented))
            # A final JSON property has no comma; preserve its key and numeric value.
            if re.fullmatch(r'"[^"\n]+"\s*:\s*-?\d+(?:\.\d+)?,', quote):
                if quote[:-1] in event["text"]:
                    candidates.append(("remove_final_json_property_comma", event, quote[:-1]))
            escaped = json.dumps(quote, ensure_ascii=False)[1:-1]
            # Proves this is JSON representation only, not paraphrasing.
            if escaped != quote and escaped in event["text"]:
                assert json.loads('"' + escaped + '"') == quote
                candidates.append(("json_string_representation", event, escaped))
            if event["kind"] == "tool_result":
                numbered = restore_line_numbers(event["text"], quote)
                if numbered:
                    candidates.append(("restore_tool_line_numbers", event, numbered))
            match = re.match(r"^([A-Za-z_][\w.-]*\.(?:stl|scad|json|md))(?=[:：\s])", quote)
            if match:
                with_ticks = "`" + match[1] + "`" + quote[match.end():]
                if with_ticks in event["text"]:
                    candidates.append(("restore_markdown_backticks", event, with_ticks))
            # A common error is citing a command's result instead of its paired action.
            if citation["role"] == "action" and event["kind"] == "tool_result" and event["call_id"]:
                paired = [e for e in events.values() if e["kind"] == "tool_call" and
                          e["call_id"] == event["call_id"] and quote in e["text"]]
                if len(paired) == 1:
                    candidates.append(("paired_action_event_id", paired[0], quote))
            elif citation["role"] == "result" and event["kind"] == "tool_call" and event["call_id"]:
                paired = [e for e in events.values() if e["kind"] == "tool_result" and
                          e["call_id"] == event["call_id"] and quote in e["text"]]
                if len(paired) == 1:
                    candidates.append(("paired_result_event_id", paired[0], quote))
        # Only use a globally relocated quote if it occurs in exactly one event.
        exact = [e for e in events.values() if quote in e["text"]]
        if len(exact) == 1:
            target = exact[0]
            needed = {"action": "tool_call", "result": "tool_result"}.get(citation["role"])
            if needed is None or target["kind"] == needed:
                candidates.append(("unique_literal_event_id", target, quote))
        unique = {(e["id"], q): (rule, e, q) for rule, e, q in candidates}
        if len(unique) != 1:
            unresolved.append({"location": location, "citation": original,
                               "reason": "no provable correction" if not unique else "ambiguous correction"})
            continue
        rule, target, new_quote = next(iter(unique.values()))
        citation["event_id"], citation["quote"] = target["id"], new_quote
        changes.append({"location": location, "rule": rule, "before": original,
                        "after": copy.deepcopy(citation)})
    if without_evidence(result) != without_evidence(annotation):
        raise AssertionError("Substantive Judge fields changed")
    return result, changes, unresolved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--judge-id", required=True)
    parser.add_argument("--apply", action="store_true", help="save recoverable annotations; default is report only")
    args = parser.parse_args()
    run = args.run_dir.resolve()
    judge = run / "judges" / args.judge_id
    if not judge.is_dir():
        parser.error("Judge directory does not exist")
    manifest = pipeline.read(run / "private/manifest.json")
    schema = pipeline.read(run / "protocol/output.schema.json")
    report = {"created_at": pipeline.now(), "apply": args.apply, "judge_id": args.judge_id,
              "api_calls": 0, "cases": []}
    for case in manifest["cases"]:
        cid = case["case_id"]
        accepted = judge / "annotations" / f"{cid}.json"
        if accepted.exists():
            continue
        attempts = sorted((judge / "attempts" / cid).glob("*/metadata.json"))
        if not attempts:
            continue
        attempt = attempts[-1].parent
        meta = pipeline.read(attempt / "metadata.json")
        # Never touch a running attempt or reinterpret a network failure as a label.
        if meta.get("status") != "error" or not (attempt / "response.json").exists():
            continue
        raw = pipeline.read(attempt / "response.json")
        try:
            choice = raw["choices"][0]
            if choice.get("finish_reason") != "stop":
                continue
            original, syntax_changes = parse_annotation(choice["message"]["content"], schema)
            pipeline.jsonschema.validate(original, schema)
        except (KeyError, IndexError, ValueError, pipeline.jsonschema.ValidationError):
            continue
        if original["case_id"] != cid:
            continue
        packet = pipeline.read(run / "inputs" / f"{cid}.json")
        if pipeline.sha(run / "inputs" / f"{cid}.json") != case["input_sha256"]:
            raise ValueError(f"Input hash mismatch: {cid}")
        corrected, changes, unresolved = recover(original, packet)
        valid, error = False, None
        try:
            pipeline.check_annotation(corrected, packet, schema)
            valid = True
        except (ValueError, pipeline.jsonschema.ValidationError) as exc:
            error = str(exc)
        folder = judge / "citation_review" / cid / attempt.name
        pipeline.write(folder / "original_annotation.json", original)
        pipeline.write(folder / "corrected_candidate.json", corrected)
        record = {"case_id": cid, "attempt": attempt.name, "original_response": str((attempt / "response.json").relative_to(run)),
                  "original_response_sha256": pipeline.sha(attempt / "response.json"),
                  "input_sha256": case["input_sha256"], "protocol_sha256": manifest["protocol_sha256"],
                  "script_sha256": pipeline.sha(__file__), "changes": changes, "unresolved": unresolved,
                  "syntax_changes": syntax_changes,
                  "strict_validation_passed": valid, "validation_error": error,
                  "substantive_fields_unchanged": True, "human_review": "pending", "applied": False}
        if args.apply and valid and not unresolved:
            accepted.parent.mkdir(parents=True, exist_ok=True)
            try:
                with accepted.open("x") as stream:
                    stream.write(pipeline.dump(corrected) + "\n")
                record["applied"] = True
                record["annotation_sha256"] = pipeline.sha(accepted)
                pipeline.write(judge / "annotations_meta" / f"{cid}.json", {
                    "origin": "citation_representation_recovery", "review_record": str((folder / "record.json").relative_to(run)),
                    "judgement_unchanged": True, "human_review": "pending"})
            except FileExistsError:
                record["note"] = "Another process created an annotation; existing annotation kept"
        pipeline.write(folder / "record.json", record)
        report["cases"].append(record)
        print(f"{cid}: {len(syntax_changes)} JSON repairs; {len(changes)} citation corrections; unresolved={len(unresolved)}; "
              f"strict_valid={valid}; applied={record['applied']}")
    pipeline.write(judge / "citation_review/latest_report.json", report)
    counts = Counter(change["rule"] for case in report["cases"] for change in case["changes"])
    lines = ["# 引用校验诊断与恢复", "", f"时间：{report['created_at']}。本次不调用模型 API。", "",
             "原始响应、失败元数据、标签和判断保持不变；只修正可以严格证明的引用表示或定位。所有标注仍待人工复核。", "",
             "| case | JSON修正 | 引用修正 | 无法确定 | 原严格校验 | 已保存标注 |", "|---|---:|---:|---:|---|---|"]
    for case in report["cases"]:
        lines.append(f"| {case['case_id']} | {len(case['syntax_changes'])} | {len(case['changes'])} | {len(case['unresolved'])} | {case['strict_validation_passed']} | {case['applied']} |")
    lines += ["", "修正规则计数："] + [f"- {key}: {count}" for key, count in counts.items()]
    (judge / "citation_review/latest_report.md").write_text("\n".join(lines) + "\n")
    print("Report:", judge / "citation_review/latest_report.md")


if __name__ == "__main__":
    main()
