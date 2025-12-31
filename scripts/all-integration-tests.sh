#!/bin/bash
# Run all integration tests individually
# Usage: ./scripts/all-integration-tests.sh [GNO_INTEGRATION_PATH] [CONTRACT_PATH] [--skip] [--category=<categories>]
#
# Examples:
#   ./scripts/all-integration-tests.sh ./gno/gno.land/pkg/integration . --skip
#   ./scripts/all-integration-tests.sh ./gno/gno.land/pkg/integration . --skip --category=base
#   ./scripts/all-integration-tests.sh ./gno/gno.land/pkg/integration . --skip --category=base,gov,upgradable

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
GNO_INTEGRATION_PATH=""
CONTRACT_PATH=""
SKIP_FLAG=""
CATEGORY_FLAG=""

for arg in "$@"; do
    case $arg in
        --skip)
            SKIP_FLAG="--skip"
            ;;
        --category=*)
            CATEGORY_FLAG="--category=${arg#*=}"
            ;;
        *)
            if [ -z "$GNO_INTEGRATION_PATH" ]; then
                GNO_INTEGRATION_PATH="$arg"
            elif [ -z "$CONTRACT_PATH" ]; then
                CONTRACT_PATH="$arg"
            fi
            ;;
    esac
done

# Default paths
GNO_INTEGRATION_PATH="${GNO_INTEGRATION_PATH:-/app/gno/gno.land/pkg/integration}"
CONTRACT_PATH="${CONTRACT_PATH:-/app}"

# Convert to absolute paths
GNO_INTEGRATION_PATH="$(cd "$GNO_INTEGRATION_PATH" && pwd)"
CONTRACT_PATH="$(cd "$CONTRACT_PATH" && pwd)"

echo -e "${BLUE}Running all integration tests individually...${NC}"
if [ -n "$CATEGORY_FLAG" ]; then
    echo -e "${BLUE}Category filter: ${CATEGORY_FLAG#--category=}${NC}"
fi
echo ""

cd "$GNO_INTEGRATION_PATH"

tests=()
while IFS= read -r test; do
    tests+=("$test")
done < <(cd "$CONTRACT_PATH" && python3 setup.py --list-tests $SKIP_FLAG $CATEGORY_FLAG)

total=${#tests[@]}
passed=0
failed=0
failed_tests=()

echo -e "${YELLOW}Found ${total} tests to run${NC}"
echo ""

# Disable exit on error to continue running all tests
set +e

for i in "${!tests[@]}"; do
    test="${tests[$i]}"
    num=$((i + 1))

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}[${num}/${total}] Running: ${test}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if go test -v . -run "TestTestdata/^${test}\$"; then
        echo -e "${GREEN}✓ PASSED: ${test}${NC}"
        ((passed++)) || true
    else
        echo -e "${RED}✗ FAILED: ${test}${NC}"
        ((failed++)) || true
        failed_tests+=("$test")
    fi
    echo ""
done

# Re-enable exit on error
set -e

# Print summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                    TEST SUMMARY                           ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Total:  ${total}"
echo -e "  ${GREEN}Passed: ${passed}${NC}"
echo -e "  ${RED}Failed: ${failed}${NC}"

if [ ${#failed_tests[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed tests:${NC}"
    for t in "${failed_tests[@]}"; do
        echo -e "  ${RED}- ${t}${NC}"
    done
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Exit with failure if any test failed
if [ $failed -gt 0 ]; then
    exit 1
fi
