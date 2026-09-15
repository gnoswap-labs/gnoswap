# RBAC

Role-Based Access Control package for Gno smart contracts.

## Overview

RBAC system enabling dynamic role management with address-based authorization and two-step ownership transfer.

## Features

- Dynamic role registration with address assignment
- Address-based authorization checks
- Two-step ownership transfer (Ownable2Step pattern)
- System role protection (cannot be removed)
- Runtime role address updates

## Core API

```go
// Create RBAC manager with an explicit owner address.
func NewRBACWithAddress(addr address) *RBAC

// Role management
func (rb *RBAC) RegisterRole(roleName string, addr address) error
func (rb *RBAC) UpdateRoleAddress(roleName string, addr address) error
func (rb *RBAC) RemoveRole(roleName string) error

// Authorization
func (rb *RBAC) IsAuthorized(roleName string, addr address) bool

// Role queries
func (rb *RBAC) GetRoleAddress(roleName string) (address, error)
func (rb *RBAC) GetAllRoleAddresses() map[string]address

// Ownership management
func (rb *RBAC) Owner() address
func (rb *RBAC) PendingOwner() address
func (rb *RBAC) TransferOwnershipBy(newOwner, caller address) error
func (rb *RBAC) AcceptOwnershipBy(addr address) error
func (rb *RBAC) DropOwnershipBy(addr address) error
```

## Usage

```go
// Create manager with owner
manager := rbac.NewRBACWithAddress(adminAddr)

// Register role with address
err := manager.RegisterRole("editor", editorAddr)
if err != nil {
    // handle error
}

// Check authorization
if manager.IsAuthorized("editor", callerAddr) {
    // caller is authorized as editor
}

// Update role address
err = manager.UpdateRoleAddress("editor", newEditorAddr)

// Get role address
addr, err := manager.GetRoleAddress("editor")
```

## System Roles

Reserved system-role names cannot be removed after they are registered. A new
RBAC manager starts with no role entries; register each system role explicitly
with its address.

- `admin`, `governance`, `devops`
- `pool`, `position`, `router`, `staker`
- `emission`, `launchpad`, `protocol_fee`
- `gov_staker`, `xgns`, `community_pool`

## Errors

| Error | Description |
|-------|-------------|
| `ErrInvalidRoleName` | Role name is empty or whitespace-only |
| `ErrRoleAlreadyExists` | Role already registered |
| `ErrRoleDoesNotExist` | Role not found |
| `ErrCannotRemoveSystemRole` | Cannot remove a registered system role |
| `ErrInvalidAddress` | Invalid address for `UpdateRoleAddress` or ownership transfer; `RegisterRole` stores its supplied address without validation |
| `ErrUnauthorized` | Caller is not owner |
| `ErrNoPendingOwner` | No pending owner |
| `ErrPendingUnauthorized` | Caller is not pending owner |

## Security

- Address-based role authorization
- Two-step ownership transfer prevents accidental transfers
- System roles protected from removal
- Role name validation (no empty/whitespace names)