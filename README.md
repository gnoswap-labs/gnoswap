# Gnoswap Contracts

This repository contains smart contracts (realms) for Gnoswap. You can run tests, as guided below, to see how it operates.

_Note: The contracts are currently in active development and are not yet in production. We will manage the code through release versions, and an official production version of the contracts will be released prior to the launch._

## Prerequisite

### Set your working directory to `WORKDIR`

```
$ export WORKDIR=~/work
```

### Build Gno.land for Gnoswap

Clone the `gno` repository from `gnoswap-labs`. And switch to the `gs/base_clean` branch.
You will be able to clone the repository and build it after running the following commands:

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
	$ cp -R _setup/* gov pool position staker $WORKDIR/gno-for-swap/examples/gno.land/r/
	```

### Run the Test Cases

```
$ gno test -root-dir $WORKDIR/gno-for-swap -verbose=true $WORKDIR/gno-for-swap/examples/gno.land/r/staker
```

## Integration Tests

The contracts can be tested by deploying and executing the contract directly through Gno Chain locally.

### Create accounts for testing

You can pass this step if you already created the accounts.

```
gnokey add test1 --recover
gnokey add -recover=true -index 10 gsa
gnokey add -recover=true -index 11 lp01
gnokey add -recover=true -index 12 lp02
gnokey add -recover=true -index 13 tr01
```

Create testing accounts using the next mnemonic code.

```
source bonus chronic canvas draft south burst lottery vacant surface solve popular case indicate oppose farm nothing bullet exhibit title speed wink action roast
```

### Testing

The Gno.land blockchain must be cleaned up and run before each tests.

```
$ cd $WORKDIR/gno-for-swap/gno.land
$ rm -r testdir && gnoland start -skip-failing-genesis-txs=true
```

#### Pool

```
$ cd $WORKDIR/gnoswap/_makefile
$ make -f 1_pool.mk all
```

#### Position

```
$ cd $WORKDIR/gnoswap/_makefile
$ make -f 2_position.mk all
```

#### staker

```
$ cd $WORKDIR/gnoswap/_makefile
$ make -f 3_staker.mk all
```
