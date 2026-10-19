import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from argparse import Namespace

SPEC = importlib.util.spec_from_file_location("trajectory_runner", Path(__file__).resolve().parents[1] / "run.py")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


def packet():
    return {"schema_version": "1.0", "case_id": "case_001", "task_instruction": "分离检查",
            "warnings": [], "events": [
                {"id": "E00001", "kind": "tool_call", "call_id": "a", "tool": "bash", "text": "check.py"},
                {"id": "E00002", "kind": "tool_result", "call_id": "a", "tool": "", "text": "bodies=4 PASS"}]}


def annotation():
    return {"schema_version": "1.0", "case_id": "case_001", "dimensions": [
        {"dimension": d, "label": "unknown", "method": "", "outcome": "unknown", "evidence": [],
         "final_version": {"status": "unknown", "reason": "no version", "evidence": []},
         "self_check": {"verdict": "none", "target": "unknown", "evidence": []},
         "reason": "synthetic fixture only", "limitations": []} for d in runner.DIMS]}


class PipelineTests(unittest.TestCase):
    def test_gemini_raw_recovers_failed_results_and_deduplicates_updates(self):
        with tempfile.TemporaryDirectory() as tmp:
            trial = Path(tmp)
            path = trial / "agent/gemini-cli.trajectory.jsonl"
            path.parent.mkdir()
            call = {"id": "call_a", "name": "read_file", "args": {"file_path": "/outside"},
                    "result": [{"functionResponse": {"id": "call_a", "response": {"error": "denied"}}}]}
            records = [{"type": "gemini", "id": "msg1", "content": "", "toolCalls": [call]},
                       {"type": "gemini", "id": "msg1", "content": "", "toolCalls": [call]},
                       {"type": "user", "content": [{"functionResponse": {
                           "id": "call_a", "name": "read_file", "response": {"error": "permission denied"}}}]},
                       {"type": "gemini", "id": "msg2", "content": "finished"}]
            path.write_text("\n".join(json.dumps(e) for e in records))
            runner.write(trial / "agent/trajectory.json", {"steps": []})
            events, maps, _, source = runner.normalize(trial)
            self.assertEqual(source, path)
            self.assertEqual([e["kind"] for e in events], ["tool_call", "tool_result", "assistant"])
            self.assertIn("permission denied", events[1]["text"])
            self.assertEqual([runner.replay_event(source, row, {}) for row in maps], events)

    def test_private_snapshots_restore_without_original_trial_or_input(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            trial, run = base / "trial", base / "bundle"
            source = trial / "agent/trajectory.json"
            runner.write(source, {"steps": [{"source": "agent", "message": "done", "tool_calls": [
                {"tool_call_id": "x", "function_name": "bash", "arguments": {"command": "check"}}],
                "observation": {"results": [{"source_call_id": "x", "content": "PASS"}]}}]})
            for name in ["config.json", "result.json", "regrade/reward.json", "regrade/details.json"]:
                runner.write(trial / name, {"fixture": True})
            instruction = trial / "instruction.md"
            instruction.write_text("Test requirement")
            events, maps, warnings, source = runner.normalize(trial)
            p = {"schema_version": "1.0", "case_id": "case_001", "task_instruction": instruction.read_text(),
                 "warnings": warnings, "events": events}
            runner.write(run / "private/source_maps/case_001.json", maps)
            restoration = runner.freeze_raw_materials(run, "case_001", trial, source, instruction, p, maps, None)
            runner.write(run / "private/manifest.json", {"cases": [{"case_id": "case_001", "restoration": restoration}]})
            runner.shutil.rmtree(trial)
            self.assertEqual(runner.restore_case(run, "case_001"), p)

    def test_seven_group_selection_uses_latest_normal_attempt_not_grade(self):
        with tempfile.TemporaryDirectory() as tmp:
            job, reruns = Path(tmp) / "kin", Path(tmp) / "reruns"
            agents = {
                "deepseek_dsh": {"model_name": "deepseek/deepseek-flash", "import_path": "dsh_agent:DeepSeekHarness"},
                "claude_cc": {"model_name": "claude-opus-5-5", "name": "claude-code"},
                "gpt_codex": {"model_name": "gpt-6.1-sol", "name": "codex"},
                "gpt_dsh": {"model_name": "openai/gpt-6.1-sol", "import_path": "dsh_agent:DeepSeekHarness"},
                "claude_dsh": {"model_name": "anthropic/claude-opus-5-5", "import_path": "dsh_agent:DeepSeekHarness"},
                "gemini_dsh": {"model_name": "google/gemini-4-argon-high", "import_path": "dsh_agent:DeepSeekHarness"},
                "gemini_cli": {"model_name": "google/gemini-4-argon-high", "import_path": "gemini_agent:PinnedGeminiCli"},
            }
            for g, agent in agents.items():
                for task in runner.TASKS:
                    trial = job / f"{task}__{g}"
                    runner.write(trial / "config.json", {"agent": agent})
                    runner.write(trial / "result.json", {"task_name": task, "finished_at": "2026-10-18T10:00:00Z"})
            new = reruns / "rerun" / "kin1-dino-tail__new"
            runner.write(new / "config.json", {"agent": agents["gemini_cli"]})
            runner.write(new / "result.json", {"task_name": "kin1-dino-tail", "finished_at": "2026-10-18T11:00:00Z"})
            runner.write(new / "regrade/reward.json", {"pass": 0})
            bad = reruns / "rerun" / "kin1-dino-tail__bad"
            runner.write(bad / "config.json", {"agent": agents["gemini_cli"]})
            runner.write(bad / "result.json", {"task_name": "kin1-dino-tail", "finished_at": "2026-10-18T12:00:00Z",
                                                "exception_info": {"exception_type": "NetworkError"}})
            for suffix, marked in [("newer_marked", True), ("newer__deprecated", False)]:
                obsolete = job / f"kin1-dino-tail__{suffix}"
                runner.write(obsolete / "config.json", {"agent": agents["gemini_cli"]})
                runner.write(obsolete / "result.json", {"task_name": "kin1-dino-tail", "finished_at": "2026-10-19T12:00:00Z"})
                if marked:
                    (obsolete / "SUPERSEDED.md").write_text("Replaced by another run")
            selected, alternatives = runner.select_trials(job, reruns, "all")
            self.assertEqual(len(selected), 35)
            self.assertIn(new, [row[0] for row in selected])
            self.assertNotIn(bad, [row[0] for row in selected])
            self.assertEqual(len(alternatives[str(new)]), 2)
            self.assertEqual(len(runner.select_trials(job, reruns, "four")[0]), 20)

    def test_continue_keeps_original_prefix_and_intervention_without_duplication(self):
        with tempfile.TemporaryDirectory() as tmp:
            original, continued = Path(tmp) / "original", Path(tmp) / "continued"
            rel = Path("agent/dsh-home/sessions/app/s1/session.v4.jsonl")
            first = [{"type": "turn/start"}, {"type": "tool/call", "data": {
                "callId": "a", "name": "bash", "arguments": "original_check"}}]
            last = [{"type": "turn/start"}, {"type": "user/message", "data": {
                "source": {"kind": "user"}, "content": [{"type": "text", "text": "continue"}]}},
                {"type": "tool/result", "data": {"message": {"toolCallId": "a", "content": "PASS"}}}]
            for trial, events in [(original, first), (continued, first + last)]:
                (trial / rel).parent.mkdir(parents=True)
                (trial / rel).write_text("".join(json.dumps(e) + "\n" for e in events))
                (trial / "agent/dsh.jsonl").write_text('{"type":"session","sessionId":"s1"}\n')
            runner.write(continued / "agent/continue_manifest.json", {"mode": "manual continue",
                "resumed_from_path": str(original), "message": "continue", "continues": [{"index": 1}]})
            events, _, _, source = runner.normalize(continued)
            info = runner.continuation_info(continued, source)
            self.assertTrue(info["original_prefix_verified"])
            self.assertEqual([e["kind"] for e in events], ["tool_call", "intervention", "tool_result"])
            (original / rel).write_text("CHANGED")
            with self.assertRaisesRegex(ValueError, "original prefix"):
                runner.continuation_info(continued, source)

    def test_serialized_atif_image_is_not_sent_as_base64_text(self):
        block = {"type": "image", "source": {"type": "base64", "data": "synthetic_image_bytes"}}
        self.assertEqual(runner.text_content(json.dumps(block)), "[IMAGE_NOT_INCLUDED]")
        combined = json.dumps(block) + '\n\n[metadata] ' + json.dumps({"type": "image", "file": {"base64": "bytes"}})
        self.assertEqual(runner.text_content(combined), "[IMAGE_NOT_INCLUDED]\n\n[metadata] [IMAGE_NOT_INCLUDED]")

    def test_fabricated_citation_rejected(self):
        a = annotation()
        a["dimensions"][0]["evidence"] = [{"event_id": "E00002", "role": "result", "quote": "NOT IN LOG"}]
        with self.assertRaisesRegex(ValueError, "nonliteral"):
            runner.check_annotation(a, packet(), runner.schemas()[1])

    def test_verified_needs_actual_call_and_result(self):
        a = annotation()
        d = a["dimensions"][0]
        d.update(label="verified", outcome="pass")
        with self.assertRaisesRegex(ValueError, "action and result"):
            runner.check_annotation(a, packet(), runner.schemas()[1])
        d["evidence"] = [{"event_id": "E00001", "role": "action", "quote": "check.py"},
                         {"event_id": "E00002", "role": "result", "quote": "bodies=4 PASS"}]
        runner.check_annotation(a, packet(), runner.schemas()[1])

    def test_duplicate_dimensions_and_false_final_coverage_rejected(self):
        a = annotation()
        a["dimensions"][1]["dimension"] = "C1"
        with self.assertRaisesRegex(ValueError, "exactly"):
            runner.check_annotation(a, packet(), runner.schemas()[1])
        a = annotation()
        a["dimensions"][0]["final_version"]["status"] = "yes"
        with self.assertRaisesRegex(ValueError, "Unverified"):
            runner.check_annotation(a, packet(), runner.schemas()[1])

    def test_dsh_prefers_durable_output_without_reasoning(self):
        with tempfile.TemporaryDirectory() as tmp:
            trial = Path(tmp)
            runner.write(trial / "agent/unused.json", {})
            (trial / "agent/dsh.jsonl").write_text('{"type":"session","sessionId":"s1"}\n')
            durable = trial / "agent/dsh-home/sessions/app/s1/session.v4.jsonl"
            durable.parent.mkdir(parents=True)
            es = [{"type": "system/message", "data": {"message": {"content": "MODEL_IDENTITY"}}},
                  {"type": "tool/call", "data": {"callId": "a", "name": "bash", "arguments": "run"}},
                  {"type": "tool/result", "data": {"message": {"toolCallId": "a", "content": [
                      {"type": "text", "text": "FULL RESULT"}]}}},
                  {"type": "assistant/message", "data": {"message": {"content": [
                      {"type": "thinking", "text": "HIDDEN"}, {"type": "text", "text": "visible"}]}}}]
            durable.write_text("\n".join(json.dumps(e) for e in es))
            events, _, _, source = runner.normalize(trial)
            self.assertEqual(source, durable)
            self.assertEqual(len(events), 3)
            self.assertIn("FULL RESULT", runner.dump(events))
            self.assertNotIn("HIDDEN", runner.dump(events))
            self.assertNotIn("MODEL_IDENTITY", runner.dump(events))

    def test_command_execution_and_reports_remain_unreviewed(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp) / "run"
            inp, out = runner.schemas()
            runner.write(run / "inputs/case_001.json", packet())
            runner.write(run / "protocol/output.schema.json", out)
            prompts = run / "protocol/prompts"
            prompts.mkdir()
            (prompts / "common.md").write_text("JSON test")
            (prompts / "C1.md").write_text("test")
            runner.write(run / "private/grades/case_001.json", {"c1": 0})
            runner.write(run / "private/manifest.json", {"protocol_sha256": runner.protocol_digest(run), "cases": [{
                "case_id": "case_001", "group": "test", "task": "synthetic",
                "input_sha256": runner.sha(run / "inputs/case_001.json"), "prior_retries": 0,
                "grade_sha256": runner.sha(run / "private/grades/case_001.json")} ]})
            client = Path(tmp) / "client.py"
            client.write_text("import json,sys\nrequest=json.load(sys.stdin)\nassert 'messages' in request\nprint(" + repr(runner.dump(annotation())) + ")\n")
            args = Namespace(run_dir=run, judge_id="fixture", model="synthetic-not-a-real-judge",
                             command=f"{runner.sys.executable} {client}", endpoint=None, extra_body="{}",
                             response_format="json_object", timeout=10, case=None, limit=0)
            runner.judge(args)
            runner.validate(args)
            runner.summarize(args)
            report = (run / "judges/fixture/reports/review.csv").read_text()
            self.assertIn("pending", report)
            self.assertEqual(len(list((run / "judges/fixture/attempts/case_001").iterdir())), 1)
            runner.judge(args)
            self.assertEqual(len(list((run / "judges/fixture/attempts/case_001").iterdir())), 1)

    def test_judge_payload_excludes_independent_grade(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            runner.write(run / "inputs/case_001.json", packet())
            runner.write(run / "protocol/output.schema.json", runner.schemas()[1])
            (run / "protocol/prompts").mkdir()
            (run / "protocol/prompts/common.md").write_text("test")
            runner.write(run / "private/grades/case_001.json", {"secret_grade_marker": 99})
            req, _, _ = runner.request_for(run, "case_001")
            self.assertNotIn("secret_grade_marker", runner.dump(req))

    def test_incomplete_http_response_saved_but_not_accepted(self):
        # Network-free verification of the HTTP branch and truncation handling.
        import io
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            runner.write(run / "inputs/case_001.json", packet())
            runner.write(run / "protocol/output.schema.json", runner.schemas()[1])
            (run / "protocol/prompts").mkdir()
            (run / "protocol/prompts/common.md").write_text("test")
            runner.write(run / "private/manifest.json", {"protocol_sha256": runner.protocol_digest(run), "cases": [{
                "case_id": "case_001", "input_sha256": runner.sha(run / "inputs/case_001.json")} ]})
            args = Namespace(run_dir=run, judge_id="http", model="fixture", command=None,
                endpoint="https://example.invalid/v1/chat/completions", extra_body="{}",
                response_format="json_object", timeout=10, case=None, limit=0, api_key_env="FIXTURE_KEY")
            raw = {"choices": [{"finish_reason": "length", "message": {"content": "{}"}}]}
            with patch.dict(runner.os.environ, {"FIXTURE_KEY": "not-a-real-key"}), \
                 patch.object(runner, "urlopen", return_value=io.BytesIO(json.dumps(raw).encode())):
                with self.assertRaisesRegex(ValueError, "Judge cases failed"):
                    runner.judge(args)
            self.assertFalse((run / "judges/http/annotations/case_001.json").exists())
            self.assertTrue((run / "judges/http/attempts/case_001/001/response.json").exists())


if __name__ == "__main__":
    unittest.main()
