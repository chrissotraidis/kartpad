#!/usr/bin/env python3
"""Release gate for pull requests (see .github/workflows/release-gate.yml).

If version.json changed against BASE, the pull request description (PR_BODY) must
contain the "Go or no-go" answers from docs/RELEASE-CHECKLIST.md, numbered 1 to 4,
each with a real answer, and docs/releases/v<version>.md must exist.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def version_changed(base: str) -> bool:
    diff = subprocess.run(["git", "diff", "--quiet", base, "HEAD", "--", "version.json"], cwd=ROOT)
    return diff.returncode != 0


def problems(body: str, version: str) -> list[str]:
    found = []
    if not (ROOT / "docs/releases" / f"v{version}.md").is_file():
        found.append(f"docs/releases/v{version}.md is missing")
    match = re.search(r"go or no-go", body, re.IGNORECASE)
    if not match:
        found.append('the description has no "Go or no-go" answers (docs/RELEASE-CHECKLIST.md)')
        return found
    answers = body[match.end():]
    for number in range(1, 5):
        line = re.search(rf"^\s*{number}\.\s+(.+)$", answers, re.MULTILINE)
        if not line or len(line.group(1).strip()) < 10:
            found.append(f"go-or-no-go question {number} has no answer")
    return found


def main() -> int:
    base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
    if not version_changed(base):
        print("version.json unchanged: not a release pull request")
        return 0
    version = json.loads((ROOT / "version.json").read_text())["version"]
    found = problems(os.environ.get("PR_BODY") or "", version)
    for problem in found:
        print(f"Release gate: {problem}")
    if found:
        print("Answer the go-or-no-go questions in the pull request description, then re-run.")
        return 1
    print(f"Release gate passed for {version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
