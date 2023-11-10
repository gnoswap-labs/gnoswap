FROM gnoswap/gnokey

RUN apt update && apt install -y make curl jq && apt clean

WORKDIR /opt/gnoswap
ADD . .

ENV GNOLAND_RPC_URL "localhost:26657"

CMD ["/bin/bash","-c","_test/init_test_accounts.sh && make -f _test/phase_v2.mk all"]
# CMD ["/bin/bash","-c","_test/init_test_accounts.sh && make -f _test/phase_v1.mk all"]
