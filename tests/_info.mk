# r/demo/wugnot from gno
ADDR_WUGNOT := g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum

# based on v1
ADDR_POOL := g148tjamj80yyrm309z7rk690an22thd2l3z8ank
ADDR_POSITION := g1q646ctzhvn60v492x8ucvyqnrj2w30cwh6efk5
ADDR_ROUTER := g1lm2l7tf49h3mykesct7rhfml30yx8dw5xrval7
ADDR_STAKER := g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
ADDR_PROTOCOL_FEE := g1f7wpek7q67tkns27sw495u5yuu3a5wwjxw5l6l
ADDR_GOV_STAKER := g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa
ADR_GOV_GOV := g17s8w2ve7k85fwfnrk59lmlhthkjdted8whvqxd
ADDR_LAUNCHPAD := g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3
ADDR_GNS := g13ffa5r3mqfxu3s7ejl02scq9536wt6c2t789dm
ADDR_GNFT := g1mclfz2dn4lnez0lcjwgz67hh72rdafjmufvfmw

# username address
ADDR_GNOSWAP :=
ADDR_ADMIN :=
ADDR_TEST :=

# INCENTIVE_START
TOMORROW_MIDNIGHT := $(shell (gdate -ud 'tomorrow 00:00:00' +%s))
INCENTIVE_END := $(shell expr $(TOMORROW_MIDNIGHT) + 7776000) # 7776000 SECONDS = 90 DAY

# MAX_UINT64 := 18446744073709551615
MAX_APPROVE := 9223372036854775806
TX_EXPIRE := 9999999999

MAKEFILE := $(shell realpath $(firstword $(MAKEFILE_LIST)))
ROOT_DIR:=$(shell dirname $(MAKEFILE))/../


# TODO: change below 2 values based on which chain to deploy
GNOLAND_RPC_URL ?= localhost:26657
CHAINID ?= dev
