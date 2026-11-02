# GnoSwap Contracts

Smart contracts for GnoSwap AMM DEX on Gno.land.

## Prerequisites

- Go 1.25+ and GNU Make, or [mise](https://mise.jdx.dev) (installs Go from `mise.toml`)
- Python 3.11+ for the integration-test helpers
- Docker and the `docker-compose` command for integration tests

## Directory Structure

```
gnoswap/
├── contract/                       # Smart contracts
│   ├── p/                          # Packages (libraries)
│   │   └── gnoswap/
│   │       ├── gnsmath/v1/         # AMM math utilities
│   │       ├── int256/v1/          # 256-bit signed integers
│   │       ├── uint256/v1/         # 256-bit unsigned integers
│   │       ├── rbac/v1/            # Role-based access control
│   │       └── consts/v1/          # Protocol constants
│   │
│   └── r/                          # Realms (contracts)
│       ├── gnoswap/
│       │   ├── pool/               # Pool proxy, storage, and v1/
│       │   ├── position/           # LP position proxy, storage, and v1/
│       │   ├── router/             # Swap proxy, storage, and v1/
│       │   ├── staker/             # Liquidity mining proxy, storage, and v1/
│       │   ├── gov/                # Governance/staker proxies and v1/; xGNS
│       │   ├── launchpad/          # Launchpad proxy, storage, and v1/
│       │   ├── protocol_fee/       # Fee proxy, storage, and v1/
│       │   ├── community_pool/v1/  # Treasury transfers
│       │   ├── access/v1/          # Access control
│       │   ├── emission/           # GNS emission distribution
│       │   ├── gns/                # GNS token
│       │   ├── gnft/               # Position NFT and metadata
│       │   ├── halt/v1/            # Emergency pause
│       │   ├── rbac/v1/            # RBAC realm
│       │   ├── referral/v1/        # Referral system
│       │   └── test_token/         # Test tokens
│       └── scenario/              # Scenario/filetest packages
│
├── tests/                          # Test suites
│   ├── integration/                # Integration tests
│   └── deploy/                     # Deployment scripts
│
└── scripts/                        # Utility scripts
```

## Testing

### Run Package Tests

Build the toolchain once (re-run to update it). It clones the
[GnoSwap Gno fork](https://github.com/gnoswap-labs/gno) at `GNO_REF` (default
`master`) into `~/.cache/gno-toolchains/gnoswap-<GNO_REF>` and builds `gno`
and `gnokey` there:

```bash
make gno-setup        # or: mise run setup
```

Then run tests from the repository root. `contract/` is a `gnowork.toml`
workspace, so `gno test` runs on this checkout directly:

```bash
make test PKG=gno.land/r/gnoswap/pool/v1
make test PKG=gno.land/r/gnoswap/pool/v1 RUN=TestCreatePool
mise run test gno.land/r/gnoswap/pool/v1 -run TestCreatePool
mise run test ./p/gnoswap/gnsmath/v1   # path relative to contract/
```

`PKG` is a module path or a path under `contract/`; without it every package
is tested.

### Run Scenario Tests

```bash
make test PKG=gno.land/r/gnoswap/scenario/pool
make test PKG=gno.land/r/gnoswap/scenario/router
```

### Run Integration Tests

```bash
make integration-test-build
make integration-test-list
make integration-test-run TEST=pool_create_pool_and_mint
make integration-test
```

## Security

GnoSwap implements multiple layers of security across all contracts. For security concerns or vulnerability reports, see [SECURITY.md](SECURITY.md).

## License

Licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please follow existing patterns, include tests, and maintain documentation.
