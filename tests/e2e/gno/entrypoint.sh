#!/bin/bash
set -eu

TEST_ADDR="g1z437dpuh5s4p64vtq09dulg6jzxpr2hd4q8r5x"
DEPLOY_GNOSWAP="${DEPLOY_GNOSWAP:-1}"
READY_FILE="/tmp/gnoswap-ready"

rm -f "$READY_FILE"

printf "%s\n\n" "$RELAYER_MNEMONIC" | gnokey add relayer --recover --insecure-password-stdin --force 2>&1
RELAYER_ADDR=$(gnokey list 2>&1 | grep relayer | sed 's/.*addr: \([^ ]*\).*/\1/')

gnodev local \
    -node-rpc-listener 0.0.0.0:26657 \
    -web-listener 0.0.0.0:8888 \
    -empty-blocks \
    -no-watch \
    -add-account "${TEST_ADDR}=10000000000ugnot" \
    -add-account "${RELAYER_ADDR}=10000000000ugnot" \
    -resolver root=/aibgno \
    -resolver root=$GNOROOT/examples \
    -paths "gno.land/r/aib/ibc/core,gno.land/r/aib/ibc/apps/transfer" &

GNODEV_PID=$!
cleanup() {
    kill "$GNODEV_PID" >/dev/null 2>&1 || true
    wait "$GNODEV_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

until curl -sf http://localhost:26657/status >/dev/null; do
    sleep 1
done

if [ "$DEPLOY_GNOSWAP" = "1" ]; then
    if ! gnokey query vm/qeval -data 'gno.land/r/gnoswap/access.MustGetAddress("pool")' -remote localhost:26657 >/dev/null 2>&1; then
        cd /opt/gnoswap/tests

        printf "%s\n\n" "$TEST_MNEMONIC" | gnokey add gnoswap_admin --recover --insecure-password-stdin --force >/dev/null 2>&1
        make patch-admin-address ENV=default ADDR_ADMIN="$TEST_ADDR"
        find ../contract -type f \( -name "*_test.gno" -o -name "*_filetest.gno" \) -delete

        sed -i -E 's/-gas-fee [0-9]+ugnot/-gas-fee 1000000ugnot/g' scripts/deploy.mk
        sed -i -E 's/-gas-wanted [0-9]+/-gas-wanted 120000000/g' scripts/deploy.mk

        for target in \
            deploy-uint256 deploy-int256 deploy-rbac deploy-gnsmath deploy-store deploy-version_manager \
            deploy-access deploy-rbac-realm deploy-halt-realm deploy-referral deploy-gns deploy-emission deploy-common deploy-gnft \
            deploy-protocol_fee deploy-pool deploy-position \
            deploy-protocol_fee-v1 deploy-pool-v1 deploy-position-v1; do
            attempt=0
            while true; do
                set +e
                output=$(make -f scripts/deploy.mk "$target" ENV=default GNOLAND_RPC_URL=localhost:26657 CHAINID=dev ADDR_ADMIN="$TEST_ADDR" TOMORROW_MIDNIGHT=0 INCENTIVE_END=0 2>&1)
                status=$?
                set -e
                echo "$output"
                if [ $status -eq 0 ] || printf "%s" "$output" | grep -q "package already exists"; then
                    break
                fi
                attempt=$((attempt + 1))
                if [ $attempt -ge 5 ]; then
                    echo "failed target $target after retries"
                    exit 1
                fi
                sleep 1
            done
        done

    fi
fi

touch "$READY_FILE"

wait "$GNODEV_PID"
