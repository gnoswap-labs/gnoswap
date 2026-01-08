# RBAC

Role-based access control management realm.

## Overview

RBAC realm manages role addresses and permissions for the GnoSwap protocol, integrating with the access package.

## Configuration

- **Admin/Governance Control**: Role management by admin or governance
- **Dynamic Roles**: Add/remove at runtime
- **Access Integration**: Syncs with access package
- **Owner-Managed Admin Role**: `admin` role is bound to RBAC owner and cannot be updated via `UpdateRoleAddress`

## Key Functions

### `RegisterRole(cur realm, roleName string, roleAddress address)`

Registers new role in system. Only callable by admin or governance.

### `RemoveRole(cur realm, roleName string)`

Removes existing role. Only callable by admin or governance. System roles cannot be removed.

### `UpdateRoleAddress(cur realm, roleName string, addr address)`

Updates address for role. Only callable by admin or governance.
The `admin` role is not updatable via this function and is managed through ownership transfer.

### `GetRoleAddress(roleName string) (address, error)`

Returns address for role.

### `IsOwner(addr address) bool`

Returns true if addr is the current owner.

### `IsPendingOwner(addr address) bool`

Returns true if addr is the pending owner.

### `GetOwner() address`

Returns the current owner address.

### `GetPendingOwner() address`

Returns the pending owner address.

### `TransferOwnership(cur realm, newOwner address)`

Initiates two-step ownership transfer. Only callable by current owner.

### `AcceptOwnership(cur realm)`

Accepts pending ownership transfer. Only callable by pending owner.
Also updates the `admin` role address and syncs it to the access package.

## Usage

```go
// Register new role (requires admin or governance)
RegisterRole(cross, "new_role", roleAddress)

// Update role address
UpdateRoleAddress(cross, "staker", newAddress)

// Admin role is updated via ownership transfer
TransferOwnership(cross, newAdmin)
AcceptOwnership(cross)

// Get role address
addr, err := GetRoleAddress("router")

// Transfer ownership (two-step)
TransferOwnership(cross, newAdmin)  // Step 1: Initiate
AcceptOwnership(cross)               // Step 2: Accept (by newAdmin)
```

## Contract Upgrade

RBAC enables seamless contract upgrades through role address updates. Versioned contracts (with paths like `v1`) can be upgraded by deploying new versions and updating role addresses.

### Upgrade Process

1. **Deploy new contract version** (e.g., `v2` contracts)
2. **Update role addresses** to point to new contracts
3. **Verify distribution** flows to new contract addresses

### Upgradeable Components

All versioned contracts under `gno.land/r/gnoswap/{version}/` are upgradeable:

- `pool` - Liquidity pool management
- `position` - Position management
- `router` - Swap routing engine
- `staker` - Staking and rewards
- `governance` - Governance system (governance, staker, xgns)
- `launchpad` - Token launch platform
- `protocol_fee` - Fee collection
- `community_pool` - Community treasury

### Example: GNS Distribution Upgrade

```go
// Before upgrade - GNS distributed to v1 contracts
mintAndDistribute() // → v1 staker, devops, community_pool

// Upgrade process - update role addresses
rbac.UpdateRoleAddress("staker", newV2StakerAddr)
rbac.UpdateRoleAddress("devops", newV2DevOpsAddr)
rbac.UpdateRoleAddress("community_pool", newV2CommunityPoolAddr)

// After upgrade - GNS distributed to v2 contracts
mintAndDistribute() // → v2 staker, devops, community_pool
```

This approach ensures zero-downtime upgrades with atomic role address switches, maintaining protocol continuity while enabling feature updates and bug fixes.

### Test Example

The upgrade mechanism is demonstrated in the test file:
[upgrade scenario test](./../../../../tests/scenario/upgrade/change_gns_distribution_target_filetest.gno)

```go
// Test scenario steps:
// 1. Initialize emission and mint GNS to v1 contracts
// 2. Update role addresses to point to v2 contracts
// 3. Verify GNS now flows to v2 contracts

func changeDistributionTarget() {
    // Update all role addresses atomically
    rbac.UpdateRoleAddress("staker", newStakerAddr)
    rbac.UpdateRoleAddress("gov_staker", newGovStakerAddr)
    rbac.UpdateRoleAddress("devops", newDevOpsAddr)
    rbac.UpdateRoleAddress("community_pool", newCommunityPoolAddr)
}
```

The test validates that after role updates, GNS distribution switches from v1 to v2 contracts without any protocol downtime or loss of funds.

## Security

- Admin-only role management
- Synchronized with access package
- Ownership transfer capability
- Role validation before updates
