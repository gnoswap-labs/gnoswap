.PHONY: fmt
fmt:
	find . -name "*.gno" -type f -exec gofumpt -w {} \;
