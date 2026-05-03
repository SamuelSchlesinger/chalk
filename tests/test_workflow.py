import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILES = [
    "script.md",
    "sync_scripts.py",
    "voiceover.sh",
    "timed_scenes.py",
    "timed_scenes_shorts.py",
]


def run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)


def copy_project(dst):
    for name in PROJECT_FILES:
        source = ROOT / name
        target = dst / name
        shutil.copy2(source, target)
        if source.stat().st_mode & 0o111:
            target.chmod(target.stat().st_mode | 0o755)


class WorkflowTests(unittest.TestCase):
    def in_temp_project(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name)
        copy_project(path)
        return path

    def test_starter_scripts_are_in_sync(self):
        project = self.in_temp_project()

        result = run([sys.executable, "sync_scripts.py", "--check"], project)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("ALL 2 SEGMENTS IN SYNC", result.stdout)

    def test_sync_handles_multiword_headings_and_shell_quoting(self):
        project = self.in_temp_project()
        spoken = 'we say "alpha", then $x \\beta, and it\'s fine.'
        (project / "script.md").write_text(
            f"""# video title

## square both sides

{spoken}

> **[CUT TO MANIM: S01_Square scene]**
> title card

## closing

closing line goes here
""",
        )

        voiceover = (project / "voiceover.sh").read_text()
        voiceover = re.sub(
            r"SEGMENTS=\(\n.*?\n\)",
            """SEGMENTS=(
    "01:S01_Square:01_square:square both sides"
    "02:S02_Closing:02_closing:closing"
)""",
            voiceover,
            flags=re.DOTALL,
        )
        voiceover = re.sub(
            r"SCRIPTS=\(\n.*?\n\)",
            """SCRIPTS=(
    'stale prompt'
    'stale closing'
)""",
            voiceover,
            flags=re.DOTALL,
        )
        (project / "voiceover.sh").write_text(voiceover)

        sync = run([sys.executable, "sync_scripts.py"], project)
        check = run([sys.executable, "sync_scripts.py", "--check"], project)
        syntax = run(["bash", "-n", "voiceover.sh"], project)
        sourced = run(
            [
                "bash",
                "-lc",
                'source ./voiceover.sh >/dev/null; printf "%s\\n" "${SCRIPTS[0]}"',
            ],
            project,
        )

        self.assertEqual(sync.returncode, 0, sync.stdout + sync.stderr)
        self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
        self.assertEqual(syntax.returncode, 0, syntax.stdout + syntax.stderr)
        self.assertEqual(sourced.returncode, 0, sourced.stdout + sourced.stderr)
        self.assertEqual(sourced.stdout.strip(), spoken)

    def test_durations_reports_missing_renders_without_failing(self):
        project = self.in_temp_project()

        result = run(["bash", "voiceover.sh", "durations"], project)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("01", result.stdout)
        self.assertIn("02", result.stdout)
        self.assertIn("missing", result.stdout)
        self.assertIn("(no recording)", result.stdout)

    def test_composite_fails_before_partial_work_when_assets_are_missing(self):
        project = self.in_temp_project()

        result = run(["bash", "voiceover.sh", "composite"], project)
        output = result.stdout + result.stderr

        self.assertNotEqual(result.returncode, 0, output)
        self.assertIn("ERROR: missing required assets for landscape composite", output)
        self.assertIn("vo_01_intro.wav", output)
        self.assertIn("S01_Intro.mp4", output)
        self.assertFalse((project / "output" / "concat_list.txt").exists())


if __name__ == "__main__":
    unittest.main()
