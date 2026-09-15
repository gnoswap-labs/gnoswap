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

## Gnoweb

`Render("")` shows the owner, pending owner (`None` when absent), and the fixed
system-role assignments. Unassigned roles are explicit; custom roles are not
enumerated. Unsupported paths return `404`.

## Usage

```go
// Register new role (requires admin or governance)
RegisterRole(cross(cur), "new_role", roleAddress)

// Update role address
UpdateRoleAddress(cross(cur), "staker", newAddress)

// Admin role is updated via ownership transfer
TransferOwnership(cross(cur), newAdmin)
AcceptOwnership(cross(cur))

// Get role address
addr, err := GetRoleAddress("router")

// Transfer ownership (two-step)
TransferOwnership(cross(cur), newAdmin) // Step 1: Initiate
AcceptOwnership(cross(cur))             // Step 2: Accept (by newAdmin)
```

## Contract Upgrade

RBAC supports contract upgrades by changing role addresses. Versioned implementations live under component-specific realm paths (for example, `gno.land/r/gnoswap/pool/v1`), while the stable realm resolves calls through the current role address.

### Upgrade Process

1. **Deploy a new component version** under its versioned realm path.
2. **Update the relevant role address** to point to the new implementation.
3. **Verify distribution and call flows** use the new role address.

### Versioned Components

This checkout contains versioned implementations for:

- `pool`
- `position`
- `router`
- `staker`
- `gov/governance`
- `gov/staker`
- `launchpad`
- `protocol_fee`

The `community_pool` role is a distribution and treasury destination, not a versioned component. Updating that role redirects distributions to the selected address.

### Example: GNS Distribution Upgrade

```go
func changeDistributionTarget(cur realm) {
    // Update role addresses through the RBAC realm.
    rbac.UpdateRoleAddress(cross(cur), "staker", newStakerAddr)
    rbac.UpdateRoleAddress(cross(cur), "gov_staker", newGovStakerAddr)
    rbac.UpdateRoleAddress(cross(cur), "devops", newDevOpsAddr)
    // community_pool is a distribution target, not a versioned implementation.
    rbac.UpdateRoleAddress(cross(cur), "community_pool", newCommunityPoolAddr)
}
```

### Test Example

The upgrade mechanism is demonstrated in the [upgrade scenario test](../../../scenario/upgrade/change_gns_distribution_target_filetest.gno).

```go
// The scenario initializes distribution targets, updates role addresses,
// and verifies that subsequent GNS distributions use the new addresses.
func changeDistributionTarget(cur realm) {
    rbac.UpdateRoleAddress(cross(cur), "staker", newStakerAddr)
    rbac.UpdateRoleAddress(cross(cur), "gov_staker", newGovStakerAddr)
    rbac.UpdateRoleAddress(cross(cur), "devops", newDevOpsAddr)
    rbac.UpdateRoleAddress(cross(cur), "community_pool", newCommunityPoolAddr)
}
```

## Security

- Admin or governance authorization is required for role management
- Ownership transfer is restricted to the current owner and pending owner
- Role updates are synchronized with the access package
- Role validation is performed before updates
