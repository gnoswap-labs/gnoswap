#!/usr/bin/env bash

BENCHMARK_COUNT=0

run_metric() {
  local name=$1 raw json
  shift
  raw=$(mktemp)
  if ! "$@" 2>&1 | tee "$raw"; then
    rm -f "$raw"
    return 1
  fi
  if ! json=$(python3 "$PERF_DIR/collect_metrics.py" "$name" "$raw"); then
    rm -f "$raw"
    return 1
  fi
  rm -f "$raw"
  if (( BENCHMARK_COUNT++ )); then
    printf ',\n' >> "$RESULT_FILE"
  fi
  printf '  %s' "$json" >> "$RESULT_FILE"
}
