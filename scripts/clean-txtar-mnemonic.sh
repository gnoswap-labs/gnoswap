#!/bin/bash

# Base directory for txtar files
TXTAR_DIR="tests/integration/testdata"

# Clean function
clean_txtar_file() {
    local file=$1
    local temp_file="${file}.tmp"
    
    # Replace actual mnemonics with placeholder
    sed -E "s/adduserfrom gns_admin '([^']+)'/adduserfrom gns_admin 'mnemonic here'/" "$file" > "$temp_file"
    
    # Check if replacement was made
    if diff -q "$file" "$temp_file" > /dev/null; then
        rm "$temp_file"
        echo "No changes needed for $file"
    else
        mv "$temp_file" "$file"
        echo "Cleaned $file"
    fi
}

# Find and clean all txtar files containing mnemonics
for txtar_file in "$TXTAR_DIR"/*.txtar; do
    if [ -f "$txtar_file" ]; then
        if grep -E "adduserfrom gns_admin '[^']+'" "$txtar_file" | grep -v "mnemonic here" > /dev/null 2>&1; then
            clean_txtar_file "$txtar_file"
        fi
    fi
done

echo "Done cleaning txtar files"