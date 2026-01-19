#!/bin/bash

# Script to remove all *_test.gno and testutils.gno files from the project
# Usage: ./remove-test.sh [root_directory]
#   If root_directory is not provided, defaults to ../../ from script location

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if ROOT_DIR is provided, otherwise use ../../ from script location
if [ -z "$1" ]; then
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
TEST_FILES=$(find "$ROOT_DIR" -name "*_test.gno" -o -name "testutils.gno" -type f)

if [ -z "$TEST_FILES" ]; then
    echo "No test files found."
    exit 0
fi

echo "Found the following test files:"
echo "$TEST_FILES"
echo
echo "Total count: $(echo "$TEST_FILES" | wc -l) files"
echo

read -p "Are you sure you want to delete all these files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing test files..."
    echo "$TEST_FILES" | while IFS= read -r file; do
        rm -f "$file"
        echo "Removed: $file"
    done
    echo "All test files and testutils.gno files have been removed."
else
    echo "Operation cancelled."
fi
