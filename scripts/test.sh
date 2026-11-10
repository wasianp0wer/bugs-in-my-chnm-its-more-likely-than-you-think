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
# An "ERROR:" whose GDScript backtrace runs inside a GUT test (_run_test) is left to GUT:
# it already fails the test unless the test expected it (assert_push_error_count).
engine_errors() {
  awk '
    /^ERROR:/ { if (pending) bad = 1; pending = 1; n = 0; next }
    pending {
      n++
      if ($0 ~ /_run_test \(res:\/\/addons\/gut\/gut\.gd/) pending = 0
      else if (n > 20 || $0 !~ /^ /) { bad = 1; pending = 0 }
    }
    /^(SCRIPT ERROR|Parse Error)/ { bad = 1 }
    END { if (pending) bad = 1; exit bad ? 0 : 1 }
  ' "$1"
}
if [ "$status" -eq 0 ] && engine_errors "$out"; then
  echo "test.sh: engine errors detected in output" >&2
  status=1
fi
exit "$status"
