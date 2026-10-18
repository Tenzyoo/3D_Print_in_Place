#!/usr/bin/env python3
"""Offline material audit: schemas, citations, raw snapshots and byte-exact reconstruction.

Does not execute logged commands, call a Judge, or invent annotation results.
"""
import argparse
from collections import Counter
from pathlib import Path
import tempfile

import run as pipeline


def audit(run):
    manifest = pipeline.read(run / "private/manifest.json")
    implementation_manifest = run / "private/implementation/manifest.json"
    if implementation_manifest.exists():
        for name, digest in pipeline.read(implementation_manifest).items():
            if pipeline.sha(implementation_manifest.parent / name) != digest:
                raise ValueError(f"Frozen implementation changed: {name}")
        if pipeline.sha(implementation_manifest.parent / "run.py") != manifest["preparer_sha256"]:
            raise ValueError("Frozen preparer differs from the version used to prepare materials")
    expected = {c["case_id"] for c in manifest["cases"]}
    if len(expected) != len(manifest["cases"]):
        raise ValueError("Duplicate case IDs")
    schema = pipeline.read(run / "protocol/input.schema.json")
    pipeline.jsonschema.Draft202012Validator.check_schema(schema)
    pipeline.jsonschema.Draft202012Validator.check_schema(pipeline.read(run / "protocol/output.schema.json"))
    if pipeline.protocol_digest(run) != manifest["protocol_sha256"]:
        raise ValueError("Frozen protocol hash mismatch")
    required_protocols = {"common.md", "C1_separation.md", "C2_clearance.md", "C3_motion.md", "C4_retention.md"}
    if {p.name for p in (run / "protocol/prompts").glob("*.md")} != required_protocols:
        raise ValueError("Missing or unexpected frozen prompts")
    for folder in ["inputs", "requests", "private/source_maps", "private/grades", "private/restoration"]:
        actual = {p.stem for p in (run / folder).glob("*.json")}
        if actual != expected:
            raise ValueError(f"Case inventory mismatch in {folder}: {actual ^ expected}")
    if {p.name for p in (run / "private/raw").iterdir() if p.is_dir()} != expected:
        raise ValueError("Raw snapshot inventory mismatch")
    group_counts = Counter(c["group"] for c in manifest["cases"])
    groups = pipeline.ALL_GROUPS if manifest["scope"] == "all" else pipeline.FOUR_GROUPS
    actual_pairs = {(c["group"], c["task"]) for c in manifest["cases"]}
    if actual_pairs != {(g, t) for g in groups for t in pipeline.TASKS}:
        raise ValueError("Missing or duplicate group/task combination")
    report = {"created_at": pipeline.now(), "run_dir": str(run), "materials_ready": False,
              "judge_calls_made_by_audit": 0, "groups": dict(group_counts), "cases": [],
              "limitations": ["字节级复原只针对已保存日志及规范化输入，不表示恢复每次完整 API 请求。",
                              "不复原已被覆盖的中间 CAD 版本；子 Agent、图像等限制以输入 warnings 为准。",
                              "本地准备完整性与真实 Judge 接口可用性是两项检查，本审计不测试远程接口。"]}
    for case in manifest["cases"]:
        cid = case["case_id"]
        input_path = run / "inputs" / f"{cid}.json"
        request_path = run / "requests" / f"{cid}.json"
        packet = pipeline.read(input_path)
        pipeline.jsonschema.validate(packet, schema)
        if pipeline.sha(input_path) != case["input_sha256"] or pipeline.sha(request_path) != case["request_sha256"]:
            raise ValueError(f"Input/request hash mismatch: {cid}")
        if packet["case_id"] != cid:
            raise ValueError(f"Wrong packet ID: {cid}")
        ids = [e["id"] for e in packet["events"]]
        maps = pipeline.read(run / "private/source_maps" / f"{cid}.json")
        if len(ids) != len(set(ids)) or ids != [row["event_id"] for row in maps]:
            raise ValueError(f"Evidence/source map mismatch: {cid}")
        restored = pipeline.restore_case(run, cid)
        if restored != packet:
            raise ValueError(f"Raw-source reconstruction differs: {cid}")
        rebuilt_request = pipeline.request_for_packet(run, restored)
        if rebuilt_request != pipeline.read(request_path):
            raise ValueError(f"Restored request differs: {cid}")
        # Test byte-for-byte JSON serialization too, not just semantic equality.
        with tempfile.TemporaryDirectory(prefix="trajectory_audit_") as tmp:
            dest = Path(tmp)
            pipeline.write(dest / "input.json", restored)
            pipeline.write(dest / "request.json", rebuilt_request)
            if pipeline.sha(dest / "input.json") != case["input_sha256"] or pipeline.sha(dest / "request.json") != case["request_sha256"]:
                raise ValueError(f"Byte-level reconstruction mismatch: {cid}")
        grade_path = run / "private/grades" / f"{cid}.json"
        if pipeline.sha(grade_path) != case["grade_sha256"]:
            raise ValueError(f"Independent score changed: {cid}")
        grade = pipeline.read(grade_path)
        if not grade or any(grade.get(f"c{i}") not in (0, 1) for i in range(1, 5)):
            raise ValueError(f"Missing formal four-dimension grade: {cid}")
        # Judge payload contains protocol and evidence only, never the private envelope.
        if set(packet) != {"schema_version", "case_id", "task_instruction", "warnings", "events"}:
            raise ValueError(f"Unexpected payload fields: {cid}")
        recipe = pipeline.read(run / case["restoration"]["recipe"])
        frozen_grade = next(f for f in recipe["files"] if f["role"] == "independent_grade")
        if pipeline.read(run / frozen_grade["snapshot"]) != grade:
            raise ValueError(f"Frozen grade copies disagree: {cid}")
        result_file = next(f for f in recipe["files"] if f["role"] == "trial_result")
        result = pipeline.read(run / result_file["snapshot"])
        if not result.get("finished_at") or result.get("exception_info"):
            raise ValueError(f"Selected trial did not end normally: {cid}")
        continuation = case.get("continuation")
        intervention_events = [e for e in packet["events"] if e["kind"] == "intervention"]
        if continuation:
            previous = next(f for f in recipe["files"] if f["role"] == "continuation_original_prefix")
            current = next(f for f in recipe["files"] if f["role"] == "trajectory_source")
            if not (run / current["snapshot"]).read_bytes().startswith((run / previous["snapshot"]).read_bytes()):
                raise ValueError(f"Archived continuation lost original prefix: {cid}")
            if [e["text"] for e in intervention_events] != continuation["manual_messages"]:
                raise ValueError(f"Manual continuation evidence missing: {cid}")
        calls = {e["call_id"] for e in packet["events"] if e["kind"] == "tool_call"}
        results = {e["call_id"] for e in packet["events"] if e["kind"] == "tool_result"}
        missing_results, missing_calls = sorted(calls - results), sorted(results - calls)
        for call_id in missing_results + missing_calls:
            if not any(call_id in warning for warning in packet["warnings"]):
                raise ValueError(f"Unreported evidence gap: {cid}:{call_id}")
        live_source = Path(case["source_file"])
        if live_source.exists() and pipeline.sha(live_source) != case["source_sha256"]:
            raise ValueError(f"Live original source changed: {cid}")
        report["cases"].append({"case_id": cid, "group": case["group"], "task": case["task"],
             "events": len(ids), "raw_files": len(recipe["files"]), "input_bytes": input_path.stat().st_size,
             "request_bytes": request_path.stat().st_size, "raw_restore": "byte_exact",
             "missing_tool_results": missing_results, "missing_tool_calls": missing_calls,
             "manual_continue": bool(continuation), "warnings": packet["warnings"]})
    report["materials_ready"] = True
    report["n_cases"] = len(report["cases"])
    report["n_dimensions"] = len(report["cases"]) * 4
    report["n_events"] = sum(c["events"] for c in report["cases"])
    report["n_raw_files"] = sum(c["raw_files"] for c in report["cases"])
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, required=True)
    args = parser.parse_args()
    run = args.run_dir.resolve()
    try:
        report = audit(run)
    except Exception as exc:
        pipeline.write(run / "audit/failure.json", {"created_at": pipeline.now(), "materials_ready": False,
                                                    "error": f"{type(exc).__name__}: {exc}"})
        parser.exit(1, f"Audit failed: {exc}\n")
    pipeline.write(run / "audit/report.json", report)
    lines = ["# 打标材料完整性审计", "", "状态：通过（材料已准备，未调用真实 Judge）。", "",
             f"- {report['n_cases']} 条 case，{report['n_dimensions']} 个待标注维度，{report['n_events']} 个证据事件。",
             f"- {report['n_raw_files']} 份原始材料快照均已校验。",
             "- 每条 input 和 request 均从 private 原始快照成功逐字节复原。",
             "- 输入 Schema、证据定位、评分隔离、冻结哈希和人工续跑前缀均已核对。", "",
             "| case | group | task | events | restore | missing results | manual continue |",
             "|---|---|---|---:|---|---:|---|"]
    for c in report["cases"]:
        lines.append(f"| {c['case_id']} | {c['group']} | {c['task']} | {c['events']} | byte exact | {len(c['missing_tool_results'])} | {c['manual_continue']} |")
    lines += ["", "已知范围限制："] + ["- " + text for text in report["limitations"]]
    (run / "audit/report.md").write_text("\n".join(lines) + "\n")
    print(f"Audit passed: {report['n_cases']} cases, {report['n_events']} events, {report['n_raw_files']} raw snapshots; byte-exact reconstruction")


if __name__ == "__main__":
    main()
