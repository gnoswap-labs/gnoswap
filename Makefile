PROJECT_ROOT := $(shell pwd)
GNO := $(PROJECT_ROOT)/scripts/gno.sh
GNO_REF ?= master
GNO_TOOLCHAIN ?= $(HOME)/.cache/gno-toolchains/gnoswap-$(GNO_REF)
export GNO_REF GNO_TOOLCHAIN

include $(PROJECT_ROOT)/scripts/test_values.mk

# Default Target
.PHONY: all
all: help

.PHONY: fmt
fmt:
	find . -name "*.gno" -type f -exec gofumpt -w {} \;

# 📌 Gno toolchain and tests (see scripts/gno.sh, same flow as `mise run`)
.PHONY: gno-setup
gno-setup:
	@$(GNO) setup

.PHONY: test
test:
	@$(GNO) test $(or $(PKG),./...) -v $(if $(RUN),-run $(RUN)) $(if $(COVER),-cover)

.PHONY: integration-test
integration-test:
	@$(GNO) integration --all $(if $(SKIP),--skip)

.PHONY: integration-test-list
integration-test-list:
	@$(GNO) integration-list $(if $(SKIP),--skip)

.PHONY: integration-test-run
integration-test-run:
	@$(GNO) integration $(or $(TEST),$(error Please specify a test using 'make integration-test-run TEST=<name>'))

.PHONY: integration-test-docker
integration-test-docker:
	@docker-compose run --build --rm test $(or $(TEST),--all)

# 📌 Gas report generation
BLESS_DIR := $(PROJECT_ROOT)/tests/integration/bless
GNO_INTEGRATION_DIR ?= $(GNO_TOOLCHAIN)/src/gno.land/pkg/integration
TXTAR_BLESS := $(shell go env GOPATH)/bin/txtar-bless

.PHONY: integration-link
integration-link:
	@$(GNO) integration-link

.PHONY: bless-install
bless-install:
	@cd $(BLESS_DIR) && go build -o $(TXTAR_BLESS) .
	@echo "✅ Installed txtar-bless to $(TXTAR_BLESS)"

.PHONY: gas-report
gas-report: integration-link
	@if [ -z "$(TEST)" ]; then \
		echo "❌ Error: Please specify a test using 'make gas-report TEST=<name>'"; \
		echo "   Example: make gas-report TEST=uint256_gas_measurement"; \
		exit 1; \
	else \
		$(TXTAR_BLESS) -test $(TEST) -integration-dir $(GNO_INTEGRATION_DIR) -report; \
	fi

.PHONY: gas-report-tsv
gas-report-tsv: integration-link
	@if [ -z "$(TEST)" ]; then \
		echo "❌ Error: Please specify a test using 'make gas-report-tsv TEST=<name>'"; \
		echo "   Example: make gas-report-tsv TEST=uint256_gas_measurement"; \
		exit 1; \
	else \
		filename="$(TEST)_$$(git rev-parse --short HEAD).tsv"; \
		$(TXTAR_BLESS) -test $(TEST) -integration-dir $(GNO_INTEGRATION_DIR) -report -tsv -output "$$filename"; \
	fi

# 📌 Help message
.PHONY: help
help:
	@echo "🔹 Available commands:"
	@echo ""
	@echo "  make gno-setup                        Build the gno toolchain into ~/.cache/gno-toolchains"
	@echo "  make test PKG=<path>                  Run gno test for a package (module path or contract/ path)"
	@echo "  make test PKG=<path> RUN=<name>       Run specific test function"
	@echo ""
	@echo "  make help                             Show this help message"
	@echo "  make fmt                              Format all .gno files"
	@echo ""
	@echo "  make integration-test [SKIP=1]        Run all integration tests (SKIP=1 drops testdata-skip.txt)"
	@echo "  make integration-test-list [SKIP=1]   List available integration tests"
	@echo "  make integration-test-run TEST=<name> Run specific integration test"
	@echo "  make integration-test-docker [TEST=]  Run integration tests in Docker"
	@echo "  make integration-link                 Link contracts and txtars into the toolchain (for bless)"
	@echo ""
	@echo "  make bless-install                    Install bless tool to GOPATH/bin"
	@echo "  make gas-report TEST=<name>           Generate gas measurement report (markdown)"
	@echo "  make gas-report-tsv TEST=<name>       Generate gas measurement report (TSV file)"
