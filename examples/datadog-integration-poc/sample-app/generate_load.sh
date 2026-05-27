#!/bin/bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:28080}"
ITERATIONS="${ITERATIONS:-20}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

echo "Generating load against ${BASE_URL}"
echo "Iterations: ${ITERATIONS}"
echo "Sleep between requests: ${SLEEP_SECONDS}s"
echo

for i in $(seq 1 "${ITERATIONS}"); do
  echo "[$i/${ITERATIONS}] Triggering /simulate-load"
  curl -s "${BASE_URL}/simulate-load" || true
  echo
  echo "[$i/${ITERATIONS}] Refreshing /metrics"
  curl -s "${BASE_URL}/metrics" >/dev/null || true
  sleep "${SLEEP_SECONDS}"
done

echo
echo "Load generation complete."
echo "Check metrics:"
echo "  curl ${BASE_URL}/metrics | grep -E 'app_memory_usage_percent|memory_threshold_exceeded_total|memory_threshold_percent'"

# Made with Bob
