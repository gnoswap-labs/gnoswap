# Gnoswap Contracts

This repository contains smart contracts (realms) for Gnoswap. You can run unit tests, as guided below, to see how it operates.

_Note: The contracts are currently in active development and are not yet in production. We will manage the code through release versions, and an official release of contracts will be announced before our launch._


## Running Unit Tests

To run unit tests, follow these steps:

### 1. Set Your Working Directory
Set your working directory to `WORKDIR` (e.g., `export WORKDIR=~/work`).

### 2. Build Gno.land for Gnoswap
1. Clone the `gno` repository from `gnoswap-labs` and switch to the `gs/base_clean` branch. You will clone the repository in the `gno-for-swap` directory after running the following commands:

```
$ cd $WORKDIR
$ git clone https://github.com/gnoswap-labs/gno.git gno-for-swap
$ cd gno-for-swap
$ git checkout gs/base_clean
```

2. Build and Install Gno:

```
$ make install
```


### 3. Set Up Gnoswap Contracts in Gno Core

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

### 4. Run the Test Cases

```
$ gno test -root-dir $WORKDIR/gno-for-swap -verbose=true $WORKDIR/gno-for-swap/examples/gno.land/r/staker
```

