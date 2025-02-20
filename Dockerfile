FROM ubuntu:latest

ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    wget \
    software-properties-common \
    sudo \
    python3 \
    python3-pip \
    python3-venv \
    sed \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz && \
    rm go1.22.0.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin
ENV GOPATH=/go
ENV PATH=$PATH:/go/bin

RUN apt-get update && apt-get install -y \
    autoconf \
    bison \
    patch \
    rustc \
    libssl-dev \
    libyaml-dev \
    libreadline6-dev \
    zlib1g-dev \
    libgmp-dev \
    libncurses5-dev \
    libffi-dev \
    libgdbm6 \
    libgdbm-dev \
    libdb-dev \
    uuid-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/rbenv/ruby-build.git && \
    cd ruby-build && \
    PREFIX=/usr/local ./install.sh && \
    cd .. && \
    rm -rf ruby-build

RUN ruby-build 3.4.0 /usr/local

RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y python3.12 python3.12-venv python3.12-dev && \
    rm -rf /var/lib/apt/lists/* && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

RUN mkdir -p /home/gnoswap/workdir
WORKDIR /home/gnoswap/workdir

# copy scripts and register permissions
COPY .github/scripts/generate_matrix.rb /home/gnoswap/workdir/.github/scripts/
COPY .github/scripts/run_tests.rb /home/gnoswap/workdir/.github/scripts/
COPY setup.py /home/gnoswap/workdir/
RUN chmod +x /home/gnoswap/workdir/.github/scripts/generate_matrix.rb && \
    chmod +x /home/gnoswap/workdir/.github/scripts/run_tests.rb

# clone gno repository
RUN git clone https://github.com/gnolang/gno.git -b master && \
    cd gno && \
    sed -i 's/ctx.Timestamp += (count \* 5)/ctx.Timestamp += (count \* 2)/g' ./gnovm/tests/stdlibs/std/std.go && \
    make install.gno

ENV PATH=$PATH:/home/gnoswap/workdir/gno/bin
ENV PATH=$PATH:/home/gnoswap/workdir/bin
ENV GNO_ROOT_DIR=/home/gnoswap/workdir/gno

# entrypoint script
RUN echo '#!/bin/bash\n\
if [ "$1" = "test" ]; then\n\
  cd /home/gnoswap/workdir\n\
  ls -la ./gno/examples/gno.land/p/gnoswap || true\n\
  ruby .github/scripts/run_tests.rb -f "$2" -r "/home/gnoswap/workdir/gno"\n\
else\n\
  exec "$@"\n\
fi' > /entrypoint.sh && \
chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
