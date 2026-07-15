#!/usr/bin/env bash
set -euo pipefail

PERF_DIR=$(cd "$(dirname "$0")" && pwd)
TESTS_DIR=$(cd "$PERF_DIR/.." && pwd)
RESULTS_DIR="$PERF_DIR/results"
RESULT_FILE="$RESULTS_DIR/benchmark_$(date -u +%Y%m%d_%H%M%S).json"
ENV=${ENV:-default}

# shellcheck source=lib/metrics.sh
source "$PERF_DIR/lib/metrics.sh"
mkdir -p "$RESULTS_DIR"
printf '[\n' > "$RESULT_FILE"
trap 'printf "\n]\n" >> "$RESULT_FILE"' EXIT

run_target() {
  run_metric "$1" make -C "$TESTS_DIR" -f scripts/test.mk "$2" "ENV=$ENV"
}

run_target pool_create pool-create-gns-wugnot-default
run_target liquidity_mint mint-gns-ugnot
make -C "$TESTS_DIR" -f scripts/test.mk setup-multihop-gns-usdc "ENV=$ENV"
run_target swap_exact_in_single swap-exact-in-single-gns-wugnot
run_target swap_multihop swap-exact-in-multihop-gns-usdc
run_target swap_exact_out swap-exact-out-gns-wugnot
run_target collect_fees collect-swap-fee
make -C "$TESTS_DIR" -f scripts/test.mk set-pool-tier-gns-wugnot "ENV=$ENV"
run_target stake_token stake-token-1
run_target collect_rewards collect-staking-reward-1
run_target unstake_token unstake-token-1
run_target liquidity_burn decrease-liquidity-position-01

printf 'Results: %s\n' "$RESULT_FILE"
