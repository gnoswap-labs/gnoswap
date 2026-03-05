#!/bin/bash
set -eu

CHAIN_ID="${ATOMONE_CHAIN_ID:-atomone-e2e-1}"
MONIKER="validator"

atomoned init "$MONIKER" --chain-id "$CHAIN_ID" --default-denom uatone --home /root/.atomone -o

echo "$TEST_MNEMONIC" | atomoned keys add validator --recover --keyring-backend test --home /root/.atomone
echo "$RELAYER_MNEMONIC" | atomoned keys add relayer --recover --keyring-backend test --home /root/.atomone

VALIDATOR_ADDR=$(atomoned keys show validator -a --keyring-backend test --home /root/.atomone)
RELAYER_ADDR=$(atomoned keys show relayer -a --keyring-backend test --home /root/.atomone)

atomoned genesis add-genesis-account "$VALIDATOR_ADDR" "1000000000uatone,10000000000uphoton" --keyring-backend test --home /root/.atomone
atomoned genesis add-genesis-account "$RELAYER_ADDR" "1000000000uatone,10000000000uphoton" --keyring-backend test --home /root/.atomone

atomoned genesis gentx validator "500000000uatone" \
    --chain-id "$CHAIN_ID" \
    --keyring-backend test \
    --home /root/.atomone

atomoned genesis collect-gentxs --home /root/.atomone

CONFIG_DIR=/root/.atomone/config

sed -i 's/enable = false/enable = true/g' "$CONFIG_DIR/app.toml"
sed -i 's/address = "tcp:\/\/localhost:1317"/address = "tcp:\/\/0.0.0.0:1317"/g' "$CONFIG_DIR/app.toml"
sed -i 's/address = "localhost:9090"/address = "0.0.0.0:9090"/g' "$CONFIG_DIR/app.toml"
sed -i 's/minimum-gas-prices = ""/minimum-gas-prices = "0uatone,0uphoton"/g' "$CONFIG_DIR/app.toml"

sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/g' "$CONFIG_DIR/config.toml"
sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' "$CONFIG_DIR/config.toml"
sed -i 's/timeout_propose = "3s"/timeout_propose = "1s"/g' "$CONFIG_DIR/config.toml"
sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = ["*"]/g' "$CONFIG_DIR/config.toml"

exec atomoned start --home /root/.atomone
