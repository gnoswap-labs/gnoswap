#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    echo -e "${BLUE}GnoSwap Integration Test Runner${NC}"
    echo ""
    echo "Usage:"
    echo "  docker-compose run test [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --list, -l          List all available tests"
    echo "  --all, -a           Run all integration tests"
    echo "  --test, -t NAME     Run specific test by name"
    echo "                      (without .txtar extension)"
    echo ""
    echo "Examples:"
    echo "  docker-compose run test --list"
    echo "  docker-compose run test --all"
    echo "  docker-compose run test -t deploy"
    echo "  docker-compose run test -t position_mint"
    echo ""
}

list_tests() {
    echo -e "${BLUE}Available integration tests:${NC}"
    echo ""

    if [ -d "/workspace/contract/tests/integration/testdata" ]; then
        find /workspace/contract/tests/integration/testdata -name "*.txtar" -type f | \
            sed 's|.*/||' | \
            sed 's|\.txtar||' | \
            sort | \
            while read test; do
                echo "  - $test"
            done
    else
        echo -e "${RED}Error: Test directory not found${NC}"
        exit 1
    fi
}

setup_tests() {
    echo -e "${YELLOW}Setting up test environment...${NC}"

    cd /workspace/contract

    # Run setup.py to create symlinks
    python3 setup.py --exclude-tests -w /workspace

    echo -e "${GREEN}Setup completed!${NC}"
}

run_test() {
    local test_name=$1

    echo -e "${BLUE}Running test: ${test_name}${NC}"
    echo ""

    cd /workspace/gno/gno.land/pkg/integration

    if [ "$test_name" = "all" ]; then
        # Run all tests
        go test -v . -run "TestTestdata"
    else
        # Run specific test
        go test -v . -run "TestTestdata/${test_name}"
    fi
}

# Main logic
case "${1:-}" in
    --help|-h|"")
        show_help
        ;;
    --list|-l)
        list_tests
        ;;
    --all|-a)
        setup_tests
        run_test "all"
        ;;
    --test|-t)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Test name required${NC}"
            echo "Usage: docker-compose run test -t TEST_NAME"
            exit 1
        fi
        setup_tests
        run_test "$2"
        ;;
    *)
        # Assume it's a test name for convenience
        setup_tests
        run_test "$1"
        ;;
esac
