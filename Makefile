# Project Paths
PROJECT_ROOT := $(shell pwd)
TMP_PATH := $(PROJECT_ROOT)/tmp
GNO_PATH := $(TMP_PATH)/gno
GNOSWAP_PATH := $(TMP_PATH)/gnoswap
SCRIPT := $(PROJECT_ROOT)/scripts/test.sh

include $(PROJECT_ROOT)/scripts/test_values.mk

# Default Target
.PHONY: all
all: help

# 📌 Run the entire test if executed without a specific folder
.PHONY: test
test: reset
	@DEBUG=$(DEBUG) bash $(SCRIPT) test

# 📌 Run tests on specific folders only
.PHONY: test-folder
test-folder: 
	@if [ -z "$(FOLDER)" ]; then \
		echo "❌ Error: Please specify a folder using 'make test-folder FOLDER=<path>'"; \
		exit 1; \
	else \
		DEBUG=$(DEBUG) bash $(SCRIPT) test-folder $(FOLDER); \
	fi

# 📌 Reset the test environment
.PHONY: reset
reset: clean clone setup

# 📌 Initial setup (Go, Python installation & GnoVM setup)
.PHONY: setup
setup:
	@DEBUG=$(DEBUG) bash $(SCRIPT) setup $(GNOSWAP_PATH)

# 📌 Project Clone (GnoVM & Gnoswap)
.PHONY: clone
clone:
	@DEBUG=$(DEBUG) bash $(SCRIPT) clone

# 📌 Delete the temporary folder
.PHONY: clean
clean:
	@rm -rf $(TMP_PATH)

# 📌 find test files
.PHONY: search
search:
	@DEBUG=$(DEBUG) bash $(SCRIPT) search $(FOLDER) $(EXTENSION)
  
.PHONY: fmt
fmt:
	find . -name "*.gno" -type f -exec gofumpt -w {} \;

# 📌 Integration test commands (Docker-based)
.PHONY: integration-test
integration-test:
	@docker-compose run --rm test --all

.PHONY: integration-test-list
integration-test-list:
	@python3 $(PROJECT_ROOT)/setup.py --list-tests

.PHONY: integration-test-run
integration-test-run:
	@if [ -z "$(TEST)" ]; then \
		echo "❌ Error: Please specify a test using 'make integration-test-run TEST=<name>'"; \
		exit 1; \
	else \
		docker-compose run --rm test -t $(TEST); \
	fi

.PHONY: integration-test-build
integration-test-build:
	@docker-compose build

# 📌 Gas report generation
BLESS_DIR := $(PROJECT_ROOT)/tests/integration/bless
GNO_INTEGRATION_DIR ?= $(HOME)/gno/gno.land/pkg/integration
TXTAR_BLESS := $(shell go env GOPATH)/bin/txtar-bless

.PHONY: bless-install
bless-install:
	@cd $(BLESS_DIR) && go build -o $(TXTAR_BLESS) .
	@echo "✅ Installed txtar-bless to $(TXTAR_BLESS)"

.PHONY: gas-report
gas-report:
	@if [ -z "$(TEST)" ]; then \
		echo "❌ Error: Please specify a test using 'make gas-report TEST=<name>'"; \
		echo "   Example: make gas-report TEST=uint256_gas_measurement"; \
		exit 1; \
	else \
		$(TXTAR_BLESS) -test $(TEST) -integration-dir $(GNO_INTEGRATION_DIR) -report; \
	fi

.PHONY: gas-report-tsv
gas-report-tsv:
	@if [ -z "$(TEST)" ]; then \
		echo "❌ Error: Please specify a test using 'make gas-report-tsv TEST=<name>'"; \
		echo "   Example: make gas-report-tsv TEST=uint256_gas_measurement"; \
		exit 1; \
	else \
		$(TXTAR_BLESS) -test $(TEST) -integration-dir $(GNO_INTEGRATION_DIR) -report -tsv; \
	fi

# 📌 Help message
.PHONY: help
help:
	@echo "🔹 Available commands:"
	@echo ""
	@echo "  make test                             Run tests for all folders"
	@echo "  make test-folder FOLDER=<path>        Run test for a specific folder"
	@echo "  make setup                            Install dependencies (Go, Python, etc.)"
	@echo "  make clone                            Clone GnoVM and Gnoswap repositories"
	@echo "  make help                             Show this help message"
	@echo "  make clean                            Delete the temporary folder"
	@echo "  make search                           Find test files"
	@echo "  make reset                            Reset the test environment"
	@echo "  make fmt                              Format all .gno files"
	@echo "  make integration-test                 Run all integration tests"
	@echo "  make integration-test-list            List available integration tests"
	@echo "  make integration-test-run TEST=<name> Run specific integration test"
	@echo "  make integration-test-build           Build Docker image for integration tests"
	@echo ""
	@echo "  make bless-install                    Install bless tool to GOPATH/bin"
	@echo "  make gas-report TEST=<name>           Generate gas measurement report (markdown)"
	@echo "  make gas-report-tsv TEST=<name>       Generate gas measurement report (TSV file)"
