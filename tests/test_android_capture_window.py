"""Keep sustained-performance windows attributable to one live runtime."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[1] / "tools/android-perf/capture-window.py"
spec = importlib.util.spec_from_file_location("capture_window", PATH)
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def stat(pid=42, started=987):
    fields = ["S"] + ["0"] * 18 + [str(started)] + ["0"] * 6
    return f"{pid} (kartpad (game)) " + " ".join(fields)


def mem(pid=42):
    return f"** MEMINFO in pid {pid} [dev.kartpad.android] **\n TOTAL PSS: 1048576 TOTAL RSS: 2097152\n"


def line(time, pid=42, tag="KartPadPerf", values="fps=60.0 p95_ms=16.7 pipelines_created=123 pipelines_queued=0"):
    return f"{time:.3f} {pid} 50 I {tag}: {values}"


class CaptureWindowTest(unittest.TestCase):
    def test_process_identity_uses_start_time_even_with_parentheses(self):
        self.assertEqual(capture.process_identity(stat()), (42, 987))
        self.assertNotEqual(capture.process_identity(stat()), capture.process_identity(stat(started=988)))

    def test_pss_does_not_confuse_rss_or_other_processes(self):
        self.assertEqual(capture.pss_kib(mem(), 42), 1048576)
        self.assertEqual(capture.pss_kib("** MEMINFO in pid 42 [dev.kartpad.android] **\n TOTAL 400 3 2 1", 42), 400)
        with self.assertRaises(ValueError): capture.pss_kib(mem(43), 42)
        with self.assertRaises(ValueError): capture.pss_kib("No process found", 42)

    def test_old_foreign_and_nonmetric_logs_are_excluded(self):
        old = line(100)
        text = "\n".join([old, line(101), line(102, pid=43), line(103, tag="Other", values="secret=123")])
        parsed = capture.metrics(text, 42, [old])
        self.assertEqual(len(parsed), 1)
        self.assertEqual(parsed[0]["unix_s"], 101)
        self.assertNotIn("secret", parsed[0])

    def test_empty_cpu_window_has_no_invented_zero(self):
        summary = capture.summarize(capture.metrics(line(100), 42), [{"pss_kib": 1024}])
        self.assertEqual(summary["main_cpu_ms_per_present_samples"], 0)
        self.assertNotIn("main_cpu_ms_per_present_median", summary)

    def run_fake_window(self, directory, restarted=False, restart_during_screenshot=False):
        log_reads, stat_reads, screenshots = 0, 0, 0
        calls = []
        def adb(command, **kwargs):
            nonlocal log_reads, stat_reads, screenshots
            args = command[3:]
            calls.append(args)
            if args[:2] == ["shell", "cat"] and args[-1].endswith("/stat"):
                stat_reads += 1
                return stat(started=988 if (restarted and stat_reads > 1) or (restart_during_screenshot and screenshots == 2) else 987)
            if args[:2] == ["shell", "cat"]: return "dev.kartpad.android\0"
            if args[:2] == ["exec-out", "screencap"]:
                screenshots += 1
                return b"png-fixture"
            if args[:3] == ["shell", "dumpsys", "meminfo"]: return mem()
            if args[:3] == ["shell", "dumpsys", "thermalservice"]: return "Thermal Status: 1"
            if args[0] == "logcat":
                log_reads += 1
                return line(100) if log_reads == 1 else "\n".join([
                    line(100), line(101),
                    line(101, tag="KartPadCPU", values="main_cpu_ms_per_present=99"),
                    line(102, tag="KartPadCPU", values="main_cpu_ms_per_present=12")])
            raise AssertionError(command)
        clock = iter(range(0, 100, 6))
        out = Path(directory) / "window.json"
        with patch.object(capture.subprocess, "check_output", side_effect=adb), \
             patch.object(capture.time, "monotonic", side_effect=lambda: next(clock)), \
             patch.object(capture.time, "sleep"), patch("builtins.print"):
            capture.main(["--serial", "emulator-5580", "--pid", "42", "--label", "repeat", "--course", "luigi", "--seconds", "5", "--out", str(out)])
        self.assertFalse(any("force-stop" in c or "-c" in c or "start" in c for c in calls))
        return out

    def test_capture_preserves_process_and_drops_overlapping_first_cpu_interval(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            out = self.run_fake_window(directory)
            result = json.loads(out.read_text())
            self.assertEqual(result["pid"], 42)
            self.assertEqual(result["summary"]["main_cpu_ms_per_present_median"], 12)
            self.assertEqual(result["memory"][0]["thermal_status"], 1)
            self.assertTrue(out.with_suffix(".before.png").exists())
            self.assertTrue(out.with_suffix(".after.png").exists())

    def test_restarted_pid_cannot_produce_a_valid_window(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "restarted"):
                self.run_fake_window(directory, restarted=True)
            self.assertFalse((Path(directory) / "window.json").exists())


    def test_orphaned_screenshot_is_not_overwritten(self):
        for suffix in ("before", "after"):
            with self.subTest(suffix=suffix), tempfile.TemporaryDirectory() as directory:
                existing = Path(directory) / f"window.{suffix}.png"
                existing.write_bytes(b"preserve-evidence")
                with self.assertRaises(SystemExit), patch("sys.stderr"):
                    self.run_fake_window(directory)
                self.assertEqual(existing.read_bytes(), b"preserve-evidence")
                self.assertFalse((Path(directory) / "window.json").exists())

    def test_restart_during_final_screenshot_invalidates_window(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "during screenshot"):
                self.run_fake_window(directory, restart_during_screenshot=True)
            self.assertFalse((Path(directory) / "window.json").exists())


if __name__ == "__main__":
    unittest.main()
