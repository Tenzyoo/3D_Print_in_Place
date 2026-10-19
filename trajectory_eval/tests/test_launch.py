import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("launch_runner", HERE / "run.py")
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)
spec = importlib.util.spec_from_file_location("launch_driver", HERE / "launch.py")
launch = importlib.util.module_from_spec(spec)
with patch.dict(sys.modules, {"run": pipeline}):
    spec.loader.exec_module(launch)


class LaunchTests(unittest.TestCase):
    def test_deepseek_uses_own_key_endpoint_and_native_parameters(self):
        values = {"GPT_API_KEY": "gpt-test-key", "JUDGE_API_KEY": "other-test-key",
                  "GPT_BASE_URL": "https://gpt.invalid/v1", "JUDGE_ENDPOINT": "https://judge.invalid/v1/chat/completions",
                  "DEEPSEEK_API_KEY": "deepseek-test-key", "DEEPSEEK_BASE_URL": "https://api.deepseek.com",
                  "DEEPSEEK_MODEL": "deepseek-flash"}
        model, endpoint, key, body, judge_id = launch.resolve_judge(values, "deepseek")
        self.assertEqual(model, "deepseek-flash")
        self.assertEqual(endpoint, "https://api.deepseek.com/chat/completions")
        self.assertEqual(key, "deepseek-test-key")
        self.assertEqual(judge_id, "deepseek_flash_high_v1")
        params = launch.json.loads(body)
        self.assertEqual(params["max_tokens"], 65536)
        self.assertNotIn("max_completion_tokens", params)
        self.assertEqual(params["thinking"], {"type": "enabled"})

    def test_deepseek_does_not_fall_back_to_gpt_credentials(self):
        with self.assertRaisesRegex(ValueError, "no cross-provider"):
            launch.resolve_judge({"GPT_API_KEY": "gpt-test-key", "GPT_MODEL": "gpt"}, "deepseek")

    def test_env_parser_treats_values_as_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / ".env"
            p.write_text('# comment\nexport GPT_MODEL="judge-model"\nGPT_API_KEY="literal$(not-executed)#key"\n')
            values = launch.env_values(p)
            self.assertEqual(values["GPT_MODEL"], "judge-model")
            self.assertEqual(values["GPT_API_KEY"], "literal$(not-executed)#key")

    def test_failed_requests_are_not_counted_as_labels(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            pipeline.write(run / "private/manifest.json", {"cases": [{"case_id": "case_001"}, {"case_id": "case_002"}]})
            pipeline.write(run / "judges/test/attempts/case_001/001/metadata.json", {
                "status": "error", "error": "URLError: Temporary failure in name resolution"})
            status = launch.execution_status(run, "test", "synthetic-judge", "failed")
            self.assertFalse(status["complete"])
            self.assertEqual(status["states"], {"error": 1, "not_attempted": 1})
            self.assertNotIn("validated_unreviewed", status["states"])
            self.assertFalse((run / "judges/test/annotations").exists())


if __name__ == "__main__":
    unittest.main()
