#!/bin/bash

set -e

RETRIES=${RETRIES:-60}

if [[ ! -z "$GNOLAND_RPC_URL" ]]; then
    curl --fail --show-error --silent --retry-connrefused --retry $RETRIES --retry-delay 5 $GNOLAND_RPC_URL
fi

exec /bin/bash -c "_test/init_test_accounts.sh && make -f _test/init_until_mint_for_router_test_from_sheet.mk all"
