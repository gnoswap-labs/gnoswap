#!/bin/bash
# docker-compose run --rm test [--list | --all | -t NAME | NAME]
set -e

case "${1:-}" in
--help | -h | "") echo "usage: docker-compose run --rm test [--list | --all | -t NAME | NAME]" ;;
--list | -l) exec /app/scripts/gno.sh integration-list ;;
--all | -a) exec /app/scripts/gno.sh integration --all ;;
--test | -t) exec /app/scripts/gno.sh integration "${2:?test name required}" ;;
*) exec /app/scripts/gno.sh integration "$1" ;;
esac
