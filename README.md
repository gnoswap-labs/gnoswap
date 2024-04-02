# Gnoswap Contracts

This repository contains smart contracts (realms) for Gnoswap. You can run tests, as guided below, to see how it operates.

_Note: The contracts are currently in active development and are not yet in production. We will manage the code through release versions, and an official production version of the contracts will be released prior to the launch._

## Prerequisite

### Set your working directory to `WORKDIR`

```
$ export WORKDIR=~/work
```

### Build Gno.land for Gnoswap

Clone the `gno` repository from `gnoswap-labs`. And switch to the `master_20240401` branch. You will be able to clone the repository and build it after running the following commands:

```
$ cd $WORKDIR
$ git clone https://github.com/gnoswap-labs/gno.git gno
$ cd gno
$ git checkout master_20240401
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
   # copy grc20 tokens
   $ cp -R __local/grc20_tokens/* $WORK_DIR/gno/examples/gno.land/r/demo
   $ cp -R _deploy/r/demo/* $WORK_DIR/gno/examples/gno.land/r/demo
   
   # copy gnoswap base packages ( includes uint256, int256 and bit of pool calculation )
   $ cp -R _deploy/p/demo/gnoswap $WORK_DIR/gno/examples/gno.land/p/demo
   
   # copy gnoswap base realms ( includes common logic, variables and consts )
   $ cp -R _deploy/r/gnoswap $WORK_DIR/gno/examples/gno.land/r/gnoswap
   
   # copy gnoswap realms
   $ cp -R gov pool position router staker $WORK_DIR/gno/examples/gno.land/r/demo
   ```

3. Move all test cases into its own directory:
   ```
   # Governance
   $ cd $WORKDIR/gno/examples/gno.land/r/demo/gov
   $ mv _TEST_/* .
   
   # Pool
   $ cd $WORKDIR/gno/examples/gno.land/r/demo/pool
   $ mv _TEST_/* .
   
   # Position
   $ cd $WORKDIR/gno/examples/gno.land/r/demo/position
   $ mv _TEST_/* .
   
   # Router
   $ cd $WORKDIR/gno/examples/gno.land/r/demo/router
   $ mv _TEST_/* .
   
   # Staker
   $ cd $WORKDIR/gno/examples/gno.land/r/demo/staker
   $ mv _TEST_/* .
   ```

### Run the Test Cases

```
$ gno test -root-dir $WORKDIR/gno-for-swap -verbose=true $WORKDIR/gno/examples/gno.land/r/demo/{CONTRACT_FOLDER_HERE}
```

## Integration Tests

The contracts can be tested using [testscript](https://github.com/gnolang/gno/blob/d54ca62749f79a6992da520e1659ba0dbbdd980b/gno.land/pkg/integration/doc.go)

### Change Admin Address
1. Open `$WORKDIR/gno/examples/gno.land/r/gnoswap/consts/consts.gno`
2. Change `GNOSWAP_ADMIN`, `FEE_COLLECTOR` to `g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5`

### Testing
```
$ cd $WORKDIR/gnoswap
$ cp __local/test/gnoswap.txtar $WORKDIR/gno/gno.land/cmd/gnoland/testdata/
$ cd $WORKDIR/gno/gno.land/cmd/gnoland
$ go test -v . -run Testdata/gnoswap
```