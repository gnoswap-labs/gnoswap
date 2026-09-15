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

## Component Upgrades

Versioned component implementations are selected by the version manager behind
each stable component proxy. RBAC role addresses identify authorization and
distribution targets (including stable proxies); changing a role with
`UpdateRoleAddress` only changes the role mapping and does not select
implementation code.

### Upgrade Process

1. **Register the implementation**: Each version package calls the component
   proxy's `RegisterInitializer` during package initialization.
2. **Initial activation**: When no implementation is active, the first
   registered initializer is activated. Later registrations are retained but
   remain inactive.
3. **Activate a registered version**: An authorized admin or governance caller
   invokes the component's `UpgradeImpl` with the fully qualified package path
   of a previously registered version, for example
   `pool.UpgradeImpl(cross(cur), "gno.land/r/gnoswap/pool/v2")`.
4. **Preserve proxy state and identities**: Calls continue through the stable
   proxy and shared domain storage; RBAC role identities are unchanged. The
   selected implementation's initializer is responsible for compatible state
   setup.

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

## Distribution Target Changes

The `community_pool` role is a distribution and treasury destination, not a
versioned component. Updating that role redirects distributions to the selected
address.

### Example: GNS Distribution Target Change

```go
func changeDistributionTarget(cur realm) {
    // Update distribution and authorization targets through RBAC.
    // This does not select an implementation version.
    rbac.UpdateRoleAddress(cross(cur), "staker", newStakerAddr)
    rbac.UpdateRoleAddress(cross(cur), "gov_staker", newGovStakerAddr)
    rbac.UpdateRoleAddress(cross(cur), "devops", newDevOpsAddr)
    // community_pool is a distribution target, not a versioned implementation.
    rbac.UpdateRoleAddress(cross(cur), "community_pool", newCommunityPoolAddr)
}
```

### Test Example

The distribution-target scenario is demonstrated in the
[role-address update scenario test](../../../scenario/upgrade/change_gns_distribution_target_filetest.gno).
It initializes distribution targets, updates role addresses, and verifies that
subsequent GNS distributions use the new addresses.

```go
// The scenario changes distribution targets, not implementation versions.
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
