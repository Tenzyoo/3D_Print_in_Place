import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("repair_runner", HERE / "run.py")
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)
spec = importlib.util.spec_from_file_location("citation_repair", HERE / "repair_citations.py")
repair = importlib.util.module_from_spec(spec)
with patch.dict(sys.modules, {"run": pipeline}):
    spec.loader.exec_module(repair)


def annotation(citations):
    return {"dimensions": [{"dimension": "C1", "label": "verified", "method": "fixed method",
        "outcome": "fail", "reason": "unchanged judgement", "evidence": citations,
        "final_version": {"status": "no", "reason": "unchanged", "evidence": []},
        "self_check": {"verdict": "fail", "target": "final", "evidence": []}}]}


class RepairTests(unittest.TestCase):
    def test_presentation_recovery_keeps_source_words_and_numbers(self):
        cases = [
            ('结果为 **`0.000000 mm³`**。', '结果为 **`0.000000 mm^3`**'),
            ('29: 使用 `angle1`/`angle2` 检查。', '- 使用 angle1/angle2 检查。'),
            ('1 agent agent 55K file.png', '1 agent agent   55K file.png'),
            ('**完全伸展总长度**：**$326.0\\text{ mm}$**',
             '完全伸展总长度：**$326.0\\text{ mm}$**'),
        ]
        for text, quote in cases:
            with self.subTest(quote=quote):
                restored = repair.restore_presentation(text, quote)
                self.assertIsNotNone(restored)
                self.assertIn(restored, text)
        self.assertIsNone(repair.restore_presentation('上蘑菇形帽', '上蘑菇形防脱帽'))
        self.assertIsNone(repair.restore_presentation('gap = 0.4', 'gap = 0.5'))
        self.assertIsNone(repair.restore_presentation('value = a**2', 'value = a2'))

    def test_json_recovery_only_removes_exact_duplicates_and_closes_objects(self):
        schema = pipeline.obj({"dimension": {"type": "string"},
            "final_version": pipeline.obj({"evidence": {"type": "array"}}),
            "self_check": pipeline.obj({"verdict": {"type": "string"}})})
        good = '{"dimension":"C1","final_version":{"evidence":[]},"self_check":{"verdict":"pass"}}'
        broken = good.replace('"final_version":{"evidence":[]}',
            '"final_version":{"evidence":[],"final_version":{"evidence":[]}')
        recovered, changes = repair.parse_annotation(broken, schema)
        self.assertEqual(recovered, pipeline.json.loads(good))
        self.assertTrue(changes)
        broken = good.replace('[]},"self_check"', '[],"self_check"')
        recovered, changes = repair.parse_annotation(broken, schema)
        self.assertEqual(recovered, pipeline.json.loads(good))
        self.assertEqual(changes[0]['rule'], 'close_final_version_before_self_check')
        with self.assertRaises(ValueError):
            repair.parse_annotation(broken.replace('"verdict":"pass"', '"verdict":'), schema)

    def test_line_numbers_are_restored_without_content_changes(self):
        text = '<content>\n57:         "a": true,\n58:         "b": true,\n</content>'
        quote = '"a": true,\n        "b": true,'
        restored = repair.restore_line_numbers(text, quote)
        self.assertEqual(restored, '"a": true,\n58:         "b": true,')
        self.assertIn(restored, text)
        self.assertIsNone(repair.restore_line_numbers(text, '"a": false,'))
        self.assertIsNone(repair.restore_line_numbers(text + '\n' + text, quote))

    def test_json_escape_correction_preserves_judgement(self):
        code = 'for x in xs:\n print("value", x)'
        packet = {"events": [{"id": "E1", "kind": "tool_call", "call_id": "c", "tool": "bash",
                              "text": pipeline.dump({"command": code})}]}
        original = annotation([{"event_id": "E1", "role": "action", "quote": code}])
        candidate, changes, unresolved = repair.recover(original, packet)
        self.assertEqual(len(changes), 1)
        self.assertFalse(unresolved)
        self.assertIn(candidate["dimensions"][0]["evidence"][0]["quote"], packet["events"][0]["text"])
        self.assertEqual(repair.without_evidence(original), repair.without_evidence(candidate))

    def test_ambiguous_global_quote_only_uses_proven_call_pair(self):
        events = [{"id": "E1", "kind": "tool_call", "call_id": "old", "text": "build model"},
                  {"id": "E2", "kind": "tool_call", "call_id": "last", "text": "build model"},
                  {"id": "E3", "kind": "tool_result", "call_id": "last", "text": "OK"}]
        original = annotation([{"event_id": "E3", "role": "action", "quote": "build model"}])
        candidate, changes, unresolved = repair.recover(original, {"events": events})
        self.assertFalse(unresolved)
        self.assertEqual(candidate["dimensions"][0]["evidence"][0]["event_id"], "E2")
        self.assertEqual(changes[0]["rule"], "paired_action_event_id")

    def test_absent_or_ambiguous_evidence_is_not_invented(self):
        events = [{"id": "E1", "kind": "assistant", "call_id": "", "text": "PASS"},
                  {"id": "E2", "kind": "assistant", "call_id": "", "text": "PASS"}]
        for quote in ["ABSENT", "PASS"]:
            original = annotation([{"event_id": "missing", "role": "claim", "quote": quote}])
            candidate, changes, unresolved = repair.recover(original, {"events": events})
            self.assertEqual(candidate, original)
            self.assertFalse(changes)
            self.assertEqual(len(unresolved), 1)


if __name__ == "__main__":
    unittest.main()
