FROM golang:1.25-alpine

# Install dependencies
RUN apk add --no-cache \
    git \
    bash \
    python3 \
    py3-pip \
    make \
    jq

WORKDIR /app

# Clone the toolchain that backs the current Pearl testnet.
RUN git clone --branch chain/pearl --single-branch --depth 1 \
    https://github.com/gnolang/gno.git /app/gno

# Build gno tools
WORKDIR /app/gno
RUN make install.gno

# Set environment variables
ENV PATH="/root/go/bin:${PATH}"
ENV GOPATH="/root/go"

# Create directory for contract code
WORKDIR /app

# Copy entrypoint script
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["--help"]
