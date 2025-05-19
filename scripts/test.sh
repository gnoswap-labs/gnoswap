#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.
set -o pipefail  # Catch errors in pipelines.

# ✅ Enable debugging
if [[ "$DEBUG" == "true" ]]; then
  set -x # Print commands and their arguments
fi

# Project path setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_PATH="$PROJECT_ROOT/tmp"
GNO_PATH="$TMP_PATH/gno"
GNOSWAP_PATH="$TMP_PATH/gnoswap"

source "$SCRIPT_DIR"/test_values.sh

# ✅ Clone Gnolang & Gnoswap project
clone_repos() {
  # Ensure tmp directory exists
  mkdir -p "$TMP_PATH"

  # Clone gnoswap repository into $TMP_PATH
  echo "✅ Cloning gnoswap repository into tmp/gnoswap..."
  git clone https://github.com/gnoswap-labs/gnoswap.git "$GNOSWAP_PATH"

  # Clone gno repository into $TMP_PATH
  echo "✅ Cloning gno repository into tmp/gno..."
  git clone --depth 1 --branch master https://github.com/gnolang/gno.git "$GNO_PATH"
}

# ✅ env setup(Go, Python install)
setup_env() {
  # Install Go if not available
  echo "✅ Checking Go installation..."
  if ! command -v go &> /dev/null; then
      echo "Go is not installed. Installing Go..."
      curl -OL https://golang.org/dl/go1.23.linux-amd64.tar.gz
      sudo tar -C /usr/local -xzf go1.23.linux-amd64.tar.gz
  fi

  # Use the system's default GOROOT
  export GOPATH=$HOME/go
  export PATH=$GOPATH/bin:$PATH
  echo "✅ Go Version: $(go version)"

  # Modify `gnovm`
  echo "✅ Configuring gnovm..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' 's/ctx.Timestamp += (count \* 5)/ctx.Timestamp += (count \* 2)/g' "$GNO_PATH/gnovm/tests/stdlibs/std/std.go"
  else
      sed -i 's/ctx.Timestamp += (count \* 5)/ctx.Timestamp += (count \* 2)/g' "$GNO_PATH/gnovm/tests/stdlibs/std/std.go"
  fi

  # Build & install `gno` CLI
  echo "✅ Installing gno CLI..."
  cd "$GNO_PATH"
  make install.gno
  cd "$PROJECT_ROOT"

  # Install Python if not available
  echo "✅ Checking Python installation..."
  if ! command -v python3 &> /dev/null; then
      sudo apt update && sudo apt install -y python3 python3-pip
  fi
  python3 --version

  # Run setup.py (install to tmp/)
  echo "✅ Running setup.py in gnoswap..."
  cd "$GNOSWAP_PATH"
  python3 setup.py -w "$TMP_PATH"
  cd "$PROJECT_ROOT"
}

find_test_files() {
    local folder="$1"
    local extension="$2"

    # 🔍 Checking the existence of a directory
    if [[ ! -d "$folder" ]]; then
        echo "❌ Error: Directory $folder does not exist!"
        return 1
    fi

    echo "📂 Searching for test files in: $folder, *_test.$extension"

    # 🔹 Search test files
    if [[ -z "$extension" ]]; then
        found_gno=$(find "$folder" -name "*_test.gno" | sort)
        found_gnoA=$(find "$folder" -name "*_test.gnoA" | sort)

        if [[ -n "$found_gno" ]] && echo "✅ Found _test.gno files:"; then
          echo "$found_gno"
        else
          echo "❌ No _test.gno files found in $folder"
        fi

        if [[ -n "$found_gnoA" ]] && echo "✅ Found _test.gnoA files:"; then
            echo "$found_gnoA"
        else
            echo "❌ No _test.gnoA files found in $folder"
        fi
    else
        found_files=$(find "$folder" -name "*_test.$extension" | sort)
        if [[ -n "$found_files" ]] && echo "✅ Found _test.$extension files:"; then
            echo "$found_files"
        else
            echo "❌ No _test.$extension files found in $folder"
        fi
    fi
}

# ✅ run specific folder test
run_test() {
    local folder="$TMP_PATH/$1"
    FAILED_TESTS=()

    echo "🚀 Running tests for $folder..."

    if [[ ! -d "$folder" ]]; then
        echo "❌ Error: Test folder $folder does not exist! Skipping..."
        return
    fi

    if ! gno test "$folder" -root-dir "$GNO_PATH" -v; then
        echo "❌ Test failed for $folder"
    else
        echo "✅ Test passed for $folder"
    fi

    cd "$folder"
    # shellcheck disable=SC2207
    UNITTESTS=($(ls *_test.gno 2>/dev/null || true))
    for testfile in "${UNITTESTS[@]}"; do
      if [[ ${testfile} == "_helper_test.gno" ]]; then
        continue
      fi
      base="${testfile%.gno}"
      mv "$testfile" "$base.gnoA"
    done

    TESTFILES=()
    if [[ -d "./tests" ]]; then
        TESTFILES=($(ls ./tests/*_test.gnoA 2>/dev/null || true))
    fi

    LENGTH=${#TESTFILES[@]}
    for testfile in "${TESTFILES[@]}"; do
      base_path="${testfile%.gnoA}"
      base_name="${base_path##*/}"
      mv "$testfile" "$base_name.gno"

      if ! gno test "$folder" -root-dir "$GNO_PATH" -v; then
        echo "❌ Test failed for $folder file: $base_name.gno"
        FAILED_TESTS+=("$folder file: $base_name.gno test failed")
      else
        echo "✅ Test passed for $folder file: $base_name.gno"
      fi
      mv "$base_name.gno" "$testfile"
    done

    for testfile in "${UNITTESTS[@]}"; do
      if [[ ${testfile} == "_helper_test.gno" ]]; then
        continue
      fi
      base="${testfile%.gno}"
      mv "$base.gnoA" "$base.gno"
    done

    cd "$PROJECT_ROOT"
}

# ✅ run total folder test
run_all_tests() {
  echo "🔍 Running all tests... $TEST_VALUES"

  FAILED_TESTS=()
  ALL_TEST_LENGTH=${#TEST_VALUES[@]}
  for ((i=0; i<ALL_TEST_LENGTH; i++)); do
    run_test "${TEST_VALUES[$i]}"
  done

  # 테스트 실패 여부 출력
  if [[ ${#FAILED_TESTS[@]} -ne 0 ]]; then
      echo "❌ Some tests failed:"
      for fail in "${FAILED_TESTS[@]}"; do
          echo "   - $fail"
      done
      exit 1
  else
      echo "✅ All tests passed successfully!"
  fi
}

# ✅ Branch operation according to the execution command
case "$1" in
    setup)
        if [[ -n "$2" ]]; then
            GNOSWAP_PATH="$2"
        fi
        
        setup_env
        ;;
    clone)
        clone_repos
        ;;
    test)
        run_all_tests
        ;;
    test-folder)
        if [[ -z "$2" ]]; then
            echo "❌ Error: Please provide a folder path"
            exit 1
        fi
        run_test "$2"
        ;;
    search)
        if [[ -z "$2" ]]; then
            echo "❌ Error: Please provide a folder path : $2"
            exit 1
        fi
        find_test_files "$TMP_PATH/$2" "$3"
        ;;
    *)
        echo "❌ Error: Invalid command. Available commands: setup, clone, test, test-folder <path>"
        exit 1
        ;;
esac