# GnoSwap Contracts

Smart contracts for GnoSwap AMM DEX on Gno.land.

## Prerequisites

- GNU Make 3.81 or higher
- Latest version of [gno.land](https://github.com/gnolang/gno)

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
