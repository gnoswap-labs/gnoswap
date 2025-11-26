#!/bin/bash
# Convenience script for running integration tests via Docker
# Usage: ./scripts/run-integration-test.sh [OPTIONS]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running"
    exit 1
fi

# Build image if needed (only on first run or when Dockerfile changes)
build_if_needed() {
    if ! docker-compose images | grep -q "contract2-test"; then
        echo "Building Docker image (first time setup)..."
        docker-compose build
    fi
}

# Pass all arguments to docker-compose run
case "${1:-}" in
    --build|-b)
        # Force rebuild
        echo "Rebuilding Docker image..."
        docker-compose build --no-cache
        shift
        if [ -n "${1:-}" ]; then
            docker-compose run --rm test "$@"
        fi
        ;;
    *)
        build_if_needed
        docker-compose run --rm test "$@"
        ;;
esac
