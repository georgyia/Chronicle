#!/usr/bin/env bash
# Summarize code coverage from `swift test --enable-code-coverage`.
# Prints a per-file line-coverage table for Chronicle sources.
set -euo pipefail

BIN_PATH="$(swift build --show-bin-path 2>/dev/null)"
PROF="${BIN_PATH}/codecov/default.profdata"

# Locate the test bundle produced by SwiftPM.
XCTEST="$(/usr/bin/find "${BIN_PATH}" -name '*.xctest' -maxdepth 1 -print -quit 2>/dev/null || true)"
if [[ -z "${XCTEST}" || ! -f "${PROF}" ]]; then
  echo "No coverage data found. Run: swift test --enable-code-coverage" >&2
  exit 0
fi

EXECUTABLE="${XCTEST}/Contents/MacOS/$(basename "${XCTEST}" .xctest)"

xcrun llvm-cov report \
  "${EXECUTABLE}" \
  -instr-profile "${PROF}" \
  -ignore-filename-regex='.build|Tests|Benchmarks' \
  2>/dev/null | tail -n 40
