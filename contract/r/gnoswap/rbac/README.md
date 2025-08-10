# RBAC

Role-based access control management.

## Features

- Dynamic role management
- Address assignment per role
- Ownership transfer support
- Integration with access package

## Functions

- `RegisterRole` - Register new role
- `RemoveRole` - Remove existing role
- `UpdateRoleAddress` - Update role address
- `GetRoleAddress` - Get address for role
- `TransferOwnership` - Transfer admin role

## Usage

```go
// Register new role
RegisterRole("new_role")

// Update role address
UpdateRoleAddress("staker", newAddress)

// Get role address
addr, err := GetRoleAddress("router")
```

## Notes

- Uses p/rbac for role definitions
- Synchronized with access package
- Admin role has full control

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Role Addresses**: Address assignments for each role
- **Role Registry**: Add/remove roles dynamically
- **Admin Transfer**: Transfer ownership to new admin