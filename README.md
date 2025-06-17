# GnoSwap Contracts

This repository contains smart contracts (realms) for GnoSwap.

## Index

- [Setting Up and Testing GnoSwap Contracts](#setting-up-and-testing-gnoswap-contracts)
  - [Prerequisites](#prerequisites)
  - [Setting Up GnoSwap Contracts](#setting-up-gnoswap-contracts)
  - [Running Tests](#running-tests)
- [Realms](#realms)
  - [Core Realms Deployed on Testnet5](#core-realms-deployed-on-testnet5)


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

### Core Realms Deployed on Testnet5

- pool: [gno.land/r/gnoswap/v1/pool](https://gnoscan.io/realms/details?path=gno.land/r/gnoswap/v1/pool)
- position: [gno.land/r/gnoswap/v1/position](https://gnoscan.io/realms/details?path=gno.land/r/gnoswap/v1/position)
- router: [gno.land/r/gnoswap/v1/router](https://gnoscan.io/realms/details?path=gno.land/r/gnoswap/v1/router)
- staker: [gno.land/r/gnoswap/v1/staker](https://gnoscan.io/realms/details?path=gno.land/r/gnoswap/v1/staker)

## Development Environment Setup

### Using Docker (Recommended)

1. Build the Docker image:
```bash
make docker-build
```

2. Start the container:
```bash
make docker-up
```

3. Access the container shell:
```bash
make docker-shell
```

4. View logs:
```bash
make docker-logs
```

5. Stop the container:
```bash
make docker-down
```

### Manual Setup

If you prefer to set up the environment manually:

1. Install Python 3.11 or later
2. Install uv package manager:
```bash
pip install uv
```

3. Create a virtual environment and install dependencies:
```bash
uv venv
source .venv/bin/activate  # On Unix/macOS
# or
.venv\Scripts\activate  # On Windows
uv pip install -r requirements.txt
```