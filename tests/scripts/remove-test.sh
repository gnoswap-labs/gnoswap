#!/bin/bash

set -euo pipefail

# Script to remove all *_test.gno and testutils.gno files from the project
# Usage: REMOVE_TESTS_CONFIRM=yes ./remove-test.sh [root_directory]
#   If root_directory is not provided, defaults to ../../ from script location
#   REMOVE_TESTS_CONFIRM=yes skips the confirmation prompt (used by make deploy)

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if ROOT_DIR is provided, otherwise use ../../ from script location
if [ -z "${1:-}" ]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
    echo "No ROOT_DIR provided, using default: $ROOT_DIR"
else
    ROOT_DIR="$1"
fi

if [ ! -d "$ROOT_DIR" ]; then
    echo "Error: Directory '$ROOT_DIR' does not exist"
    exit 1
fi

echo "Searching for *_test.gno and testutils.gno files in: $ROOT_DIR"
TEST_FILES=$(find "$ROOT_DIR" -type f \( -name "*_test.gno" -o -name "testutils.gno" \))

if [ -z "$TEST_FILES" ]; then
    echo "No test files found."
    exit 0
fi

echo "Found the following test files:"
echo "$TEST_FILES"
echo
echo "Total count: $(echo "$TEST_FILES" | wc -l) files"
echo

if [ "${REMOVE_TESTS_CONFIRM:-}" = "yes" ]; then
    REPLY=y
else
    read -p "Are you sure you want to delete all these files? (y/N): " -n 1 -r
    echo
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing test files..."
    while IFS= read -r file; do
        rm -f "$file"
        echo "Removed: $file"
    done <<< "$TEST_FILES"
    echo "All test files and testutils.gno files have been removed."
else
    echo "Operation cancelled."
    exit 1
fi
