#!/bin/bash

# Script to replace admin address in specific files from commit 90bfb4852a2fc9b8de45918050ff2d826ddb5ec2
# Usage: ./patch-admin-address.sh <new_address>

set -e

OLD_ADDRESS="g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"

# Static list of files to process (from commit 90bfb4852a2fc9b8de45918050ff2d826ddb5ec2)
TARGET_FILES=(
    "contract/r/gnoswap/rbac/consts.gno"
    "contract/r/gnoswap/test_token/bar/bar.gno"
    "contract/r/gnoswap/test_token/baz/baz.gno"
    "contract/r/gnoswap/test_token/foo/foo.gno"
    "contract/r/gnoswap/test_token/obl/obl.gno"
    "contract/r/gnoswap/test_token/qux/qux.gno"
    "contract/r/gnoswap/test_token/usdc/usdc.gno"
)

# Check if new address is provided
if [ -z "$1" ]; then
    echo "Error: New address is required"
    echo "Usage: $0 <new_address>"
    exit 1
fi

NEW_ADDRESS="$1"

# Validate that new address is not empty
if [ -z "$NEW_ADDRESS" ]; then
    echo "Error: New address cannot be empty"
    exit 1
fi

echo "Replacing address in target files..."
echo "Old address: $OLD_ADDRESS"
echo "New address: $NEW_ADDRESS"
echo ""

# Counter for modified files
MODIFIED_COUNT=0

# Get the root directory of the git repository
GIT_ROOT=$(git rev-parse --show-toplevel)

# Process each target file
for file in "${TARGET_FILES[@]}"; do
    FULL_PATH="$GIT_ROOT/$file"
    
    # Check if file exists
    if [ ! -f "$FULL_PATH" ]; then
        echo "Warning: File not found - $file"
        continue
    fi
    
    # Check if the file contains the old address
    if grep -q "$OLD_ADDRESS" "$FULL_PATH"; then
        echo "Processing: $file"
        
        # Replace the address in the file
        # Use different syntax for macOS (BSD sed) vs Linux (GNU sed)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/$OLD_ADDRESS/$NEW_ADDRESS/g" "$FULL_PATH"
        else
            # Linux
            sed -i "s/$OLD_ADDRESS/$NEW_ADDRESS/g" "$FULL_PATH"
        fi
        
        MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
    else
        echo "Skipping (no match): $file"
    fi
done

echo ""
echo "Done! Modified $MODIFIED_COUNT file(s)"
