# Community Pool

GnoSwap community treasury for ecosystem development.

## Overview

Community-governed treasury that receives protocol emissions and fees for ecosystem growth initiatives. Also collects unclaimed internal staking rewards from warmup periods.

## Configuration

- **Emission Allocation**: 5% of GNS emissions (default)
- **Governance Control**: All disbursements require proposal
- **Fund Sources**: GNS emissions, unclaimed rewards (internal reward only), protocol fees

## Governance Process

- **Proposal Creation**: Submit funding request with justification
- **Voting Period**: Token holders vote on proposal
- **Execution**: Approved transfers execute automatically
- **Transparency**: All operations emit events

## Key Functions

### `TransferToken`
Transfers tokens to specified address (governance only).

## Usage

```go
// Transfer via governance proposal
TransferToken(
    "gno.land/r/demo/usdc",
    recipientAddr,
    1000000,
)
```

## Security

- Governance-only transfers
- No emergency withdrawals
- Event emission for transparency
- Multi-token support