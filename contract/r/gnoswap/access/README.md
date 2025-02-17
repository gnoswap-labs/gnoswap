# Access Control

The `access` package provides a configuration-based wrapper around the `p/rbac` package, offering simplified role management and access control for Gno smart contracts.

## Key Features

- **Configuration-based Setup**: Initialize access control with a simple configuration containing role-to-address mappings
- **Predefined Roles**: Built-in roles for common access patterns (admin, governance, router, pool, etc.)
- **Dynamic Role Management**: Support for creating new roles and updating role addresses at runtime
- **Simple Permission Checks**: Utility functions for checking role-based permissions

## Predefined Roles

| Role Name | Value | Description |
|-----------|-------|-------------|
| `ROLE_ADMIN` | `admin` | Admin role |
| `ROLE_GOVERNANCE` | `governance` | Governance role |
| `ROLE_GOV_STAKER` | `gov_staker` | Governance staker role |
| `ROLE_ROUTER` | `router` | Router role |
| `ROLE_POOL` | `pool` | Pool role |
| `ROLE_POSITION` | `position` | Position role |
| `ROLE_STAKER` | `staker` | Staker role |
| `ROLE_LAUNCHPAD` | `launchpad` | Launchpad role |
| `ROLE_EMISSION` | `emission` | Emission role |
| `ROLE_USER` | `user` | User role |

## API Overview

### Configuration

```go
type Config struct {
    Roles map[string]std.Address
}

// Create default configuration
func DefaultConfig() *Config
```

### Core Functions

```go
// Initialize access control with configuration
func Initialize(cfg *Config) error

// Update address for a specific role
func UpdateRoleAddress(roleName string, newAddress std.Address) error

// Create a new role with associated address
func CreateRole(roleName string, address std.Address) error

// Check if a role exists
func RoleExists(roleName string) bool

// Get all registered roles
func GetRoles() []string
```

### Permission Checks

```go
// Role-specific permission checks
func AdminOnly(caller std.Address) error
func GovernanceOnly(caller std.Address) error
func RouterOnly(caller std.Address) error
// ... and more
```

## Implementation Details

1. **Configuration**: The package maintains a global configuration storing role-to-address mappings.

2. **Permission Checking**: Each role is associated with an address checker that validates if a caller matches the configured address.

3. **Role Management**:
   - Roles can be pre-configured during initialization
   - New roles can be created at runtime
   - Role addresses can be updated dynamically

The sequence diagram above illustrates the flow of initialization and role management operations in the Access Control system.

## Limitations

- Only supports single-address to role mapping
- All roles use the same permission type ("access")
- Configuration must be initialized before using any functionality
- Global configuration state may need careful management in complex applications