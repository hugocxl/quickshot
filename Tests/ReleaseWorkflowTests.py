"""Exercise release versioning against disposable Git histories, never this repo."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class ReleaseWorkflowTests(unittest.TestCase):
    def test_bootstrap_multi_commit_push_and_missing_bump(self):
        with tempfile.TemporaryDirectory(prefix="quickshot-release-tests-") as directory:
            repo = Path(directory)
            shutil.copytree(ROOT / "scripts", repo / "scripts")
            env = dict(os.environ, GIT_AUTHOR_NAME="Test", GIT_AUTHOR_EMAIL="test@example.com",
                       GIT_COMMITTER_NAME="Test", GIT_COMMITTER_EMAIL="test@example.com")

            def run(*args, ok=True):
                result = subprocess.run(args, cwd=repo, env=env, text=True, capture_output=True)
                if ok:
                    self.assertEqual(result.returncode, 0, result.stderr)
                else:
                    self.assertNotEqual(result.returncode, 0)
                return result.stdout.strip()

            def commit(message):
                run("git", "add", ".")
                run("git", "commit", "-m", message)
                return run("git", "rev-parse", "HEAD")

            def section(version):
                return f"## {version} - 2026-11-03\n\n### Changed\n\n- Improve Quickshot.\n"

            run("git", "init", "-b", "main")
            (repo / "README.md").write_text("Existing unversioned app\n")
            baseline = commit("Existing history")
            changelog = repo / "CHANGELOG.md"
            changelog.write_text("# Changelog\n\n" + section("1.0.1"))
            first = commit("Introduce release setup")
            run("scripts/changelog.sh", "check")
            run("scripts/changelog.sh", "tag", baseline, first)
            self.assertEqual(run("git", "rev-list", "-1", "v1.0.1"), first)
            changelog.write_text("# Changelog\n\n" + section("1.0.2") + "\n" + section("1.0.1"))
            second = commit("Fix")
            changelog.write_text("# Changelog\n\n" + section("1.1.0") + "\n" + section("1.0.2") + "\n" + section("1.0.1"))
            third = commit("Feature")
            run("scripts/changelog.sh", "tag", first, third)
            self.assertEqual(run("git", "rev-list", "-1", "v1.0.2"), second)
            self.assertEqual(run("git", "rev-list", "-1", "v1.1.0"), third)
            notes = run("scripts/changelog.sh", "notes", "1.0.1")
            self.assertIn("## 1.0.2", notes)
            self.assertNotIn("## 1.0.1", notes)
            run("scripts/changelog.sh", "tag", first, third)  # Rerun is safe.
            (repo / "README.md").write_text("Missing version bump\n")
            invalid = commit("Missing bump")
            run("scripts/changelog.sh", "tag", third, invalid, ok=False)
            changelog.write_text("# Changelog\n\n" + section("1.0.1") + section("1.1.0"))
            run("scripts/changelog.sh", "check", ok=False)


if __name__ == "__main__":
    unittest.main()
