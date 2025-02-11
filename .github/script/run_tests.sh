#!/bin/bash
# .github/scripts/run_tests.sh

# Check if folder argument is provided
if [ -z "$1" ]; then
    echo "Error: Please provide a folder path"
    exit 1
fi

FOLDER="$1"
ROOT_DIR="$2"

if [ -z "$ROOT_DIR" ]; then
    ROOT_DIR="/home/runner/work/gnoswap/gnoswap/gno"
fi

# Run unit tests first
echo "Running unit tests for $FOLDER"
gno test ./"$FOLDER" -root-dir "$ROOT_DIR" -v

# Remove all `_test.gno` except `_helper_test.gno`
echo "Removing temporary test files"
find ./"$FOLDER" -type f -name "*_test.gno" \
    ! -name "_helper_test.gno" \
    -exec rm -f {} +

# Run gnoA tests one-by-one
echo "Running gnoA tests"
cd ./"$FOLDER" || exit 1

TESTFILES=$(ls | grep '_test.gnoA$' || true)
if [ -n "$TESTFILES" ]; then
    for f in $TESTFILES; do
        echo "Testing $f"
        base="${f%.gnoA}"
        mv "$f" "$base.gno"
        gno test . -root-dir "$ROOT_DIR" -v
        mv "$base.gno" "$f"
    done
else
    echo "No gnoA test files found"
fi
