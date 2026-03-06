.PHONY: up down test test-only test-keep-up clean logs build

GOMODCACHE ?= $(CURDIR)/.cache/gomod
GOCACHE ?= $(CURDIR)/.cache/go-build
up:
	docker compose up -d --build --force-recreate

down:
	docker compose down -v

test:
	docker compose up -d --build --force-recreate
	$(MAKE) test-only; ret=$$?; docker compose down -v; exit $$ret

test-keep-up:
	docker compose up -d --build --force-recreate
	$(MAKE) test-only

test-only:
	mkdir -p "$(GOMODCACHE)" "$(GOCACHE)"
	GOMODCACHE="$(GOMODCACHE)" GOCACHE="$(GOCACHE)" go test -v -timeout 15m -count=1 ./...

clean:
	docker compose down -v --rmi local

logs:
	docker compose logs -f

build:
	docker compose build
