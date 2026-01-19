#!/bin/bash

# Script to create an upgradeable contract by copying v1 to a new version
# Usage: ./patch-upgrade.sh <contract_path> <version>
# Example: ./patch-upgrade.sh contract/r/gnoswap/launchpad v2

set -e

# Check if required arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <contract_path> <version>"
    echo "Example: $0 contract/r/gnoswap/launchpad v2"
    exit 1
fi

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Get contract path relative to project root
CONTRACT_PATH_REL=$1
VERSION=$2

# Convert to absolute path based on project root
CONTRACT_PATH="${PROJECT_ROOT}/${CONTRACT_PATH_REL}"

# Validate that VERSION starts with 'v' followed by a number
if [[ ! $VERSION =~ ^v[0-9]+$ ]]; then
    echo "Error: Version must be in format 'v<number>' (e.g., v2, v3)"
    exit 1
fi

# Check if source directory exists
SOURCE_DIR="${CONTRACT_PATH}/v1"
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' does not exist"
    exit 1
fi

# Set target directory
TARGET_DIR="${CONTRACT_PATH}/${VERSION}"

# Check if target directory already exists
if [ -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' already exists"
    echo "Please remove it first or choose a different version"
    exit 1
fi

echo "Creating upgradeable contract..."
echo "  Project Root: $PROJECT_ROOT"
echo "  Contract Path: $CONTRACT_PATH_REL"
echo "  Source: $SOURCE_DIR"
echo "  Target: $TARGET_DIR"
echo "  Version: $VERSION"
echo ""

# Step 1: Copy v1 directory to new version directory (excluding *test.gno files)
echo "[1/3] Copying v1 directory to ${VERSION} (excluding *test.gno files)..."
rsync -a --exclude='*test.gno' "$SOURCE_DIR/" "$TARGET_DIR/"
echo "  ✓ Directory copied successfully"

# Step 2: Update gnomod.toml module path
GNOMOD_FILE="${TARGET_DIR}/gnomod.toml"
if [ -f "$GNOMOD_FILE" ]; then
    echo "[2/3] Updating gnomod.toml module path..."
    # Replace /v1 with /${VERSION} in the module line
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed syntax
        sed -i '' "s|/v1\"|/${VERSION}\"|g" "$GNOMOD_FILE"
    else
        # Linux sed syntax
        sed -i "s|/v1\"|/${VERSION}\"|g" "$GNOMOD_FILE"
    fi
    echo "  ✓ gnomod.toml updated successfully"
else
    echo "  ⚠ Warning: gnomod.toml not found in target directory"
fi

# Step 3: Update package declaration in all .gno files
echo "[3/3] Updating package declarations in *.gno files..."
GNO_FILES=$(find "$TARGET_DIR" -name "*.gno" -type f)
FILE_COUNT=0

for file in $GNO_FILES; do
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed syntax
        sed -i '' "s/^package v1$/package ${VERSION}/g" "$file"
    else
        # Linux sed syntax
        sed -i "s/^package v1$/package ${VERSION}/g" "$file"
    fi
    FILE_COUNT=$((FILE_COUNT + 1))
done

echo "  ✓ Updated $FILE_COUNT .gno files"
echo ""
echo "✅ Upgradeable contract created successfully!"
echo "New contract location: $TARGET_DIR"
