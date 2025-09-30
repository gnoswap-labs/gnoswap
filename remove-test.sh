#!/bin/bash

# Script to remove all *_test.gno and testutils.gno files from the project

echo "Finding all *_test.gno and testutils.gno files..."
TEST_FILES=$(find . -name "*_test.gno" -o -name "testutils.gno" -type f)

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
