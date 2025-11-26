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

setup_tests() {
    echo -e "${YELLOW}Setting up test environment...${NC}"

    cd /app

    # Run setup.py to create symlinks
    python3 setup.py --exclude-tests -w /app

    echo -e "${GREEN}Setup completed!${NC}"
}

run_single_test() {
    local test_name=$1

    echo -e "${BLUE}Running test: ${test_name}${NC}"
    echo ""

    cd /app/gno/gno.land/pkg/integration
    # Use ^ and $ anchors to match exact test name
    go test -v . -run "TestTestdata/^${test_name}\$"
}

run_all_tests() {
    /app/scripts/all-integration-tests.sh \
        /app/gno/gno.land/pkg/integration \
        /app
}

# Main logic
case "${1:-}" in
    --help|-h|"")
        show_help
        ;;
    --all|-a)
        setup_tests
        run_all_tests
        ;;
    --test|-t)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Test name required${NC}"
            echo "Usage: docker-compose run test -t TEST_NAME"
            exit 1
        fi
        setup_tests
        run_single_test "$2"
        ;;
    *)
        # Assume it's a test name for convenience
        setup_tests
        run_single_test "$1"
        ;;
esac
