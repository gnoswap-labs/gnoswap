#!/bin/bash

# Example:
# export GNS_ADMIN_MNEMONIC="your-test-mnemonic-phrase-here" && ./scripts/update-txtar-mnemonic.sh

# Check if GNS_ADMIN_MNEMONIC is set
if [ -z "${GNS_ADMIN_MNEMONIC}" ]; then
    echo "Error: GNS_ADMIN_MNEMONIC environment variable is not set"
    exit 1
fi

# Base directory for txtar files
TXTAR_DIR="tests/integration/testdata"

# Update function
update_txtar_file() {
    local file=$1
    local temp_file="${file}.tmp"

    # Replace the mnemonic placeholder with actual mnemonic
    sed -E "s/adduserfrom gns_admin 'mnemonic here'/adduserfrom gns_admin '${GNS_ADMIN_MNEMONIC}'/" "$file" > "$temp_file"

    # Check if replacement was made
    if diff -q "$file" "$temp_file" > /dev/null; then
        rm "$temp_file"
        echo "No changes needed for $file"
    else
        mv "$temp_file" "$file"
        echo "Updated $file"
    fi
}

# Find and update all txtar files containing the mnemonic placeholder
for txtar_file in "$TXTAR_DIR"/*.txtar; do
    if [ -f "$txtar_file" ]; then
        if grep -E -q "adduserfrom gns_admin 'mnemonic here'" "$txtar_file"; then
            update_txtar_file "$txtar_file"
        fi
    fi
done

echo "Done updating txtar files"
