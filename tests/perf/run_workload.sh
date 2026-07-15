#!/usr/bin/env bash
set -euo pipefail

PERF_DIR=$(cd "$(dirname "$0")" && pwd)
RUN_DIR=${RUN_DIR:?RUN_DIR is required}
ADMIN_ADDRESS=${ADMIN_ADDRESS:?ADMIN_ADDRESS is required}
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

account_field() {
  gnokey query "auth/accounts/$ADMIN_ADDRESS" -remote 127.0.0.1:26657 |
    sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p"
}

ACCOUNT_NUMBER=$(account_field account_number)
START_SEQUENCE=$(account_field sequence)
printf '' > "$RUN_DIR/operations.txt"
for ((block = 0; block < BLOCKS; block++)); do
  CURRENT_OPERATIONS=$OPERATIONS
  if [[ "$CALIBRATE" == true && "$block" == 1 ]]; then
    CURRENT_OPERATIONS=80
  fi
  SOURCE="$RUN_DIR/workload-$((block + 1)).gno"
  TX="$RUN_DIR/workload-$((block + 1)).tx"
  python3 "$PERF_DIR/generate_workload.py" --start "$((block * OPERATIONS))" --count "$CURRENT_OPERATIONS" "$SOURCE"
  gnokey maketx run -broadcast=false -gas-fee 10000000000ugnot -gas-wanted "$MAX_GAS" \
    "$ADMIN_ADDRESS" "$SOURCE" > "$TX"
  printf '\n' | gnokey sign -insecure-password-stdin=true -chainid dev \
    -account-number "$ACCOUNT_NUMBER" -account-sequence "$((START_SEQUENCE + block))" \
    -tx-path "$TX" gnoswap_admin >/dev/null
  printf '%d\n' "$CURRENT_OPERATIONS" >> "$RUN_DIR/operations.txt"
done

START_HEIGHT=$(curl -fsS http://127.0.0.1:26657/status | jq -r '.result.sync_info.latest_block_height | tonumber')
PIDS=()
for ((block = 0; block < BLOCKS; block++)); do
  gnokey broadcast -remote 127.0.0.1:26657 "$RUN_DIR/workload-$((block + 1)).tx" \
    > "$RUN_DIR/workload-$((block + 1)).txt" 2>&1 &
  PIDS+=("$!")
  sleep 0.1
done
for pid in "${PIDS[@]}"; do
  wait "$pid" || true
done
for raw in "$RUN_DIR"/workload-*.txt; do
  if rg -q '^--= Error =--' "$raw" && ! rg -q 'request timeout' "$raw"; then
    printf 'workload transaction failed: %s\n' "$raw" >&2
    exit 1
  fi
done

TARGET_SEQUENCE=$((START_SEQUENCE + BLOCKS))
for _ in {1..600}; do
  CURRENT_SEQUENCE=$(account_field sequence)
  ((CURRENT_SEQUENCE >= TARGET_SEQUENCE)) && break
  sleep 1
done
((CURRENT_SEQUENCE >= TARGET_SEQUENCE)) || { printf 'workload transactions did not all commit\n' >&2; exit 1; }

python3 "$PERF_DIR/collect_blocks.py" "$RUN_DIR/node.jsonl" "$RUN_DIR/all-blocks.jsonl"
jq -c --argjson start "$START_HEIGHT" \
  'select(.height > $start and .execution.Node.block_txs == 1 and .execution.Node.invalid_txs == 0)' \
  "$RUN_DIR/all-blocks.jsonl" | awk -v blocks="$BLOCKS" 'NR <= blocks' > "$RUN_DIR/workload-blocks.jsonl"
jq -r .height "$RUN_DIR/workload-blocks.jsonl" > "$RUN_DIR/heights.txt"
[[ $(wc -l < "$RUN_DIR/heights.txt" | tr -d ' ') == "$BLOCKS" ]] || {
  printf 'could not identify all workload blocks\n' >&2
  exit 1
}
awk 'NR > 1 && $1 != previous + 1 { exit 1 } { previous = $1 }' "$RUN_DIR/heights.txt" || {
  printf 'workload blocks are not consecutive\n' >&2
  exit 1
}
jq -cs 'to_entries[] | {test_name: "workload-\(.key + 1)", height: .value.height, metrics: {gas_used: .value.gas_used}}' \
  "$RUN_DIR/workload-blocks.jsonl" > "$RUN_DIR/transactions.jsonl"

OPERATIONS_JSON=$(jq -Rs 'split("\n") | map(select(length > 0) | tonumber)' "$RUN_DIR/operations.txt")
HEIGHTS=$(jq -Rs 'split("\n") | map(select(length > 0) | tonumber)' "$RUN_DIR/heights.txt")
printf '{"load":"%s","operations_per_block":%d,"blocks":%d,"operations":%s,"heights":%s}\n' \
  "$LOAD" "$OPERATIONS" "$BLOCKS" "$OPERATIONS_JSON" "$HEIGHTS" > "$RUN_DIR/measurement.json"
