#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.
set -o pipefail  # Catch errors in pipelines.
set -x  # Print commands and their arguments as they are executed.

# Define paths relative to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_PATH="$PROJECT_ROOT/tmp"
GNO_PATH="$TMP_PATH/gno"
GNOSWAP_PATH="$TMP_PATH/gnoswap"

# Matrix configurations
TEST_KEYS=("p/uint256" "p/int256" "p/gnsmath" "r/common" "r/gns" "r/gnft" "r/gov/xgns"
          "r/emission" "r/protocol_fee" "r/pool" "r/position" "r/router" "r/staker"
          "r/community_pool" "r/gov/staker" "r/gov/governance" "r/launchpad")

TEST_VALUES=(
    "gno/examples/gno.land/p/gnoswap/uint256"
    "gno/examples/gno.land/p/gnoswap/int256"
    "gno/examples/gno.land/p/gnoswap/gnsmath"
    "gno/examples/gno.land/r/gnoswap/v1/common"
    "gno/examples/gno.land/r/gnoswap/v1/gns"
    "gno/examples/gno.land/r/gnoswap/v1/gnft"
    "gno/examples/gno.land/r/gnoswap/v1/gov/xgns"
    "gno/examples/gno.land/r/gnoswap/v1/emission"
    "gno/examples/gno.land/r/gnoswap/v1/protocol_fee"
    "gno/examples/gno.land/r/gnoswap/v1/pool"
    "gno/examples/gno.land/r/gnoswap/v1/position"
    "gno/examples/gno.land/r/gnoswap/v1/router"
    "gno/examples/gno.land/r/gnoswap/v1/staker"
    "gno/examples/gno.land/r/gnoswap/v1/community_pool"
    "gno/examples/gno.land/r/gnoswap/v1/gov/staker"
    "gno/examples/gno.land/r/gnoswap/v1/gov/governance"
    "gno/examples/gno.land/r/gnoswap/v1/launchpad"
)

# Ensure tmp directory exists
mkdir -p "$TMP_PATH"

# 1. Clone gnoswap repository into tmp/
echo "✅ Cloning gnoswap repository into tmp/gnoswap..."
git clone https://github.com/gnoswap-labs/gnoswap.git "$GNOSWAP_PATH"

# 2. Clone gno repository into tmp/
echo "✅ Cloning gno repository into tmp/gno..."
git clone --depth 1 --branch master https://github.com/gnolang/gno.git "$GNO_PATH"

# 3. Install Go if not available
echo "✅ Checking Go installation..."
if ! command -v go &> /dev/null; then
    echo "Go is not installed. Installing Go..."
    curl -OL https://golang.org/dl/go1.22.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.22.linux-amd64.tar.gz
fi

# Use the system's default GOROOT
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH
echo "✅ Go Version: $(go version)"

# 4. Modify `gnovm`
echo "✅ Configuring gnovm..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/ctx.Timestamp += (count \* 5)/ctx.Timestamp += (count \* 2)/g' "$GNO_PATH/gnovm/tests/stdlibs/std/std.go"
else
    sed -i 's/ctx.Timestamp += (count \* 5)/ctx.Timestamp += (count \* 2)/g' "$GNO_PATH/gnovm/tests/stdlibs/std/std.go"
fi

# 5. Build & install `gno` CLI
echo "✅ Installing gno CLI..."
cd "$GNO_PATH"
make install.gno
cd "$PROJECT_ROOT"

# 6. Install Python if not available
echo "✅ Checking Python installation..."
if ! command -v python3 &> /dev/null; then
    sudo apt update && sudo apt install -y python3 python3-pip
fi
python3 --version

# 7. Run setup.py (install to tmp/)
echo "✅ Running setup.py in gnoswap..."
cd "$GNOSWAP_PATH"
python3 setup.py -w "$TMP_PATH"
cd "$PROJECT_ROOT"

echo "📂 Searching for test files..."
find "$TMP_PATH/gno/examples/gno.land/p/gnoswap" -name "*_test.gno" || echo "❌ No _test.gno files found!"
find "$TMP_PATH/gno/examples/gno.land/r/gnoswap/v1" -name "*_test.gno" || echo "❌ No _test.gno files found!"
find "$TMP_PATH/gno/examples/gno.land/p/gnoswap" -name "*_test.gnoA" || echo "❌ No _test.gnoA files found!"
find "$TMP_PATH/gno/examples/gno.land/r/gnoswap/v1" -name "*_test.gnoA" || echo "❌ No _test.gnoA files found!"

# 8. Run tests for each contract in the matrix
echo "🔍 TEST_VALUES content:"

set +x

FAILED_TESTS=()
LENGTH=${#TEST_KEYS[@]}
for ((i=0; i<LENGTH; i++)); do
    FOLDER="$TMP_PATH/${TEST_VALUES[$i]}"
    echo "🚀 Running tests for $FOLDER..."

    # Check if folder exists
    if [[ ! -d "$FOLDER" ]]; then
        echo "❌ Error: Test folder $FOLDER does not exist! Skipping..."
        FAILED_TESTS+=("$FOLDER")
        continue
    fi

    # 1) Run unit tests
    if ! gno test "$FOLDER" -root-dir "$GNO_PATH" -v 2>&1 | tee ${TMP_PATH}/test_output.log; then
        FAILED_TESTS+=("$FOLDER")
    fi

    # 2) Remove all *_test.gno except _helper_test.gno
    find "$FOLDER" -type f -name "*_test.gno" ! -name "_helper_test.gno" -exec rm -f {} +

    # 3) Run gnoA tests
    cd "$FOLDER"
    TESTFILES=($(ls *_test.gnoA 2>/dev/null || true))

    for ((j=0; j<${#TESTFILES[@]}; j++)); do
        testfile="${TESTFILES[$j]}"
        base="${testfile%.gnoA}"

        mv "$testfile" "$base.gno"

        if ! gno test "$FOLDER" -root-dir "$GNO_PATH" -v 2>&1 | tee ${TMP_PATH}/test_output.log; then
            FAILED_TESTS+=("[$FOLDER] file: $base.gno test failed")
        fi

        mv "$base.gno" "$testfile"
    done

    cd "$PROJECT_ROOT"
done

echo ""
echo "✅ All tests completed!"
if [[ ${#FAILED_TESTS[@]} -ne 0 ]]; then
    echo "❌ Fail test :"
    for fail in "${FAILED_TESTS[@]}"; do
        echo "   - $fail"
    done
    exit 1
else
    echo "✅ All tests are successfully!"
fi
