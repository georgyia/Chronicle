#!/usr/bin/env bash
# Run the Chronicle agent under a sandbox for a fixed duration and sample its
# resident memory and CPU, to catch leaks and runaway growth over a long run.
#
# Usage: scripts/soak.sh [duration_seconds]  (default 300)
set -euo pipefail

DURATION="${1:-300}"
SANDBOX="$(mktemp -d)"
export CHRONICLE_HOME="$SANDBOX"
export CHRONICLE_SOCKET="/tmp/chr-soak-$$.sock"
export CHRONICLE_MODULE_HEARTBEAT=on

cleanup() {
  kill "$AGENT_PID" 2>/dev/null || true
  rm -rf "$SANDBOX"
  rm -f "$CHRONICLE_SOCKET"
}
trap cleanup EXIT

swift build -c release >/dev/null
.build/release/chronicled run >"$SANDBOX/agent.log" 2>&1 &
AGENT_PID=$!
echo "agent pid=$AGENT_PID sandbox=$SANDBOX duration=${DURATION}s"

start=$(date +%s)
printf '%-8s %-10s %-8s\n' "elapsed" "rss_kb" "cpu%"
while kill -0 "$AGENT_PID" 2>/dev/null; do
  now=$(date +%s); elapsed=$((now - start))
  [[ "$elapsed" -ge "$DURATION" ]] && break
  read -r rss cpu < <(ps -o rss=,%cpu= -p "$AGENT_PID" 2>/dev/null || echo "0 0")
  printf '%-8s %-10s %-8s\n' "$elapsed" "$rss" "$cpu"
  sleep 15
done

echo "--- final status ---"
.build/release/chronicle status || true
