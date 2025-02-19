.PHONY: fmt docker-build
fmt:
	find . -name "*.gno" -type f -exec gofumpt -w {} \;

docker-build:
	docker build -t gnoswap-ci .
