FROM golang:1.25-alpine

RUN apk add --no-cache git bash

ENV GNO_TOOLCHAIN=/opt/gno-toolchain
COPY scripts/gno.sh /usr/local/bin/gno.sh
RUN gno.sh setup

WORKDIR /app
ENTRYPOINT ["/app/scripts/docker-entrypoint.sh"]
CMD ["--help"]
