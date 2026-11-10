#!/usr/bin/env bash
# Run the GUT test suite headlessly. Extra args are passed through to GUT.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

# A fresh worktree has no .godot/, so import first (quietly unless it fails).
if ! import_out="$("$GODOT" --headless --path "$ROOT/sim" --import 2>&1)"; then
  echo "$import_out"
  echo "test.sh: import step failed" >&2
  exit 1
fi

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

"$GODOT" --headless --path "$ROOT/sim" -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit "$@" 2>&1 | tee "$out"
status=${PIPESTATUS[0]}

# Script/parse errors can leave GUT exiting 0 with no tests run; treat as failure.
if [ "$status" -eq 0 ] && grep -qE "^(SCRIPT ERROR|ERROR:|Parse Error)" "$out"; then
  echo "test.sh: engine errors detected in output" >&2
  status=1
fi
exit "$status"
