.PHONY: default
default: help

GNOCMD ?= go run github.com/gnoswap-labs/gno/gnovm/cmd/gno # gnoswap package
GNOROOT ?= `$(GNOCMD) env GNOROOT`

GNO_TEST_FLAGS ?= -v

TEST_TOKENS := $(wildcard $(PWD)/__local/grc20_tokens/*)
BASIC_TOKENS := $(wildcard $(PWD)/_deploy/r/demo/*)

TESTFILE_GOV := $(wildcard $(PWD)/gov/_TEST_/*)
TESTFILE_POOL := $(wildcard $(PWD)/pool/_TEST_/*)
TESTFILE_POSITION := $(wildcard $(PWD)/position/_TEST_/*)
TESTFILE_ROUTER := $(wildcard $(PWD)/router/_TEST_/*)
TESTFILE_STAKER := $(wildcard $(PWD)/staker/_TEST_/*)

.PHONY: help
help: ## Display this help message.
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make [\033[36m<target>\033[0m...]\n"} /^[[0-9a-zA-Z_\.-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: clean
clean: ## Remove temporary files.
	find . -name '*.gen.go' -exec rm -rf {} +
	rm -rf .test

.PHONY: test.prepare
test.prepare:
	echo $(GNOROOT)

	rm -rf .test
	# Create fake GNOROOT with stdlibs, testing stdlibs, and p/ dependencies.
	# This is currently necessary as gno.mod's `replace` functionality is not linked with the VM.
	mkdir -p .test/gnovm/tests .test/examples/gno.land/p/demo .test/examples/gno.land/p/demo/grc .test/examples/gno.land/r/demo
	cp -r "$(GNOROOT)/gnovm/stdlibs" .test/gnovm/stdlibs
	cp -r "$(GNOROOT)/gnovm/tests/stdlibs" .test/gnovm/tests/stdlibs
	for i in gno.land/p/demo/ufmt gno.land/p/demo/avl gno.land/p/demo/json gno.land/p/demo/grc/exts gno.land/p/demo/grc/grc20 gno.land/p/demo/grc/grc721 gno.land/p/demo/users gno.land/p/demo/testutils gno.land/r/demo/users gno.land/r/demo/wugnot gno.land/r/demo/foo20; do \
		cp -r "$(GNOROOT)/examples/$$i" ".test/examples/$$i";\
	done
	# Copy over gnoswap code.
	cp -r $(TEST_TOKENS) ".test/examples/gno.land/r/demo" # test tokens
	cp -r $(BASIC_TOKENS) ".test/examples/gno.land/r/demo" # gnft, gns

	cp -r "$(PWD)/_deploy/p/demo/gnoswap" ".test/examples/gno.land/p/demo" # gnoswap base package

	cp -r "$(PWD)/_deploy/r/gnoswap" ".test/examples/gno.land/r/gnoswap" # gnoswap base realm

	cp -r "$(PWD)/gov" "$(PWD)/pool" "$(PWD)/position" "$(PWD)/router" "$(PWD)/staker" ".test/examples/gno.land/r/demo" # gnoswap realm

	# Move tests
	cp $(TESTFILE_GOV) ".test/examples/gno.land/r/demo/gov"
	cp $(TESTFILE_POOL) ".test/examples/gno.land/r/demo/pool"
	cp $(TESTFILE_POSITION) ".test/examples/gno.land/r/demo/position"
	cp $(TESTFILE_ROUTER) ".test/examples/gno.land/r/demo/router"
	cp $(TESTFILE_STAKER) ".test/examples/gno.land/r/demo/staker"

.PHONY: test.gov
test.gov:
	cd .test/examples; GNOROOT="$(PWD)/.test" $(GNOCMD) test $(GNO_TEST_FLAGS) gno.land/r/demo/gov
	GN_FILES="$(wildcard .test/examples/gno.land/r/demo/gov/*.gn)"; \
	for f in $$GN_FILES; do \
		mv $$f $${f%.gn}.gno; \
		GNOROOT="$(PWD)/.test" $(GNOCMD) test $(GNO_TEST_FLAGS) $${f%.gn}.gno; \
		mv $${f%.gn}.gno $$f; \
	done

.PHONY: test.pool
test.pool:
	cd .test/examples; GNOROOT="$(PWD)/.test" $(GNOCMD) test $(GNO_TEST_FLAGS) gno.land/r/demo/pool
	GN_FILES="$(wildcard .test/examples/gno.land/r/demo/pool/*.gn)"; \
	for f in $$GN_FILES; do \
		mv $$f $${f%.gn}.gno; \
		GNOROOT="$(PWD)/.test" $(GNOCMD) test $(GNO_TEST_FLAGS) $${f%.gn}.gno; \
		mv $${f%.gn}.gno $$f; \
	done

.PHONY: test.position
test.position:
	cd .test/examples; GNOROOT="$(PWD)/.test" $(GNOCMD) test $(GNO_TEST_FLAGS) gno.land/r/demo/position
	GN_FILES="$(wildcard .test/examples/gno.land/r/demo/position/*.gn)"; \
	for f in $$GN_FILES; do \
	  	mv $$f $${f%.gn}.gno; \
		GNOROOT="$(PWD)/.test" $(GNOCMD) test $(GNO_TEST_FLAGS) $${f%.gn}.gno; \
		mv $${f%.gn}.gno $$f; \
	done


.PHONY: test.router
test.router:
	cd .test/examples; GNOROOT="$(PWD)/.test" $(GNOCMD) test $(GNO_TEST_FLAGS) gno.land/r/demo/router
	GN_FILES="$(wildcard .test/examples/gno.land/r/demo/router/*.gn)"; \
	for f in $$GN_FILES; do \
		mv $$f $${f%.gn}.gno; \
		GNOROOT="$(PWD)/.test" $(GNOCMD) test $(GNO_TEST_FLAGS) $${f%.gn}.gno; \
		mv $${f%.gn}.gno $$f; \
	done

.PHONY: test.staker
test.staker:
	cd .test/examples; GNOROOT="$(PWD)/.test" $(GNOCMD) test $(GNO_TEST_FLAGS) gno.land/r/demo/staker
	GN_FILES="$(wildcard .test/examples/gno.land/r/demo/staker/*.gn)"; \
	for f in $$GN_FILES; do \
		mv $$f $${f%.gn}.gno; \
		GNOROOT="$(PWD)/.test" $(GNOCMD) test $(GNO_TEST_FLAGS) $${f%.gn}.gno; \
		mv $${f%.gn}.gno $$f; \
	done

.PHONY: test.integration
test.integration: clean test.prepare test.gov test.pool test.position test.router test.staker ## Run integration tests.

