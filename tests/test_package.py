"""Tests run fake analysis programs; no genome data or Docker daemon required."""
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from genomet2t.cli import main
from genomet2t.config import ConfigError, example_toml, load_config
from genomet2t.runner import StageFailure, build_command, preview, run_stages
from genomet2t.stages import STAGES, Stage, get_stage


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="genomet2t-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.path = self.root / "sample.toml"

    def config(self, pipeline=None, docker=None):
        sections = {"pipeline": pipeline or {}, "docker": docker or {
            "workdir": "./results", "datadir": "./data", "database": "./database",
        }}
        text = ""
        for section, values in sections.items():
            text += f"[{section}]\n"
            for key, value in values.items():
                text += f"{key} = {json.dumps(value)}\n"
        self.path.write_text(text, encoding="utf-8")
        return load_config(self.path)

    def test_template_roundtrip_and_stage_assets(self):
        self.path.write_text(example_toml(), encoding="utf-8")
        config = load_config(self.path)
        config.validate([get_stage("hifi")], "docker")
        from genomet2t.assets import workflow_directory
        for stage in STAGES:
            self.assertTrue((workflow_directory() / stage.script).is_file(), stage.name)
        self.assertEqual(config.pipeline["TRNASCAN_OPTIONS"], ["-E", "-G"])

    def test_init_does_not_overwrite_sample(self):
        with redirect_stdout(io.StringIO()):
            self.assertEqual(main(["init", str(self.path)]), 0)
        before = self.path.read_bytes()
        with patch("sys.stderr", io.StringIO()):
            self.assertEqual(main(["init", str(self.path)]), 2)
        self.assertEqual(before, self.path.read_bytes())

    def test_invalid_schema_and_scalar_types(self):
        for values in ({"unexpected": 3}, {"threads": False},
                       {"HIFI_READS": ["reads.fa"]}, {"QUAL_MODULES": 5},
                       {"THREADS": 3, "threads": 4}):
            with self.subTest(values=values), self.assertRaises(ConfigError):
                self.config(values)

    def test_stage_placeholders_and_parallel_budget(self):
        config = self.config()
        config.validate([get_stage("hifi")], "docker")
        with self.assertRaisesRegex(ConfigError, "GENOME_SIZE"):
            config.validate([get_stage("ont")], "docker")
        config = self.config({"threads": 2, "GENOME_SIZE": 900000000,
                              "NEXTDENOVO_JOBS": 3})
        with self.assertRaisesRegex(ConfigError, "cannot exceed"):
            config.validate([get_stage("ont")], "docker")

    def test_relative_paths_are_relative_to_config_not_cwd(self):
        config = self.config({"HIFI_READS": "data/input.fq.gz"})
        self.assertEqual(config.local_path(config.pipeline["HIFI_READS"]),
                         self.root / "data" / "input.fq.gz")
        with self.assertRaisesRegex(ConfigError, "absolute container path"):
            config.validate([get_stage("hifi")], "docker")

    def test_docker_argument_boundaries_and_auto_image(self):
        config = self.config(docker={"workdir": "./result folder", "datadir": "./data",
                                    "database": "./database"})
        command = build_command(config, get_stage("gemoma"), "docker", "config.sh",
                                self.root)
        self.assertIn("omicsclass/genome-annotation:v1.0", command)
        mount = next(arg for arg in command if "result folder" in arg)
        self.assertIn("dst=/work/myt2t", mount)
        self.assertEqual(command[-1], "/opt/genomet2t/16.GeMoMa.sh")

    def test_reserved_or_overlapping_mounts_fail(self):
        for values in ({"workdir": "/opt"}, {"workdir": "/work", "datadir": "/work/data"},
                       {"database": "/work/myt2t"}):
            with self.subTest(values=values), self.assertRaises(ConfigError):
                self.config(values).validate([], "docker")

    def test_dry_run_has_no_process_or_directory_side_effects(self):
        config = self.config()
        with patch("subprocess.Popen", side_effect=AssertionError("must not spawn")):
            plan = preview(config, [get_stage("hifi")], "docker")
        self.assertEqual(plan[0]["stage"], "hifi")
        self.assertFalse((self.root / "results").exists())
        self.assertFalse((self.root / ".genomet2t").exists())

    def test_hic_manual_review_boundary(self):
        with self.assertRaisesRegex(ConfigError, "manual Juicebox review"):
            run_stages(self.config(), [get_stage("hic-prepare"), get_stage("hic-finalize")])

    def test_sourced_values_are_inert_and_arrays_keep_argument_boundaries(self):
        bash = os.environ.get("GENOMET2T_TEST_BASH")
        if not bash:
            self.skipTest("Set GENOMET2T_TEST_BASH to an available Bash executable.")
        value = "$(printf INJECTED); 'quoted value'"
        config = self.config({"species": value, "TRNASCAN_OPTIONS": ["-E", "-G"]})
        script = self.root / "generated.sh"
        script.write_text(config.shell_text("local"), encoding="utf-8", newline="\n")
        result = subprocess.run(
            [bash, "-c", 'source "$1"; printf "%s\\0%s\\0" "$species" "${TRNASCAN_OPTIONS[1]}"',
             "test", script.as_posix()], capture_output=True, check=True)
        self.assertEqual(result.stdout, value.encode() + b"\0-G\0")

    def test_runner_streams_records_exit_status_and_stops_after_failure(self):
        for name, code in (("first", 0), ("bad", 7), ("last", 0)):
            (self.root / f"{name}.py").write_text(
                f"import sys\nprint('{name} output', flush=True)\nsys.exit({code})\n", encoding="utf-8")
        pipeline = {key: self.root.as_posix() for key in
                    ("workdir", "datadir", "database", "scriptsdir")}
        config = self.config(pipeline)
        stages = [Stage(name, f"{name}.py", "test") for name in ("first", "bad", "last")]
        with patch("genomet2t.runner.workflow_directory", return_value=self.root):
            with redirect_stdout(io.StringIO()), self.assertRaises(StageFailure) as error:
                run_stages(config, stages, "local", sys.executable, self.root / "logs")
        self.assertEqual(error.exception.returncode, 7)
        reports = list((self.root / "logs").glob("*/run.json"))
        self.assertEqual(len(reports), 1)
        report = json.loads(reports[0].read_text(encoding="utf-8"))
        self.assertEqual(report["status"], "failed")
        self.assertEqual([x["stage"] for x in report["stages"]], ["first", "bad"])
        self.assertIn("bad output", Path(report["stages"][-1]["log"]).read_text())


if __name__ == "__main__":
    unittest.main()
