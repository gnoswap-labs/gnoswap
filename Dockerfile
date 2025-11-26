FROM golang:1.24-alpine

# Install dependencies
RUN apk add --no-cache \
    git \
    bash \
    python3 \
    py3-pip \
    make \
    jq

WORKDIR /app

# Clone gno repository (master branch from gnoswap-labs)
RUN git clone --branch master --single-branch --depth 1 \
    https://github.com/gnoswap-labs/gno.git /app/gno

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
