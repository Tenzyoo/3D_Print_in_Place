#!/usr/bin/env python3
"""Apply the user-authorized, case-specific evidence review for the frozen v2 run.

This is an assistant-reviewed correction, separate from deterministic formatting
recovery. Raw responses, labels and judgments stay unchanged; human review remains
pending. All three candidates must pass the original validator before any is saved.
"""
import copy
import json
from pathlib import Path

import repair_citations as repair
import run as pipeline


def main():
    run = pipeline.HERE / "runs/kin_all_groups_v2"
    judge = run / "judges/deepseek_flash_high_v1"
    manifest = pipeline.read(run / "private/manifest.json")
    prepared = []
    for cid in ("case_015", "case_027", "case_034"):
        folder = judge / "citation_review" / cid / "001"
        candidate = pipeline.read(folder / "corrected_candidate.json")
        original = copy.deepcopy(candidate)
        raw_path = judge / "attempts" / cid / "001/response.json"
        raw_annotation = json.loads(pipeline.read(raw_path)["choices"][0]["message"]["content"])
        _, packet, schema = pipeline.request_for(run, cid)
        source_case = next(c for c in manifest["cases"] if c["case_id"] == cid)
        if pipeline.sha(run / "inputs" / f"{cid}.json") != source_case["input_sha256"]:
            raise ValueError(f"Frozen input changed: {cid}")
        events = {e["id"]: e for e in packet["events"]}
        dims = {d["dimension"]: d for d in candidate["dimensions"]}
        changes = []

        def replace(citation, event_id, quote, location, reason):
            before = copy.deepcopy(citation)
            assert quote in events[event_id]["text"], (cid, location)
            citation.update(event_id=event_id, quote=quote)
            changes.append({"location": location, "before": before,
                            "after": copy.deepcopy(citation), "reason": reason})

        if cid == "case_015":
            citation = dims["C4"]["self_check"]["evidence"][0]
            assert "上蘑菇形防脱帽" in citation["quote"]
            replace(citation, "E00205", citation["quote"].replace("上蘑菇形防脱帽", "上蘑菇形帽"),
                    "C4.self_check.evidence[0]", "Replace the paraphrased noun with the literal source wording.")
        elif cid == "case_027":
            action, result = events["E00054"], events["E00055"]
            assert action["kind"] == "tool_call" and result["kind"] == "tool_result"
            assert action["call_id"] == result["call_id"]
            info = "prusa-slicer --info /app/output/model.stl /app/output/parts/parts_1.stl /app/output/parts/parts_2.stl /app/output/parts/parts_3.stl /app/output/parts/parts_4.stl"
            start = action["text"].index("trimesh.boolean.intersection")
            tail = "round(float(v),7))"
            end = action["text"].index(tail, start) + len(tail)
            for quote in (info, action["text"][start:end]):
                assert quote in action["text"] and len(quote) <= 1000
                citation = {"event_id": "E00054", "role": "action", "quote": quote}
                index = len(dims["C1"]["evidence"])
                dims["C1"]["evidence"].append(citation)
                changes.append({"location": f"C1.evidence[{index}]", "before": None,
                                "after": citation, "reason": "Cite the existing check command paired with the already-cited E00055 results."})
            for dim in ("C3", "C4"):
                citation = dims[dim]["final_version"]["evidence"][0]
                assert citation["quote"] == "openscad -o /app/output/model.scad"
                replace(citation, "E00052", "openscad -o /app/output/model.stl /app/output/model.scad",
                        f"{dim}.final_version.evidence[0]", "Restore the actual STL output path and SCAD input path from the same export command.")
        else:
            assert events["E00029"]["call_id"] == events["E00030"]["call_id"]
            replace(dims["C2"]["final_version"]["evidence"][0], "E00029",
                    "gap = outer_inner_wall_r - inner_outer_wall_r", "C2.final_version.evidence[0]",
                    "Use the actual assignment variable gap and the paired action event; the subtraction is unchanged.")
            citation = dims["C4"]["final_version"]["evidence"][0]
            replace(citation, "E00029", json.dumps(citation["quote"], ensure_ascii=False)[1:-1],
                    "C4.final_version.evidence[0]", "Point to the paired command and preserve its literal JSON escaping.")

        assert repair.without_evidence(original) == repair.without_evidence(candidate)
        assert repair.without_evidence(raw_annotation) == repair.without_evidence(candidate)
        pipeline.check_annotation(candidate, packet, schema)
        dest = judge / "annotations" / f"{cid}.json"
        if dest.exists() and pipeline.read(dest) != candidate:
            raise ValueError(f"An existing annotation differs: {cid}")
        record = {"case_id": cid, "created_at": pipeline.now(), "reviewer": "assistant",
                  "review_scope": "evidence citations only; user authorized source-based correction",
                  "origin": "assistant_reviewed_citation_correction", "changes": changes,
                  "prior_formatting_record": str((folder / "record.json").relative_to(run)),
                  "original_response": str(raw_path.relative_to(run)),
                  "original_response_sha256": pipeline.sha(raw_path),
                  "input_sha256": source_case["input_sha256"],
                  "protocol_sha256": manifest["protocol_sha256"],
                  "script_sha256": pipeline.sha(__file__),
                  "substantive_fields_unchanged": True, "strict_validation_passed": True,
                  "human_review": "pending", "api_calls": 0}
        prepared.append((cid, folder, dest, candidate, record))

    for cid, folder, dest, candidate, record in prepared:
        pipeline.write(folder / "assistant_reviewed_candidate.json", candidate)
        if not dest.exists():
            with dest.open("x") as stream:
                stream.write(pipeline.dump(candidate) + "\n")
        record["annotation_sha256"] = pipeline.sha(dest)
        record["applied"] = True
        pipeline.write(folder / "assistant_review_record.json", record)
        pipeline.write(judge / "annotations_meta" / f"{cid}.json", {
            "origin": record["origin"], "review_record": str((folder / "assistant_review_record.json").relative_to(run)),
            "judgement_unchanged": True, "human_review": "pending"})
        print(f"{cid}: corrected {len(record['changes'])} citations; original strict validation passed; saved")


if __name__ == "__main__":
    main()
