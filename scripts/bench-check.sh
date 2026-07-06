#!/usr/bin/env bash
# Run the benchmark suite and fail if any tracked metric regresses beyond the
# tolerance versus the committed baseline. Use `--update` to record a new baseline.
#
# Baselines are runner-specific; this gate is intended for a scheduled/on-demand
# workflow on a stable runner, not to block every PR.
set -euo pipefail

TOLERANCE="${BENCH_TOLERANCE:-0.30}"
BASELINE="Benchmarks/baseline.txt"

OUTPUT="$(swift run -c release chronicle-bench)"
echo "$OUTPUT"
echo "---"

if [[ "${1:-}" == "--update" ]]; then
  echo "$OUTPUT" | awk '/ms$/{print $1, $2}' > "$BASELINE"
  echo "Updated baseline at $BASELINE"
  exit 0
fi

# Portable (bash 3.2 / macOS) lookup: no associative arrays.
regressions=0
while read -r name value _; do
  baseValue="$(awk -v n="$name" '$1 == n { print $2 }' "$BASELINE")"
  [[ -z "$baseValue" ]] && continue
  limit="$(echo "$baseValue * (1 + $TOLERANCE)" | bc -l)"
  if (( $(echo "$value > $limit" | bc -l) )); then
    printf 'REGRESSION: %-32s %s ms > %.1f ms limit (baseline %s ms)\n' "$name" "$value" "$limit" "$baseValue"
    regressions=$((regressions + 1))
  fi
done < <(echo "$OUTPUT" | awk '/ms$/{print $1, $2}')

if [[ "$regressions" -gt 0 ]]; then
  echo "$regressions regression(s) detected."
  exit 1
fi
echo "No regressions (tolerance ${TOLERANCE})."
