#!/bin/bash

# Update BASE_SEED in p/gnoswap/fuzz/seed.gno with current Unix timestamp
# This ensures each CI run uses a different random seed for fuzz testing

set -e

SEED_FILE="contract/p/gnoswap/fuzz/seed.gno"
TIMESTAMP=$(date +%s)

if [ ! -f "$SEED_FILE" ]; then
    echo "Error: seed.gno not found at $SEED_FILE"
    exit 1
fi

echo "Updating BASE_SEED to Unix timestamp: $TIMESTAMP"

# Use sed to replace the BASE_SEED value
# macOS and Linux have different sed syntax, so we handle both
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/const BASE_SEED = [0-9]*/const BASE_SEED = $TIMESTAMP/" "$SEED_FILE"
else
    # Linux
    sed -i "s/const BASE_SEED = [0-9]*/const BASE_SEED = $TIMESTAMP/" "$SEED_FILE"
fi

echo "BASE_SEED updated successfully"
cat "$SEED_FILE"
