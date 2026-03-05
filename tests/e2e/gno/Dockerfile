FROM golang:1.24-alpine AS builder

RUN apk add --no-cache git make

RUN git clone --branch tbruyelle/origin-send-filter --single-branch --depth 1 \
    https://github.com/tbruyelle/gno.git /src/gno

RUN git clone --depth 1 https://github.com/allinbits/gno-realms.git /src/gno-realms

WORKDIR /src/gno

RUN cd contribs/gnodev && go build -o /usr/local/bin/gnodev .
RUN cd gno.land/cmd/gnokey && go build -o /usr/local/bin/gnokey .

FROM alpine:3.21

RUN apk add --no-cache curl bash

COPY --from=builder /usr/local/bin/gnodev /usr/local/bin/gnodev
COPY --from=builder /usr/local/bin/gnokey /usr/local/bin/gnokey
COPY --from=builder /src/gno /gnoroot
COPY --from=builder /src/gno-realms/gno.land /aibgno/gno.land

ENV GNOROOT=/gnoroot

COPY gno/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 26657 8888 8546

ENTRYPOINT ["/entrypoint.sh"]
