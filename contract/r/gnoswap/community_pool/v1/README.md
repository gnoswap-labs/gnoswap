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

### Emergency admin policy

Governance is the recommended normal route for treasury transfers. While
governance is not yet mature, admin authorization is retained for emergency-only
use.

This restriction is an operational policy, not an on-chain emergency check.
The admin can call `TransferToken` directly without an approved governance
proposal. The contract does not verify an emergency or automatically remove
admin access when governance matures. Withdrawal-halt and token-transfer
checks still apply; emergency admin access does not bypass them.

## Key Functions

### `TransferToken`

Directly transfers a registered token to a specified address. The caller must
be admin or governance, withdrawals must not be halted, and the normal token
transfer validation applies.

## Gnoweb

`Render("")` shows the admin and governance role addresses and the withdrawal halt
checked by `TransferToken`. It does not enumerate token balances or claim a total
treasury value. Query a specific registered token with `GetBalanceOf(tokenPath)`.
Unsupported paths return `404`.

## Usage

```go
// Governance execution, or emergency admin action under the operational policy
TransferToken(
    cross(cur),
    "gno.land/r/gnoswap/gns.GNS",
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
