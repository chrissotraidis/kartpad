#!/usr/bin/env python3
"""Measure an already-running KartPad process without restarting it or clearing logs.

Use repeated --label/--course windows after navigating in-game. Course is an
operator label: keep screenshots and do not compare different courses as a speedup.
Only numeric performance/cache records are saved, never raw logcat or game data.
"""
import argparse
import json
import math
import os
from pathlib import Path
import re
import statistics
import subprocess
import time

TAGS = ("KartPadPerf", "KartPadCPU", "KartPadDLCache", "KartPadGpuResources")
LOG_LINE = re.compile(r"^\s*(\d+\.\d+)\s+(\d+)\s+\d+\s+[VDIWEF]\s+(\w+)\s*:\s*(.*)$")
FIELDS = re.compile(r"\b([a-z][a-z0-9_]*)=(-?\d+(?:\.\d+)?)\b")


def process_identity(stat):
    # comm may contain spaces or parentheses. starttime is field 22, after comm.
    pid, rest = stat.split("(", 1)
    fields = rest.rsplit(")", 1)[1].split()
    return int(pid), int(fields[19])


def pss_kib(meminfo, pid):
    if not re.search(rf"\*\* MEMINFO in pid {pid} \[", meminfo):
        raise ValueError("Memory report belongs to another process or process exited")
    current = re.search(r"TOTAL PSS:\s*(\d+)", meminfo)
    legacy = re.search(r"^\s*TOTAL\s+(\d+)\s+", meminfo, re.MULTILINE)
    match = current or legacy
    if not match:
        raise ValueError("No PSS total in Android memory report")
    return int(match[1])


def metrics(logcat, pid, previous_lines=()):
    previous = set(previous_lines)
    result = []
    for line in logcat.splitlines():
        if line in previous:
            continue
        m = LOG_LINE.match(line)
        if not m or int(m[2]) != pid or m[3] not in TAGS:
            continue
        values = {k: float(v) for k, v in FIELDS.findall(m[4])}
        if values and all(math.isfinite(v) for v in values.values()):
            result.append({"unix_s": float(m[1]), "tag": m[3], **values})
    return result


def summarize(records, samples):
    summary = {"memory_samples": len(samples)}
    if samples:
        summary.update(pss_start_mib=samples[0]["pss_kib"] / 1024,
                       pss_end_mib=samples[-1]["pss_kib"] / 1024,
                       pss_peak_mib=max(s["pss_kib"] for s in samples) / 1024)
    for tag, field in (("KartPadPerf", "fps"), ("KartPadPerf", "p95_ms"),
                       ("KartPadCPU", "main_cpu_ms_per_present")):
        values = [r[field] for r in records if r["tag"] == tag and field in r]
        summary[f"{field}_samples"] = len(values)
        if values:
            summary[f"{field}_median"] = statistics.median(values)
            summary[f"{field}_min"] = min(values)
            summary[f"{field}_max"] = max(values)
    for tag, fields in (("KartPadPerf", ("pipelines_created", "pipelines_queued")),
                        ("KartPadDLCache", ("entries", "command_bytes")),
                        ("KartPadGpuResources", ("copy_pool_approx_mib", "live_copy_approx_mib"))):
        for field in fields:
            values = [r[field] for r in records if r["tag"] == tag and field in r]
            if values:
                summary[f"{field}_start"] = values[0]
                summary[f"{field}_end"] = values[-1]
    return summary


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--serial", required=True)
    p.add_argument("--pid", type=int, required=True, help="Already-running game PID, not chooser")
    p.add_argument("--label", required=True)
    p.add_argument("--course", required=True, help="Operator-confirmed course, not auto-detected")
    p.add_argument("--seconds", type=int, default=60)
    p.add_argument("--out", type=Path, required=True, help="New JSON file under ignored build/perf/")
    p.add_argument("--adb", default=os.environ.get("ADB", str(Path.home() / "Library/Android/sdk/platform-tools/adb")))
    args = p.parse_args(argv)
    if args.pid <= 0 or not 5 <= args.seconds <= 3600:
        p.error("positive PID and 5–3600 seconds required")
    screenshots = {suffix: args.out.with_suffix(f".{suffix}.png") for suffix in ("before", "after")}
    if any(path.exists() for path in (args.out, *screenshots.values())):
        p.error("window JSON or screenshot already exists; choose a new window label/path")
    adb = [args.adb, "-s", args.serial]
    def run(*command, binary=False):
        return subprocess.check_output(adb + list(command), text=not binary, timeout=20)
    def identity():
        return process_identity(run("shell", "cat", f"/proc/{args.pid}/stat"))
    first_identity = identity()
    if first_identity[0] != args.pid:
        raise RuntimeError("Unexpected process identity")
    cmdline = run("shell", "cat", f"/proc/{args.pid}/cmdline").strip("\x00\r\n")
    if not (cmdline == "dev.kartpad.android" or cmdline.startswith("dev.kartpad.android:")):
        raise RuntimeError("PID is not a KartPad process")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    def screenshot(suffix):
        pixels = run("exec-out", "screencap", "-p", binary=True)
        with screenshots[suffix].open("xb") as image:
            image.write(pixels)
    log_args = ("logcat", "-d", "-v", "epoch", f"--pid={args.pid}", "-s", *[f"{tag}:V" for tag in TAGS])
    screenshot("before")
    before = run(*log_args).splitlines()
    samples = []
    started = time.monotonic()
    while True:
        if identity() != first_identity:
            raise RuntimeError("Runtime process restarted; window is invalid")
        memory = pss_kib(run("shell", "dumpsys", "meminfo", "-s", str(args.pid)), args.pid)
        try:
            thermal = re.search(r"Thermal Status:\s*(\d+)", run("shell", "dumpsys", "thermalservice"))
        except subprocess.CalledProcessError:
            thermal = None
        samples.append({"elapsed_s": time.monotonic() - started, "pss_kib": memory,
                        "thermal_status": int(thermal[1]) if thermal else None})
        remaining = args.seconds - (time.monotonic() - started)
        if remaining <= 0:
            break
        time.sleep(min(10, remaining))
    after = run(*log_args)
    if identity() != first_identity:
        raise RuntimeError("Runtime process restarted; window is invalid")
    elapsed = time.monotonic() - started
    screenshot("after")
    if identity() != first_identity:
        raise RuntimeError("Runtime process restarted during screenshot; window is invalid")
    records = metrics(after, args.pid, before)
    # First periodic CPU sample can overlap the time before this window. Discard it.
    for i, record in enumerate(records):
        if record["tag"] == "KartPadCPU":
            del records[i]
            break
    summary = summarize(records, samples)
    if not summary["fps_samples"]:
        raise RuntimeError("No new game frame metrics; chooser, paused game, or unsupported build")
    result = {"schema": 1, "label": args.label, "course_operator_label": args.course,
              "pid": args.pid, "process_start_ticks": first_identity[1], "elapsed_s": elapsed,
              "limits": "Same-process diagnostic window; verify screenshots and settings. CPU/FPS use different reporting intervals. PSS sampling may affect timing. No device/gameplay acceptance.",
              "summary": summary, "memory": samples, "metrics": records}
    with args.out.open("x") as output:
        output.write(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"label": args.label, "course": args.course, **summary}, indent=2))


if __name__ == "__main__":
    main()
