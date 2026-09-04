#!/usr/bin/env python3
"""Emit an allowlisted, content-free summary of an Android A2 runtime log."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Sequence, TextIO


AUDIO_ACTIVE = re.compile(
    r"\[audio\] host playback active: (?P<rate>\d+) Hz, "
    r"(?P<channels>\d+) channels, gain=(?P<gain>[-+0-9.eE]+)"
)
NON_SILENT = re.compile(
    r"\[audio\] non-silent PCM reached host playback: "
    r"peak=(?P<peak>\d+), queued=(?P<queued>-?\d+) bytes"
)
QUEUE = re.compile(
    r"\[audio\] (?P<final>final )?queue telemetry: "
    r"checks=(?P<checks>\d+), empty-before-push=(?P<empty>\d+), "
    r"dropped-blocks=(?P<blocks>\d+), dropped-bytes=(?P<dropped>\d+), "
    r"submitted-bytes=(?P<submitted>\d+), queued=(?P<queued>-?\d+), "
    r"observed-range=\[(?P<minimum>-?\d+),(?P<maximum>-?\d+)\] bytes, "
    r"limit=(?P<limit>\d+) bytes"
)
CONTROLLER = re.compile(
    r"\[input\] Android SDL controller channel (?P<channel>\d+) "
    r"(?P<state>connected|disconnected)"
)

LIFECYCLE_MARKERS = (
    "surfaceCreated()",
    "surfaceDestroyed()",
    "nativePause()",
    "nativeResume()",
    "Standard gamepads suspended",
    "Standard gamepads resumed",
)
FATAL_MARKERS = (
    "FATAL EXCEPTION",
    "Fatal signal",
    "CheckJNI",
    "SIGABRT",
    "SIGSEGV",
)


@dataclass(frozen=True)
class QueueSample:
    checks: int
    empty_before_push: int
    dropped_blocks: int
    dropped_bytes: int
    submitted_bytes: int
    queued_bytes: int
    minimum_queued_bytes: int
    maximum_queued_bytes: int
    limit_bytes: int
    final: bool


def queue_sample(match: re.Match[str]) -> QueueSample:
    values = match.groupdict()
    sample = QueueSample(
        checks=int(values["checks"]),
        empty_before_push=int(values["empty"]),
        dropped_blocks=int(values["blocks"]),
        dropped_bytes=int(values["dropped"]),
        submitted_bytes=int(values["submitted"]),
        queued_bytes=int(values["queued"]),
        minimum_queued_bytes=int(values["minimum"]),
        maximum_queued_bytes=int(values["maximum"]),
        limit_bytes=int(values["limit"]),
        final=values["final"] is not None,
    )
    if (
        sample.limit_bytes <= 0
        or sample.minimum_queued_bytes < 0
        or sample.minimum_queued_bytes > sample.maximum_queued_bytes
        or sample.maximum_queued_bytes > sample.limit_bytes
        or sample.queued_bytes < -1
        or sample.queued_bytes > sample.limit_bytes
    ):
        raise ValueError("invalid Android audio queue telemetry")
    return sample


def summarize(streams: Iterable[TextIO]) -> dict:
    audio_active_events = 0
    audio_rates: set[int] = set()
    audio_channels: set[int] = set()
    non_silent_events = 0
    maximum_peak = 0
    queue_samples: list[QueueSample] = []
    controller_connected = 0
    controller_disconnected = 0
    lifecycle = {marker: 0 for marker in LIFECYCLE_MARKERS}
    fatal = {marker: 0 for marker in FATAL_MARKERS}

    for stream in streams:
        for raw_line in stream:
            line = raw_line.rstrip("\r\n")
            if match := AUDIO_ACTIVE.search(line):
                audio_active_events += 1
                audio_rates.add(int(match.group("rate")))
                audio_channels.add(int(match.group("channels")))
            if match := NON_SILENT.search(line):
                non_silent_events += 1
                maximum_peak = max(maximum_peak, int(match.group("peak")))
            if "queue telemetry:" in line:
                match = QUEUE.search(line)
                if not match:
                    raise ValueError("malformed Android audio queue telemetry")
                queue_samples.append(queue_sample(match))
            if match := CONTROLLER.search(line):
                if int(match.group("channel")) == 0:
                    if match.group("state") == "connected":
                        controller_connected += 1
                    else:
                        controller_disconnected += 1
            for marker in LIFECYCLE_MARKERS:
                lifecycle[marker] += line.count(marker)
            for marker in FATAL_MARKERS:
                fatal[marker] += line.count(marker)

    most_advanced = max(
        queue_samples,
        key=lambda sample: (sample.submitted_bytes, sample.checks),
        default=None,
    )
    result = {
        "schema_version": 1,
        "audio": {
            "host_playback_events": audio_active_events,
            "sample_rates_hz": sorted(audio_rates),
            "channel_counts": sorted(audio_channels),
            "non_silent_events": non_silent_events,
            "maximum_peak": maximum_peak,
            "queue_sample_count": len(queue_samples),
            "most_advanced_queue_sample": (
                asdict(most_advanced) if most_advanced else None
            ),
        },
        "controller": {
            "channel_0_connected_events": controller_connected,
            "channel_0_disconnected_events": controller_disconnected,
        },
        "lifecycle": {
            "surface_created": lifecycle["surfaceCreated()"],
            "surface_destroyed": lifecycle["surfaceDestroyed()"],
            "native_pause": lifecycle["nativePause()"],
            "native_resume": lifecycle["nativeResume()"],
            "gamepads_suspended": lifecycle["Standard gamepads suspended"],
            "gamepads_resumed": lifecycle["Standard gamepads resumed"],
        },
        "fatal_signature_counts": {
            marker: count for marker, count in fatal.items() if count
        },
    }
    result["automated_signal_matrix_passed"] = bool(
        audio_active_events
        and non_silent_events
        and most_advanced
        and most_advanced.submitted_bytes > 0
        and controller_connected
        and lifecycle["surfaceDestroyed()"]
        and lifecycle["nativePause()"]
        and lifecycle["surfaceCreated()"] >= 2
        and lifecycle["nativeResume()"]
        and lifecycle["Standard gamepads suspended"]
        and lifecycle["Standard gamepads resumed"]
        and not result["fatal_signature_counts"]
    )
    return result


def self_test() -> None:
    from io import StringIO

    clean = StringIO(
        "private text that must not be copied\n"
        "[audio] host playback active: 32000 Hz, 2 channels, gain=1\n"
        "[audio] non-silent PCM reached host playback: peak=3988, queued=2716 bytes\n"
        "[audio] queue telemetry: checks=8192, empty-before-push=0, "
        "dropped-blocks=1, dropped-bytes=384, submitted-bytes=3141120, "
        "queued=8604, observed-range=[0,15260] bytes, limit=15360 bytes\n"
        "[input] Android SDL controller channel 0 connected\n"
        "surfaceCreated()\nsurfaceDestroyed()\nnativePause()\n"
        "Standard gamepads suspended\nsurfaceCreated()\nnativeResume()\n"
        "Standard gamepads resumed\n"
    )
    result = summarize([clean])
    assert result["automated_signal_matrix_passed"]
    assert result["audio"]["maximum_peak"] == 3988
    assert "private text" not in json.dumps(result)

    fatal = summarize([StringIO("Fatal signal 6\n")])
    assert not fatal["automated_signal_matrix_passed"]
    assert fatal["fatal_signature_counts"] == {"Fatal signal": 1}

    malformed = StringIO("[audio] queue telemetry: private malformed data\n")
    try:
        summarize([malformed])
    except ValueError:
        pass
    else:
        raise AssertionError("malformed queue telemetry was accepted")


def open_inputs(paths: Sequence[str]) -> tuple[list[TextIO], list[TextIO]]:
    if not paths or paths == ["-"]:
        return [sys.stdin], []
    if "-" in paths:
        raise ValueError("stdin cannot be combined with log paths")
    opened: list[TextIO] = []
    try:
        for path in paths:
            opened.append(Path(path).open(encoding="utf-8", errors="replace"))
    except OSError:
        for stream in opened:
            stream.close()
        raise
    return opened, opened


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("logs", nargs="*", help="private logs to summarize; default stdin")
    parser.add_argument("--require-signal-matrix", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        print("Android A2 session summarizer self-test passed")
        return 0

    if args.require_signal_matrix and len(args.logs) > 1:
        parser.error("--require-signal-matrix accepts one capture or stdin only")

    try:
        streams, close_after = open_inputs(args.logs)
        try:
            result = summarize(streams)
        finally:
            for stream in close_after:
                stream.close()
    except OSError:
        parser.error("could not read one or more log inputs")
    except ValueError as error:
        parser.error(str(error))

    print(json.dumps(result, indent=2, sort_keys=True))
    if args.require_signal_matrix and not result["automated_signal_matrix_passed"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
