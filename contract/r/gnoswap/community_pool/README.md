# Community Pool

GnoSwap community treasury for ecosystem development.

## Overview

The community pool holds registered protocol-owned tokens. The emission system
routes its configured community-pool share to this address, while other
protocol flows may fund it separately. This package exposes a direct,
access-controlled transfer operation; it does not store proposal or voting
state.

## Configuration

- **Emission Allocation**: 5% of GNS emissions (default)
- **Transfer Authorization**: `TransferToken` accepts an admin or governance caller while withdrawals are not halted
- **Token Scope**: Transfers use registered token paths and the community-pool balance

## External governance and transfers

- Proposal and voting workflows, if used, are implemented by an external governance process.
- An approved external execution may call `TransferToken`, but the package itself performs no proposal validation or automatic execution.
- Successful transfers emit a `TransferToken` event.

## Key Functions

### `TransferToken`

Directly transfers a registered token to a specified address. The caller must
be admin or governance, withdrawals must not be halted, and the normal token
transfer validation applies.

## Usage

```go
// Direct transfer by an admin or governance execution
TransferToken(
    cross(cur),
    "gno.land/r/demo/usdc",
    recipientAddr,
    1000000,
)
```

## Security

- Admin-or-governance authorization is required for transfers
- Withdrawal halt blocks transfers
- Registered-token and balance validation is enforced by the transfer helper
- Proposal/voting state is not implemented in this package
- Event emission provides transfer traceability
- Multi-token support
