# RBAC

Role-Based Access Control package for Gno smart contracts.

## Overview

Flexible RBAC system enabling dynamic role and permission management without contract redeployment.

## Features

- Dynamic role registration
- Multiple permissions per role
- Declarative role definition
- Custom permission logic
- Runtime updates

## Core API

```go
// Create RBAC manager
func New() *RBAC

// Role management
func (rb *RBAC) RegisterRole(roleName string) error
func (rb *RBAC) DeclareRole(roleName string, opts ...RoleOption) error

// Permission management
func (rb *RBAC) RegisterPermission(roleName, permissionName string, checker PermissionChecker) error
func (rb *RBAC) UpdatePermission(roleName, permissionName string, newChecker PermissionChecker) error
func (rb *RBAC) RemovePermission(roleName, permissionName string) error

// Access control
func (rb *RBAC) CheckPermission(roleName, permissionName string, caller Address) error

// Permission checker type
type PermissionChecker func(caller std.Address) error
```

## Usage

```go
// Create manager
manager := rbac.New()

// Register role
manager.RegisterRole("admin")

// Add permission
adminChecker := func(caller std.Address) error {
    if caller != adminAddr {
        return errors.New("not admin")
    }
    return nil
}
manager.RegisterPermission("admin", "access", adminChecker)

// Declarative role setup
manager.DeclareRole("editor", 
    rbac.WithPermission("edit", editorChecker))

// Check access
err := manager.CheckPermission("admin", "access", caller)
```

## Architecture

```
Client → RBAC → Role → PermissionChecker
         ↓       ↓            ↓
      Manager  Storage    Validation
```

## Security

- No direct address-to-role mapping
- Custom validation logic per permission
- Runtime permission updates
- Isolated permission checks