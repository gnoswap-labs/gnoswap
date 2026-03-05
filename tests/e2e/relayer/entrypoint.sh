#!/bin/bash
set -eu

ATOMONE_CHAIN_ID="${ATOMONE_CHAIN_ID:-atomone-e2e-1}"
GNO_CHAIN_ID="${GNO_CHAIN_ID:-dev}"
RELAYER_ATOMONE_RPC_URL="${RELAYER_ATOMONE_RPC_URL:-http://atomone:26657}"
RELAYER_GNO_RPC_URL="${RELAYER_GNO_RPC_URL:-http://gno:26657}"
INDEXER_QUERY_URL="${INDEXER_QUERY_URL:-http://tx-indexer:8546/graphql/query}"

/bin/with_keyring bash -c "
    ibc-v2-ts-relayer add-mnemonic -c $ATOMONE_CHAIN_ID -m \"$RELAYER_MNEMONIC\"
    ibc-v2-ts-relayer add-mnemonic -c $GNO_CHAIN_ID -m \"$RELAYER_MNEMONIC\"

    ibc-v2-ts-relayer add-gas-price -c $ATOMONE_CHAIN_ID 0.025uphoton
    ibc-v2-ts-relayer add-gas-price -c $GNO_CHAIN_ID 0.025ugnot

    ibc-v2-ts-relayer add-path \
        -s $ATOMONE_CHAIN_ID -d $GNO_CHAIN_ID \
        --surl $RELAYER_ATOMONE_RPC_URL \
        --durl $RELAYER_GNO_RPC_URL \
        --dquery $INDEXER_QUERY_URL \
        --st cosmos --dt gno \
        --ibcv 2

    exec \"\$@\"
" -- "$@"
