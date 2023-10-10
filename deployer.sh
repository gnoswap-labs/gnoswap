#!/bin/bash

set -e

RETRIES=${RETRIES:-60}

if [[ ! -z "$GNOLAND_RPC_URL" ]]; then
    curl --fail --show-error --silent --retry-connrefused --retry $RETRIES --retry-delay 5 $GNOLAND_RPC_URL
fi

exec /bin/bash -c "_test/init_test_accounts.sh && make -f _test/phase_v1.mk all"
