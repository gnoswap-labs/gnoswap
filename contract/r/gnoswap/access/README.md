# Access

Role-based access control for GnoSwap contracts.

## Overview

Access control system manages permissions across all protocol contracts using role-based authorization.

## Roles

- **admin**: Protocol administrator
- **governance**: Governance contract
- **router**: Swap router
- **pool**: Pool management
- **position**: Position NFT
- **staker**: Liquidity staking
- **emission**: GNS emission
- **protocol_fee**: Fee collector
- **launchpad**: Token launchpad
- **gov_staker**: Governance staking
- **gov_xgns**: xGNS token

## Key Functions

### `GetAddress`
Returns address for a role.

### `SetRoleAddresses`
Updates all role addresses (RBAC only).

### `IsAuthorized`
Checks if address has role.

### Assert Functions
- `AssertIsAdmin` - Require admin role
- `AssertIsGovernance` - Require governance
- `AssertIsAdminOrGovernance` - Admin or governance
- `AssertIsRouter`, `AssertIsPool`, etc.

### Swap Whitelist
- `UpdateSwapWhiteList` - Add to whitelist
- `RemoveFromSwapWhiteList` - Remove from whitelist
- `IsSwapWhitelisted` - Check whitelist status

## Usage

```go
// Check permission
if !access.IsAuthorized("admin", caller) {
    panic("unauthorized")
}

// Assert permission (panics if unauthorized)
access.AssertIsAdminOrGovernance(caller)

// Get role address
addr, exists := access.GetAddress("router")

// Manage whitelist
access.UpdateSwapWhiteList(routerAddr)
```

## Security

- Centralized permission management
- Role-based authorization
- Swap whitelist for approved routers
- RBAC-only role updates