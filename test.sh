#!/bin/bash
# Initialize variables
VERBOSE=""
# Parse command line options
while getopts "v" opt; do
  case $opt in
    v)
      VERBOSE="-v"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
# Shift the options so $1 and $2 refer to the positional parameters
shift $((OPTIND-1))
python3 setup.py -w ../ && \
clear && printf '\e[3J'
cd ../gno && \
gno test \
    examples/$1 \
    -print-runtime-metrics \
    -run $2 $VERBOSE