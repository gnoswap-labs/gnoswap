# GnoSwap Contracts

Smart contracts for GnoSwap AMM DEX on Gno.land.

## Prerequisites

- GNU Make 3.81 or higher
- Latest version of [gno.land](https://github.com/gnolang/gno)
- Python 3.12 or higher

## Setup

```bash
# Quick setup in home directory
python3 setup.py

# Setup in custom directory
python3 setup.py -w /path/to/workdir

# Clone repository and setup
python3 setup.py -c

# Clone to custom directory
python3 setup.py -w /path/to/workdir -c
```

Options:

- `-w` or `--workdir`: Specify working directory (default: home directory)
- `-c` or `--clone`: Clone gnoswap repository before setup

If the setup script fails, you can manually copy contracts:

1. Clone repository:

```bash
git clone https://github.com/gnoswap-labs/gnoswap.git
```

2. Copy packages:

```bash
mkdir -p $WORKDIR/gno/examples/gno.land/p/gnoswap
cp -R contract/p/gnoswap/* $WORKDIR/gno/examples/gno.land/p/gnoswap/
```

3. Copy realms:

```bash
mkdir -p $WORKDIR/gno/examples/gno.land/r/gnoswap/v1
cp -R contract/r/gnoswap/* $WORKDIR/gno/examples/gno.land/r/gnoswap/v1/
```

4. Copy test tokens:

```bash
cp -R contract/r/gnoswap/test_token/* $WORKDIR/gno/examples/gno.land/r/
```

## Directory Structure

```
gnoswap/
├── contract/                       # Smart contracts
│   ├── p/                          # Packages (libraries)
│   │   └── gnoswap/
│   │       ├── gnsmath/            # AMM math utilities
│   │       ├── int256/             # 256-bit signed integers
│   │       ├── uint256/            # 256-bit unsigned integers
│   │       ├── rbac/               # Role-based access control
│   │       └── consts/             # Protocol constants
│   │
│   └── r/                          # Realms (contracts)
│       └── gnoswap/
│           ├── v1/                 # Protocol v1 contracts
│           │   ├── pool/           # Concentrated liquidity pools
│           │   ├── position/       # LP position NFTs
│           │   ├── router/         # Swap routing
│           │   ├── staker/         # Liquidity mining
│           │   ├── gov/            # Governance
│           │   ├── launchpad/      # Token distribution
│           │   ├── protocol_fee/   # Fee management
│           │   └── community_pool/ # Treasury
│           │
│           ├── access/             # Access control
│           ├── emission/           # GNS emission
│           ├── gns/                # GNS token
│           ├── halt/               # Emergency pause
│           ├── rbac/               # RBAC realm
│           ├── referral/           # Referral system
│           └── test_token/         # Test tokens
│
├── tests/                          # Test suites
│   ├── scenario/                   # Scenario-based tests
│   ├── integration/                # Integration tests
│   └── deploy/                     # Deployment scripts
│
└── scripts/                        # Utility scripts
```

## Testing

### Run All Tests

```bash
make test
```

### Run Specific Scenario Tests

```bash
make test-folder FOLDER=tests/scenario/pool
make test-folder FOLDER=tests/scenario/router
```

### Run Integration Tests

```bash
cd $WORKDIR/gno/examples
gno test -root-dir $WORKDIR/gno -v=false ./gno.land/r/gnoswap/v1/pool
```

## Security

GnoSwap implements multiple layers of security across all contracts. For security concerns or vulnerability reports, see [SECURITY.md](SECURITY.md).

## License

Licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please follow existing patterns, include tests, and maintain documentation.
