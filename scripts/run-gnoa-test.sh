#!/bin/bash

set -e
set -o pipefail
set -x  # Debug mode enable

if [[ -z "$1" ]]; then
    echo "❌ Error: Enter the path to the folder where the test will be performed!"
    echo "Usage: $0 <folder path>"
    exit 1
fi

FOLDER="$1"

# Check if folder exists
if [[ ! -d "$FOLDER" ]]; then
    echo "❌ Error: Test folder $FOLDER does not exist!"
    exit 1
fi

# gnoA test run
echo "🚀 Running gnoA tests in $FOLDER..."
cd "$FOLDER"

TESTFILES=($(ls *_test.gnoA 2>/dev/null || true))

if [[ ${#TESTFILES[@]} -eq 0 ]]; then
    echo "⚠️ Warning: No _test.gnoA files found in $FOLDER. Skipping..."
    exit 0
fi

FAILED_TESTS=()
TMP_PATH="/tmp"

for testfile in "${TESTFILES[@]}"; do
    base="${testfile%.gnoA}"

    mv "$testfile" "$base.gno"

    # Unit test 수행
    if ! gno test "$FOLDER" -root-dir "$GNO_PATH" -v 2>&1 | tee "${TMP_PATH}/test_output.log"; then
        FAILED_TESTS+=("$base.gno test failed!")
    fi

    mv "$base.gno" "$testfile"
done

cd - 

if [[ ${#FAILED_TESTS[@]} -ne 0 ]]; then
    echo ""
    echo "❌ Failed gnoA test list:"
    for fail in "${FAILED_TESTS[@]}"; do
        echo "   - $fail"
    done
    exit 1 
else
    echo "✅ All gnoA tests completed successfully!"
    exit 0
fi