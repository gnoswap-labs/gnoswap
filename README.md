# Gnoswap Contracts

This repository contains smart contracts (realms) for Gnoswap. You can run tests, as guided below, to see how it operates.

_Note: The contracts are currently in active development and are not yet in production. We will manage the code through release versions, and an official production version of the contracts will be released prior to the launch._

## Prerequisite

### Set your working directory to `WORKDIR`

```
$ export WORKDIR=~/work
```

### Build Gno.land for Gnoswap

Clone the `gno` repository from `gnoswap-labs`. And switch to the `gs/base_clean` branch. You will be able to clone the repository and build it after running the following commands:

```
$ cd $WORKDIR
$ git clone https://github.com/gnoswap-labs/gno.git gno-for-swap
$ cd gno-for-swap
$ git checkout gs/base_clean
$ make install
```

## Unit Tests

To run unit tests, follow these steps:

### Set Up Gnoswap Contracts in Gno Core

1. Clone the `gnoswap` contracts repository:

   ```
   $ cd $WORKDIR
   $ git clone https://github.com/gnoswap-labs/gnoswap.git
   $ cd gnoswap
   ```

2. Copy the `gnoswap` contracts into the Gno core:

   ```
   $ cp -R _setup/* consts gov pool position router staker $WORKDIR/gno-for-swap/examples/gno.land/r/demo/
   $ cp -R common $WORKDIR/gno-for-swap/examples/gno.land/p/demo/
   ```

### Run the Test Cases

```
$ gno test -root-dir $WORKDIR/gno-for-swap -verbose=true $WORKDIR/gno-for-swap/examples/gno.land/r/demo/staker
```

## Integration Tests

The contracts can be tested by deploying and executing the contract directly through Gno Chain locally.

### Create accounts for testing

You can pass this step if you already created the accounts with same mnemonic shown below.

```
$ cd $WORKDIR/gnoswap
$ _test/init_test_accounts.sh
```

### Testing

The Gno.land blockchain can be run using docker.

```
$ docker run --rm -p 26657:26657 --platform linux/amd64 gnoswap/gnoland
```

```
$ cd $WORKDIR/gnoswap
$ make -f _test/live_test.mk all
```
