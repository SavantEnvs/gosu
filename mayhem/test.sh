#!/usr/bin/env bash
#
# mayhem/test.sh — RUNS Gosu's own GoogleTest suite (test/*.cpp, built by build.sh with normal flags) under
# a virtual X display with software GL, the same way upstream's CMake CI does. Asserted values throughout
# (pixel comparisons, text metrics, math/color/timing/utility results).
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

RUNNER="$SRC/test/GosuTests"
[ -x "$RUNNER" ] || { echo "missing $RUNNER (mayhem/build.sh should have built it)" >&2; emit_ctrf gtest 0 1 0; exit 1; }

export SDL_VIDEO_FORCE_EGL=1 LIBGL_ALWAYS_SOFTWARE=1
cd "$SRC/test"   # tests load media/ with relative paths
log="$(mktemp)"
xvfb-run --auto-servernum "$RUNNER" >"$log" 2>&1
rc=$?
cat "$log"

total=$(sed -n 's/^\[==========\] \([0-9]*\) tests\? from .* ran\..*/\1/p' "$log" | tail -1)
passed=$(sed -n 's/^\[  PASSED  \] \([0-9]*\) tests\?\..*/\1/p' "$log" | tail -1)
skipped=$(sed -n 's/^\[  SKIPPED \] \([0-9]*\) tests\?, listed below.*/\1/p' "$log" | tail -1)
failed=$(sed -n 's/^\[  FAILED  \] \([0-9]*\) tests\?, listed below.*/\1/p' "$log" | tail -1)
rm -f "$log"
total=${total:-0}; passed=${passed:-0}; skipped=${skipped:-0}; failed=${failed:-0}

# No summary at all (crash / early exit) or a non-zero exit without a counted failure is a failure.
if [ "$total" -eq 0 ]; then failed=1; elif [ "$rc" -ne 0 ] && [ "$failed" -eq 0 ]; then failed=1; fi
cd "$SRC"
emit_ctrf gtest "$passed" "$failed" "$skipped"
