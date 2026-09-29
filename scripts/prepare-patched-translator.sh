#!/bin/zsh
set -euo pipefail

repo=${0:A:h:h}
# Keep the established output path for translator and native-registration callers.
# Maintained source lives in Git; this command never replays translator patches.
# The same step runs inside the cross-platform builder (pipeline.prepare_translator).
PYTHONPATH="$repo/builder" exec python3 -c \
  'import sys; from pathlib import Path; from kartpad_builder.pipeline import prepare_translator; prepare_translator(Path(sys.argv[1]))' \
  "$repo"
