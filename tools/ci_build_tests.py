"""Contract checks for the network bootstrap without downloading or importing."""

import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from contextlib import redirect_stdout
import subprocess

import ci_build


FONT_BOOTSTRAP_LOG = """Godot Engine v4.7.2.stable.official
ERROR: Cannot open file 'res://.godot/imported/korean_font.ttf-32d4935dfb5b77b063b7310a09c66657.fontdata'.
   at: load (core/io/resource_format_binary.cpp:1156)
ERROR: Failed loading resource: res://.godot/imported/korean_font.ttf-32d4935dfb5b77b063b7310a09c66657.fontdata.
   at: _load (core/io/resource_loader.cpp:317)
ERROR: Failed loading resource: res://assets/fonts/korean_font.ttf.
   at: _load (core/io/resource_loader.cpp:317)
ERROR: Error loading custom project font 'res://assets/fonts/korean_font.ttf'
   at: initialize_theme (scene/theme/theme_db.cpp:84)
"""


class Response(io.BytesIO):
    def __init__(self, body, *, status=206, content_range=None):
        super().__init__(body)
        self.status = status
        self.headers = {"Content-Range": content_range}


class BootstrapTests(unittest.TestCase):
    def test_range_is_exact_and_seekable(self):
        reader = ci_build.ReleaseZipReader()
        reader.seek(-4, 2)
        expected = f"bytes {ci_build.TEMPLATE_ARCHIVE_SIZE - 4}-{ci_build.TEMPLATE_ARCHIVE_SIZE - 1}/{ci_build.TEMPLATE_ARCHIVE_SIZE}"
        with patch.object(ci_build, "request", return_value=Response(b"tail", content_range=expected)) as request:
            self.assertEqual(reader.read(8), b"tail")
            self.assertEqual(request.call_args.args[1], {"Range": f"bytes={ci_build.TEMPLATE_ARCHIVE_SIZE - 4}-{ci_build.TEMPLATE_ARCHIVE_SIZE - 1}"})
        self.assertEqual(reader.read(), b"")
        with self.assertRaises(ValueError):
            reader.seek(-1)

    def test_full_response_requests_the_verified_archive_fallback(self):
        with patch.object(ci_build, "request", return_value=Response(b"not partial", status=200)):
            with self.assertRaises(ci_build.RangeUnavailable):
                ci_build.ReleaseZipReader().read(10)

    def test_wrong_range_or_truncated_body_cannot_be_accepted(self):
        with patch.object(ci_build, "request", return_value=Response(b"abcd", content_range="bytes 1-4/100")):
            with self.assertRaises(ci_build.RangeUnavailable):
                ci_build.ReleaseZipReader().read(4)
        expected = f"bytes 0-3/{ci_build.TEMPLATE_ARCHIVE_SIZE}"
        with patch.object(ci_build, "request", return_value=Response(b"ab", content_range=expected)):
            with self.assertRaises(OSError):
                ci_build.ReleaseZipReader().read(4)

    def test_hash_failure_preserves_existing_template(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "template.zip"
            target.write_bytes(b"existing valid template")
            with self.assertRaises(ValueError):
                ci_build.write_verified(target, b"changed download", "0" * 64)
            self.assertEqual(target.read_bytes(), b"existing valid template")
            self.assertFalse(target.with_name(target.name + ".download").exists())

    def test_engine_warnings_and_failures_fail_the_build(self):
        for output, status in [("WARNING: resource missing\n", 0), ("SCRIPT ERROR: invalid call\n", 0), ("unexpected shutdown\n", 1)]:
            completed = type("Completed", (), {"stdout": output, "returncode": status})()
            with patch.object(ci_build.subprocess, "run", return_value=completed):
                with self.assertRaises(RuntimeError):
                    ci_build.run(["godot"], check_engine=True)

    def test_fresh_font_bootstrap_gets_one_strict_verification(self):
        results = [subprocess.CompletedProcess([], 0, FONT_BOOTSTRAP_LOG), subprocess.CompletedProcess([], 0, "Import completed\n")]
        with patch.object(ci_build.subprocess, "run", side_effect=results) as run, redirect_stdout(io.StringIO()):
            ci_build.import_project("godot")
        self.assertEqual(run.call_count, 2)
        self.assertEqual(run.call_args_list[0].args[0], run.call_args_list[1].args[0])

    def test_clean_import_is_not_repeated(self):
        with patch.object(ci_build.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "Import completed\n")) as run, redirect_stdout(io.StringIO()):
            ci_build.import_project("godot")
        self.assertEqual(run.call_count, 1)

    def test_unrelated_errors_or_warnings_never_get_a_retry(self):
        invalid_logs = [
            "ERROR: Missing res://assets/needed.webp\n",
            FONT_BOOTSTRAP_LOG + "SCRIPT ERROR: Parse Error in game.gd\n",
            FONT_BOOTSTRAP_LOG + "WARNING: Invalid texture\n",
            "ERROR: Failed loading resource: res://assets/fonts/korean_font.ttf.\n",
            FONT_BOOTSTRAP_LOG.replace("korean_font.ttf", "different_font.ttf"),
        ]
        for output in invalid_logs:
            with self.subTest(output=output), patch.object(ci_build.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, output)) as run, redirect_stdout(io.StringIO()):
                with self.assertRaises(RuntimeError):
                    ci_build.import_project("godot")
                self.assertEqual(run.call_count, 1)

    def test_nonzero_first_import_never_gets_a_retry(self):
        with patch.object(ci_build.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, FONT_BOOTSTRAP_LOG)) as run, redirect_stdout(io.StringIO()):
            with self.assertRaises(RuntimeError):
                ci_build.import_project("godot")
        self.assertEqual(run.call_count, 1)

    def test_second_import_must_have_no_errors_and_exit_zero(self):
        for output, status in [(FONT_BOOTSTRAP_LOG, 0), ("WARNING: Other issue\n", 0), ("", 1)]:
            results = [subprocess.CompletedProcess([], 0, FONT_BOOTSTRAP_LOG), subprocess.CompletedProcess([], status, output)]
            with self.subTest(output=output, status=status), patch.object(ci_build.subprocess, "run", side_effect=results) as run, redirect_stdout(io.StringIO()):
                with self.assertRaises(RuntimeError):
                    ci_build.import_project("godot")
                self.assertEqual(run.call_count, 2)


if __name__ == "__main__":
    unittest.main()
