# Community Pool

GnoSwap community treasury for ecosystem development.

## Overview

Community-governed treasury that receives protocol emissions and fees for ecosystem growth initiatives. Also collects unclaimed internal staking rewards from warmup periods.

## Configuration

- **Emission Allocation**: 5% of GNS emissions (default)
- **Transfer Control**: Admin or governance may disburse tokens while withdrawals are enabled.
- **Fund Sources**: GNS emissions, unclaimed rewards (internal reward only), protocol fees

## Governance Process

- **Proposal Creation**: Submit funding request with justification
- **Voting Period**: Token holders vote on proposal
- **Execution**: Approved transfers execute automatically
- **Transparency**: All operations emit events

## Key Functions

### `TransferToken`
Transfers tokens to a specified address (admin or governance; blocked by the withdrawal halt).

## Gnoweb

`Render("")` shows the admin and governance role addresses and the withdrawal halt
checked by `TransferToken`. It does not enumerate token balances or claim a total
treasury value. Query a specific registered token with `GetBalanceOf(tokenPath)`.
Unsupported paths return `404`.

## Usage

```go
// Transfer via governance proposal
TransferToken(
    cross(cur),
    "gno.land/r/demo/usdc",
    recipientAddr,
    1000000,
)
```

## Security

- Admin-or-governance transfers, subject to the withdrawal halt
- No emergency withdrawals
- Event emission for transparency
- Multi-token support
