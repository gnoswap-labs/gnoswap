# RBAC

Role-based access control management realm.

## Overview

RBAC realm manages role addresses and permissions for the GnoSwap protocol, integrating with the access package.

## Configuration

- **Admin Control**: Full role management
- **Dynamic Roles**: Add/remove at runtime
- **Access Integration**: Syncs with access package

## Key Functions

### `RegisterRole`
Registers new role in system.

### `RemoveRole`
Removes existing role.

### `UpdateRoleAddress`
Updates address for role.

### `GetRoleAddress`
Returns address for role.

### `TransferOwnership`
Transfers admin role to new address.

## Usage

```go
// Register new role
RegisterRole("new_role")

// Update role address
UpdateRoleAddress("staker", newAddress)

// Get role address
addr, err := GetRoleAddress("router")

// Transfer admin ownership
TransferOwnership(newAdmin)
```

## Security

- Admin-only role management
- Synchronized with access package
- Ownership transfer capability
- Role validation before updates