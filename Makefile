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

# Docker commands
docker-build:
	docker-compose build

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

docker-logs:
	docker-compose logs -f

docker-shell:
	docker-compose exec app bash

# 📌 Help message
.PHONY: help
help:
	@echo "🔹 Available commands:"
	@echo ""
	@echo "  make test            Run tests for all folders"
	@echo "  make test-folder FOLDER=<path>  Run test for a specific folder"
	@echo "  make setup           Install dependencies (Go, Python, etc.)"
	@echo "  make clone           Clone GnoVM and Gnoswap repositories"
	@echo "  make help            Show this help message"
	@echo "  make clean           Delete the temporary folder"
	@echo "  make search          Find test files"
	@echo "  make reset           Reset the test environment"
	@echo "  make fmt             Format all .gno files"
	@echo "  make docker-build    Build Docker images"
	@echo "  make docker-up       Start Docker containers"
	@echo "  make docker-down     Stop Docker containers"
	@echo "  make docker-logs     View Docker container logs"
	@echo "  make docker-shell    Open a shell in the Docker container"


