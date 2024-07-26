# GnoSwap Contracts

This repository contains smart contracts (realms) for GnoSwap.

## Setting Up and Testing GnoSwap Contracts

This section guides you through the process of setting up Gnoswap contracts. The process involves three main steps: cloning the Gnoswap repository, copying the contracts to the gno directory, and moving test cases to their respective directories.

To set up Gnoswap contracts in Gno Core, follow these steps:

1. Clone the `gnoswap` contracts repository:

   > Tip: If `$WORKDIR` is home directory, then `$WORKDIR` is `~/`.

   ```bash
   cd $WORKDIR
   git clone https://github.com/gnoswap-labs/gnoswap.git
   cd gnoswap
   ```

2. Copy the `gnoswap` contracts into the cloned `gno` repository:

   ```bash
   # copy grc20 tokens
   cp -R __local/grc20_tokens/* $WORKDIR/gno/examples/gno.land/r/demo
   cp -R _deploy/r/gnoswap $WORKDIR/gno/examples/gno.land/r/demo

   # copy gnoswap base packages ( includes uint256, int256 and bit of pool calculation )
   cp -R _deploy/p/gnoswap $WORKDIR/gno/examples/gno.land/p/demo

   # copy gnoswap base realms ( includes common logic, variables and consts )
   cp -R _deploy/r/gnoswap $WORKDIR/gno/examples/gno.land/r/demo/gnoswap

   # copy gnoswap realms
   cp -R pool position router staker $WORKDIR/gno/examples/gno.land/r/demo
   ```

3. Move all test cases into its own directory:

Move the test cases for each contract to their respective directories. It's not necessary to move all tests; you can selectively move only the tests you need. However, files containing `VARS_HELPERS` in their name must be moved.

   ```bash
   # Pool
   cd $WORKDIR/gno/examples/gno.land/r/demo/pool
   mv _TEST_/* .

   # Position
   cd $WORKDIR/gno/examples/gno.land/r/demo/position
   mv _TEST_/* .

   # Router
   cd $WORKDIR/gno/examples/gno.land/r/demo/router
   mv _TEST_/* .

   # Staker
   cd $WORKDIR/gno/examples/gno.land/r/demo/staker
   mv _TEST_/* .
   ```

### Running Tests

While it's possible to run tests in the cloned gno directory (where the above setup process was completed), it's recommended to run them in the gnoswap directory to avoid confusion due to the large number of changed files.

First, navigate to the gnoswap directory:

```bash
cd gnoswap
```

Next, move to the Realm directory you want to test (such as pool, staker, etc.), then run the tests using the gno test command:

```bash
gno test -v . # or specify a particular test file path
```
