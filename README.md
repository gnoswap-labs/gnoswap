# GnoSwap Contracts

This repository contains smart contracts (realms) for GnoSwap.

## Index

- [Setting Up and Testing GnoSwap Contracts](#setting-up-and-testing-gnoswap-contracts)
  - [Prerequisites](#prerequisites)
  - [Setting Up GnoSwap Contracts](#setting-up-gnoswap-contracts)
  - [Running Tests](#running-tests)
- [Realms](#realms)
  - [Core Realms Deployed on Testnet4](#core-realms-deployed-on-testnet4)
  - [Pool](#pool)
  - [Position](#position)
  - [Router](#router)
  - [Staker](#staker)

## Setting Up and Testing GnoSwap Contracts

There are two ways to set up GnoSwap contracts: using the provided setup script or manually following the steps below.

### Prerequisites

- GNU Make 3.81 or higher
- Latest version of [gno.land](https://github.com/gnolang/gno)
- Python 3.12 or higher

### Using the Setup Script

> Note: If you're using the script, you don't need to manually perform the steps listed in the next section.

For convenience, we provide a Python script that automates the setup process. This script can clone the repository, copy contracts, and move test files as needed.

- To set up in your home directory without cloning the repository:

  ```bash
  python3 setup.py
  ```

- To set up in a specific directory without cloning:

  ```bash
  python3 setup.py -w /path/to/workdir
  ```

- To clone the repository and set up in your home directory:

  ```bash
  python3 setup.py -c
  ```

- To clone the repository and set up in a specific directory:

  ```bash
  python3 setup.py -w /path/to/workdir -c
  ```

Options:

- `-w` or `--workdir`: Specify the working directory (default is your home directory)
- `-c` or `--clone`: Clone the gnoswap repository before setting up

The script will perform all necessary steps to set up the GnoSwap contracts in the specified directory.

<details>
<summary><h3>Setting Up GnoSwap Contracts Manually</h3></summary>

> Important: This manual setup method is not recommended and should only be used as a last resort. If the setup script is not working properly, please create an issue in the repository.

This section guides you through the process of setting up GnoSwap contracts. The process involves three main steps: cloning the `gnoswap` repository, copying the contracts to the `gno` directory, and moving test cases to their respective directories.

1. Clone the repository:

   ```bash
   cd $WORKDIR
   git clone https://github.com/gnoswap-labs/gnoswap.git
   cd gnoswap
   ```

2. Understand the directory structure pattern:

   ```tree
   contract/
   ├── p/  # Packages directory
   │   └── gnoswap/
   │       ├── consts/
   │       ├── gnsmath/
   │       └── ...
   └── r/  # Realms directory
       └── gnoswap/
           ├── common/
           ├── pool/
           └── ...
   ```

3. Create the base directories:

   ```bash
   # Create directories for packages and realms
   mkdir -p $WORKDIR/gno/examples/gno.land/p/gnoswap
   mkdir -p $WORKDIR/gno/examples/gno.land/r/gnoswap/v1
   ```

4. Copy files following these patterns:

   For packages:

   ```bash
   # Pattern:
   cp -R contract/p/gnoswap/<package_name> $WORKDIR/gno/examples/gno.land/p/gnoswap/

   # Examples:
   cp -R contract/p/gnoswap/consts $WORKDIR/gno/examples/gno.land/p/gnoswap/
   cp -R contract/p/gnoswap/gnsmath $WORKDIR/gno/examples/gno.land/p/gnoswap/
   ```

   For realm modules:

   ```bash
   # Pattern:
   cp -R contract/r/gnoswap/<module_name> $WORKDIR/gno/examples/gno.land/r/gnoswap/v1/

   # Examples:
   cp -R contract/r/gnoswap/pool $WORKDIR/gno/examples/gno.land/r/gnoswap/v1/
   cp -R contract/r/gnoswap/router $WORKDIR/gno/examples/gno.land/r/gnoswap/v1/
   ```

   For test tokens:

   ```bash
   # Pattern:
   cp -R contract/r/gnoswap/test_token/<token_name> $WORKDIR/gno/examples/gno.land/r/

   # Example:
   cp -R contract/r/gnoswap/test_token/usdc $WORKDIR/gno/examples/gno.land/r/
   ```

5. Verify the setup:

   ```bash
   cd $WORKDIR/gno/examples
   gno test -root-dir $WORKDIR/gno -v=false ./gno.land/r/gnoswap/v1/pool
   ```

> Note: The setup maintains the original directory structure, including test files which are now part of their respective packages.

</details>

### Directory Structure Overview

Key directories and their purposes:

- `p/gnoswap/`: Core packages including math utilities and constants
- `r/gnoswap/v1/`: Protocol realms (pool, router, position, etc.)
- `r/gnoswap/test_token/`: Test tokens for development

Once you understand these patterns, you can copy any additional modules using the same structure.

### Running Tests

While it's possible to run tests in the cloned `gno` directory (where the above setup process was completed), it's recommended to run them in the `gnoswap` directory to avoid confusion due to the large number of changed files.

First, navigate to the `gno/examples` directory:

```bash
cd $WORKDIR/gno/examples
```

Next, move to the Realm directory you want to test (such as `pool`, `staker`, etc.), then run the tests using the `gno test` command:

```bash
gno test -root-dir $WORKDIR/gno -v=false ./gno.land/r/gnoswap/v1/pool
```

## Realms

This section provides information about the core realms of GnoSwap that have been deployed.

### Core Realms Deployed on Testnet4

- pool: [gno.land/r/gnoswap/v1/pool](https://gnoscan.io/realms/details?path=gno.land%2Fr%2Fgnoswap%2Fv2%2Fpool)
- position: [gno.land/r/gnoswap/v1/position](https://gnoscan.io/realms/details?path=gno.land%2Fr%2Fgnoswap%2Fv2%2Fposition)
- router: [gno.land/r/gnoswap/v1/router](https://gnoscan.io/realms/details?path=gno.land%2Fr%2Fgnoswap%2Fv2%2Frouter)
- staker: [gno.land/r/gnoswap/v1/staker](https://gnoscan.io/realms/details?path=gno.land%2Fr%2Fgnoswap%2Fv2%2Fstaker)

### Pool

Pool is a core component of GnoSwap, a smart contract that facilitates liquidity provision and trading between two GRC20 tokens. Each pool has a unique token pair, fee tier, and customizable liquidity range, leveraging Uniswap V3's concentrated liquidity mechanism.

Key features:

- Composed of two GRC20 tokens.
- Allows liquidity provision within a user-defined, customizable price range.
- Supports various fee tiers, suitable for different trading strategies.
- Dynamically adjusts liquidity according to price fluctuations.

### Position

Position is a GRC721 NFT (non-fungible token) representing the liquidity provider's (LP's) unique liquidity position. Each position has the following key functions and properties:

1. Minting: Users can create a new position by providing liquidity within a specific price range.

2. Liquidity Increase/Decrease: The liquidity of an existing position can be increased or decreased.

3. Fee Collection: Trading fees generated by the position can be collected.

4. Repositioning: The price range of an existing position can be adjusted.

Each position has unique characteristics, making it non-fungible. Positions store information such as the owner's address, price range (upper and lower ticks), amount of liquidity and accumulated fees.

Within the same pool, the liquidity of position with overlapping price range is merged within the same tick. This structure allows for more precise control of liquidity provision and better capital efficiency.

### Router

The Router in GnoSwap is responsible for executing token swaps and managing swap routes. It provides the following key functionalities:

1. `SwapRoute`: Executes token swaps based on specified routes and swap types (`EXACT_IN` or `EXACT_OUT`). It handles single and multi-hop swaps, supporting up to 3~7 routes.

2. `DrySwapRoute`: Simulates swap routes without executing the actual swap. useful for estimating swap outcomes.

3. Fee Management: Implements a protocol fee for swaps, which can be adjusted by admin or governance.

4. Support for both native `GNOT` and wrapped `WUGNOT` tokens.

The Router plays a role by efficiently routing trades and ensuring optimal execution of swaps across various liquidity pools.

### Staker

The `Staker` manages LP token staking and reward distribution. It offers the following key functionalities:

1. Stake Token: Allows users to stake LP tokens, enabling them to earn rewards.

2. Collect Reward: Enables stakers to collect accumulated rewards from their staked positions.

3. Unstake Token: Allows users to withdraw their staked LP tokens and collect all accumulated rewards.

4. Create External Incentive: Permits users to create additional reward incentives for specific liquidity pools.

5. End External Incentive: Allows the creator or admin to terminate an external incentive and refund remaining rewards.

Key features of the Staker include:

- Support for both internal (protocol-native) and external (user-created) incentives.
- Flexible reward distribution mechanisms for different incentive types.
- Safety checks to ensure proper staking, unstaking, and reward collection processes.
- Management of GNS token emissions for internal rewards.
- Handling of native GNOT and wrapped WUGNOT tokens for rewards.

The staker is a crucial components for GnoSwap's tokenomics by incentivizing liquidity provision and allowing for community-driven reward programs. It enhances the overall ecosystem by promoting long-term liquidity.
