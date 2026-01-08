// Package rbac provides a simple address-based Role-Based Access Control (RBAC)
// system for Gno smart contracts. It enables dynamic registration, update, and removal
// of roles with assigned addresses.
//
// ## Overview
//
// The RBAC package provides a manager that maintains an internal registry of roles.
// Each role is identified by a unique name and is associated with a single address.
// Authorization is performed by checking if a given address matches the role's assigned address.
//
// Key components of this package include:
//
//  1. **Role**: Represents a role with a name and an assigned address.
//  2. **RBAC Manager**: The core type (RBAC) that manages role registration, address
//     assignment, authorization verification, and role removal.
//  3. **Ownable2Step**: Provides two-step ownership transfer functionality integrated
//     into the RBAC manager.
//
// ## Key Features
//
//   - **Dynamic Role Management**: Roles can be registered, updated, and removed at runtime
//     without requiring contract redeployment.
//   - **Address-Based Authorization**: Each role is associated with a single address,
//     and authorization is verified by address matching.
//   - **System Roles**: Predefined system roles (admin, devops, pool, etc.) that cannot
//     be removed to ensure system integrity.
//   - **Two-Step Ownership Transfer**: Built-in secure ownership transfer mechanism
//     requiring explicit acceptance by the new owner.
//   - **Encapsulation**: Internal state (roles registry) is encapsulated within the RBAC
//     manager, preventing unintended external modifications.
//
// ## Workflow
//
// Typical usage of the RBAC package includes the following steps:
//
//  1. **Initialization**: Create a new RBAC manager using `New()` or `NewRBACWithAddress(addr)`.
//  2. **Role Registration**: Register roles using `RegisterRole(roleName, address)`.
//  3. **Authorization Check**: Verify if an address is authorized for a role using
//     `IsAuthorized(roleName, address)`.
//  4. **Role Management**: Update role addresses with `UpdateRoleAddress` or remove
//     non-system roles with `RemoveRole`.
//
// ## Example Usage
//
// The following example demonstrates how to use the RBAC package:
//
// ```gno
// package main
//
// import (
//	"gno.land/p/gnoswap/rbac"
//
// )
//
//	func main() {
//	    // Create a new RBAC manager (origin caller becomes owner)
//	    manager := rbac.New()
//
//	    // Define example addresses
//	    adminAddr := address("g1...")
//	    userAddr  := address("g1...")
//
//	    // Register an "admin" role with adminAddr
//	    if err := manager.RegisterRole("admin", adminAddr); err != nil {
//	        panic(err)
//	    }
//
//	    // Register a custom "editor" role with userAddr
//	    if err := manager.RegisterRole("editor", userAddr); err != nil {
//	        panic(err)
//	    }
//
//	    // Check if adminAddr is authorized for the "admin" role
//	    if manager.IsAuthorized("admin", adminAddr) {
//	        println("Admin access granted")
//	    }
//
//	    // Check if userAddr is authorized for the "admin" role
//	    if !manager.IsAuthorized("admin", userAddr) {
//	        println("User does not have admin access")
//	    }
//
//	    // Update the editor role to a different address
//	    newEditorAddr := address("g1...")
//	    if err := manager.UpdateRoleAddress("editor", newEditorAddr); err != nil {
//	        panic(err)
//	    }
//
//	    // Get all role addresses
//	    allRoles := manager.GetAllRoleAddresses()
//	    for roleName, addr := range allRoles {
//	        println(roleName, "->", addr.String())
//	    }
//	}
//
// ```
//
// ## System Roles
//
// The package defines several system roles that cannot be removed:
//
//   - admin: System administrator role
//   - devops: DevOps operations role
//   - community_pool: Community pool management role
//   - governance: Governance system role
//   - gov_staker: Governance staker role
//   - xgns: xGNS token role
//   - pool: Pool management role
//   - position: Position management role
//   - router: Router role
//   - staker: Staker role
//   - emission: Emission management role
//   - launchpad: Launchpad role
//   - protocol_fee: Protocol fee management role
//
// ## Error Handling
//
// The package defines several error types:
//
// - ErrRoleAlreadyExists: Attempting to register a role that already exists.
// - ErrRoleDoesNotExist: Attempting to access or modify a non-existent role.
// - ErrCannotRemoveSystemRole: Attempting to remove a system role.
// - ErrInvalidAddress: Providing an invalid or empty address.
// - ErrUnauthorized: Caller is not the owner when owner permission is required.
// - ErrNoPendingOwner: Attempting to accept ownership when no transfer is pending.
// - ErrPendingUnauthorized: Caller is not the pending owner when accepting ownership.
//
// ## Ownership Management
//
// The RBAC manager includes built-in two-step ownership transfer functionality:
//
//  1. Current owner calls TransferOwnershipBy to initiate transfer.
//  2. New owner calls AcceptOwnershipBy to complete the transfer.
//  3. Owner can drop ownership entirely using DropOwnershipBy.
//
// ## Limitations and Considerations
//
//   - Each role can only have one assigned address. For multi-address authorization,
//     consider creating multiple roles or implementing a wrapper.
//   - System roles are protected and cannot be removed to ensure system stability.
//   - Address validation checks for empty strings and calls IsValid() method.
//
// Package rbac is intended for use in Gno smart contracts requiring simple,
// address-based access control with role management capabilities.
package rbac
