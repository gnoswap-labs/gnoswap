# Local Environment Configuration

# RPC and Chain Configuration
GNOLAND_RPC_URL ?= localhost:26657
CHAINID ?= dev

# Contract Addresses
ADDR_WUGNOT := g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum
ADDR_POOL := g1dexaf6aqkkyr9yfy9d5up69lsn7ra80af34g5v
ADDR_POSITION := g1y3uyaa63sjxvah2cx3c2usavwvx97kl8m2v7ye
ADDR_ROUTER := g1vc883gshu5z7ytk5cdynhc8c2dh67pdp4cszkp
ADDR_STAKER := g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
ADDR_PROTOCOL_FEE := g1r340tuven27z8wq50u8d20eqrsj470082682tp
ADDR_GOV_STAKER := g1em9s40nfrwd2aqn9ypjv7d9x9z9c8uk5uxrza9
ADR_GOV_GOV := g109hw2sc704c2vnxy2y89vjyqluvzra8rhp4l8w
ADDR_LAUNCHPAD := g1x6r75sxlkp9zfqufew0vcuq9sfclsq8uaqkru9
ADDR_GNS := g13ffa5r3mqfxu3s7ejl02scq9536wt6c2t789dm
ADDR_GNFT := g1mclfz2dn4lnez0lcjwgz67hh72rdafjmufvfmw

# User Addresses (used for test scripts)
ADDR_GNOSWAP := g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c
ADDR_ADMIN := g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
ADDR_TEST := g1mjqcxzek8yacgcvnqfkj0dck67wdyhqlfp9unr

# Test User Addresses
ADDR_TEST_ADMIN := g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c
ADDR_USER_1 := # SET ACCOUNTS FOR TESTING
ADDR_USER_2 := # SET ACCOUNTS FOR TESTING
ADDR_USER_3 := # SET ACCOUNTS FOR TESTING
ADDR_USER_4 := # SET ACCOUNTS FOR TESTING

# Incentive Configuration
TOMORROW_MIDNIGHT := $(shell (gdate -ud 'tomorrow 00:00:00' +%s))
INCENTIVE_END := $(shell expr $(TOMORROW_MIDNIGHT) + 7776000) # 7776000 SECONDS = 90 DAY

# Transaction Configuration
MAX_APPROVE := 9223372036854775806
TX_EXPIRE := 9999999999

# Path Configuration
MAKEFILE := $(shell realpath $(firstword $(MAKEFILE_LIST)))
ROOT_DIR := $(shell cd $(shell dirname $(MAKEFILE))/../.. && pwd)

