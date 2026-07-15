#!/usr/bin/env bash
set -euo pipefail

PERF_DIR=$(cd "$(dirname "$0")" && pwd)
RUN_DIR=${RUN_DIR:?RUN_DIR is required}
MAX_GAS=${MAX_GAS:-3000000000}
BLOCKS=100
LOAD=
CALIBRATION=
CALIBRATE=false

while (($#)); do
  case "$1" in
    --calibrate) CALIBRATE=true; shift ;;
    --load) LOAD=$2; shift 2 ;;
    --blocks) BLOCKS=$2; shift 2 ;;
    --calibration) CALIBRATION=$2; shift 2 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [[ "$CALIBRATE" == true ]]; then
  LOAD=calibration
  BLOCKS=2
  OPERATIONS=20
else
  [[ "$LOAD" =~ ^(50|70|100)$ ]] || { printf -- '--load must be 50, 70, or 100\n' >&2; exit 2; }
  [[ -f "$CALIBRATION" ]] || { printf 'calibration file not found: %s\n' "$CALIBRATION" >&2; exit 2; }
  OPERATIONS=$(jq -er --arg load "$LOAD" '.operations_per_block[$load]' "$CALIBRATION")
fi

printf '' > "$RUN_DIR/transactions.jsonl"
printf '' > "$RUN_DIR/heights.txt"
for ((block = 0; block < BLOCKS; block++)); do
  CURRENT_OPERATIONS=$OPERATIONS
  if [[ "$CALIBRATE" == true && "$block" == 1 ]]; then
    CURRENT_OPERATIONS=80
  fi
  SOURCE="$RUN_DIR/workload.gno"
  RAW="$RUN_DIR/workload-$((block + 1)).txt"
  python3 "$PERF_DIR/generate_workload.py" --start "$((block * OPERATIONS))" --count "$CURRENT_OPERATIONS" "$SOURCE"
  printf '\n' | gnokey maketx run \
    -insecure-password-stdin=true -remote 127.0.0.1:26657 -broadcast=true \
    -chainid dev -simulate skip -gas-fee 10000000000ugnot -gas-wanted "$MAX_GAS" \
    gnoswap_admin "$SOURCE" > "$RAW"
  python3 "$PERF_DIR/collect_metrics.py" "workload-$((block + 1))" "$RAW" >> "$RUN_DIR/transactions.jsonl"
  awk '$1 == "HEIGHT:" { height = $2 } END { print height }' "$RAW" >> "$RUN_DIR/heights.txt"
done
HEIGHTS=$(jq -Rs 'split("\n") | map(select(length > 0) | tonumber)' "$RUN_DIR/heights.txt")
printf '{"load":"%s","operations_per_block":%d,"blocks":%d,"heights":%s}\n' \
  "$LOAD" "$OPERATIONS" "$BLOCKS" "$HEIGHTS" > "$RUN_DIR/measurement.json"
