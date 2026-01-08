# Access

Centralized role-based access control system for GnoSwap protocol contracts.

## Overview

The Access package provides a unified permission management system for all GnoSwap protocol contracts. It manages role-to-address mappings and provides convenient assertion functions for authorization checks throughout the protocol.

This package acts as a centralized registry where each protocol component (pool, router, staker, etc.) registers its address under a specific role. Other contracts can then query this registry to verify permissions before executing privileged operations.
Admin role ownership is managed by the RBAC realm and is updated on ownership transfer; this package only stores the latest role address.

## Architecture

The access control system consists of:

1. **Role Registry**: Maps role names (strings) to contract addresses
2. **Role Management**: Functions to set/remove roles (RBAC-only)
3. **Authorization Checks**: Functions to verify if an address has a specific role
4. **Assert Helpers**: Convenience functions that panic on authorization failure

## System Roles

The following roles are used across the GnoSwap protocol:

- **admin**: Protocol administrator with elevated privileges
- **devops**: DevOps operations for system maintenance
- **governance**: Governance contract for protocol decisions
- **router**: Swap router for token exchanges
- **pool**: Pool management contract
- **position**: Position NFT management
- **staker**: Liquidity staking contract
- **emission**: GNS token emission controller
- **protocol_fee**: Protocol fee collection and distribution
- **launchpad**: Token launchpad for new projects
- **gov_staker**: Governance staking contract
- **xgns**: xGNS token contract for governance

## Key Functions

### Role Management (RBAC Only)

#### `SetRoleAddress`

Sets or updates a role's address. Creates new role if it doesn't exist.
The `admin` role is updated by RBAC ownership transfers and should not be managed directly by other contracts.

```go
// Only callable by RBAC contract
access.SetRoleAddress(cur, "router", routerAddress)
```

#### `RemoveRole`

Removes a role from the system.

```go
// Only callable by RBAC contract
access.RemoveRole(cur, "old_role")
```

### Role Query Functions

#### `GetAddress`

Returns the address for a role and whether it exists.

```go
addr, exists := access.GetAddress("router")
if !exists {
    // Handle missing role
}
```

#### `MustGetAddress`

Returns the address for a role or panics if it doesn't exist.

```go
// Panics if role doesn't exist
routerAddr := access.MustGetAddress("router")
```

#### `GetRoleAddresses`

Returns a copy of all role-to-address mappings.

```go
allRoles := access.GetRoleAddresses()
for roleName, addr := range allRoles {
    println(roleName, "->", addr)
}
```

### Authorization Functions

#### `IsAuthorized`

Checks if an address has a specific role (non-panicking).

```go
if access.IsAuthorized("admin", caller) {
    // Caller is admin
}
```

### Assert Functions (Panic on Failure)

These functions panic with a descriptive error if authorization fails:

#### `AssertIsAdmin`

Requires admin role.

```go
access.AssertIsAdmin(caller)
```

#### `AssertIsGovernance`

Requires governance role.

```go
access.AssertIsGovernance(caller)
```

#### `AssertIsAdminOrGovernance`

Requires either admin or governance role.

```go
access.AssertIsAdminOrGovernance(caller)
```

#### Role-Specific Assertions

```go
access.AssertIsRouter(caller)
access.AssertIsPool(caller)
access.AssertIsPosition(caller)
access.AssertIsStaker(caller)
access.AssertIsEmission(caller)
access.AssertIsProtocolFee(caller)
access.AssertIsLaunchpad(caller)
access.AssertIsGovStaker(caller)
access.AssertIsGovXGNS(caller)
```

#### `AssertIsAuthorized`

Generic authorization check for any role.

```go
access.AssertIsAuthorized("custom_role", caller)
```

#### `AssertHasAnyRole`

Requires the caller to have at least one of the specified roles.

```go
access.AssertHasAnyRole(caller, "admin", "governance", "devops")
```

### Validation Functions

#### `AssertIsValidAddress`

Panics if the address is invalid.

```go
access.AssertIsValidAddress(addr)
```

#### `AssertIsUser`

Panics if the caller is not a user realm (i.e., a contract is calling).

```go
access.AssertIsUser(r)
```

## Usage Examples

### Example 1: Protecting Admin Functions

```go
package pool

import "gno.land/r/gnoswap/access"

func SetPoolFeeRate(rate uint64) {
    caller := std.PrevRealm().Addr()
    access.AssertIsAdminOrGovernance(caller)

    // Admin/governance authorized, proceed
    setFeeRate(rate)
}
```

### Example 2: Role-Based Function Access

```go
package staker

import "gno.land/r/gnoswap/access"

func DistributeRewards(amount uint64) {
    caller := std.PrevRealm().Addr()
    access.AssertIsEmission(caller)

    // Only emission contract can distribute
    distributeToStakers(amount)
}
```

### Example 3: Multi-Role Authorization

```go
package common

import "gno.land/r/gnoswap/access"

func EmergencyPause() {
    caller := std.PrevRealm().Addr()
    access.AssertHasAnyRole(caller, "admin", "devops", "governance")

    // Any of the authorized roles can pause
    pauseProtocol()
}
```

### Example 4: Non-Panicking Authorization Check

```go
package router

import "gno.land/r/gnoswap/access"

func GetSwapFee(caller address) uint64 {
    // Lower fee for admin
    if access.IsAuthorized("admin", caller) {
        return 0 // Admin gets free swaps
    }

    return standardFee
}
```

## Security Model

### Centralized Management

- All role assignments are managed through this single contract
- Provides a unified view of permissions across the entire protocol
- Prevents inconsistencies in authorization logic

### RBAC-Only Updates

- Only the RBAC contract can modify role assignments
- Uses package address verification to enforce this restriction
- Prevents unauthorized role manipulation

### Explicit Authorization

- All authorization checks are explicit and auditable
- Panic-based assertions make authorization failures obvious
- No implicit or default permissions

## Integration with RBAC

The Access contract works in conjunction with the RBAC (Role-Based Access Control) package:

1. **RBAC**: Manages role definitions and ownership transfer
2. **Access**: Provides centralized role-to-address registry and authorization checks

Role updates flow: `RBAC.UpdateRoleAddress()` → `Access.SetRoleAddress()`

## Best Practices

1. **Use Assertions for Critical Functions**: Always use assert functions for operations that should only proceed with proper authorization
2. **Check Existence Before Use**: Use `GetAddress` when you need to handle missing roles gracefully
3. **Document Role Requirements**: Clearly document which roles are required for each function
4. **Avoid Hardcoding Addresses**: Always use role-based checks instead of hardcoding addresses
5. **Test Authorization**: Thoroughly test all authorization paths in your contracts

## Error Handling

Authorization failures result in panics with descriptive error messages:

- `"unauthorized: caller X is not Y"` - Caller doesn't have required role
- `"role X does not exist"` - Role hasn't been registered
- `"invalid address: X"` - Address validation failed
- `"caller is not user"` - Contract called user-only function

## Limitations

- Role names are case-sensitive strings
- Each role can only map to one address at a time
- Role changes take effect immediately (no timelock)
