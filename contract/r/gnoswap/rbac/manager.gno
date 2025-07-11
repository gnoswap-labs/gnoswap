package rbac

import (
	"std"

	prbac "gno.land/p/gnoswap/rbac"
)

// globalManager is the single RBAC manager instance created internally in the package.
// This instance is used to manage global role and permission information.
var globalManager = prbac.New()

// RegisterRole globally registers a role with the given name.
// Returns an error if the role already exists.
// XXX seems not needed
func RegisterRole(cur realm, roleName string) error {
	if !callerIsOwner() {
		return prbac.ErrUnauthorized
	}
	return globalManager.RegisterRole(roleName)
}

// RegisterPermission globally registers a permission on a role.
// If the role does not exist, an error is returned.
// XXX seems not needed
func RegisterPermission(cur realm, roleName, permissionName string, checker prbac.PermissionChecker) error {
	if !callerIsOwner() {
		return prbac.ErrUnauthorized
	}
	return globalManager.RegisterPermission(roleName, permissionName, checker)
}

// CheckPermission globally checks if the provided caller has the specified
// permission under the given role. If the role or permission is not found, or
// the check fails, an error is returned.
func CheckPermission(roleName, permissionName string, caller std.Address) error {
	return globalManager.CheckPermission(roleName, permissionName, caller)
}

// UpdatePermission globally updates the permission checker for a role's permission.
// An error is returned if the role or permission does not exist.
func UpdatePermission(cur realm, roleName, permissionName string, newChecker prbac.PermissionChecker) error {
	return globalManager.UpdatePermission(roleName, permissionName, newChecker)
}

// RemovePermission globally removes a permission from a role.
// An error is returned if the role or permission does not exist.
func RemovePermission(cur realm, roleName, permissionName string) error {
	if !callerIsOwner() {
		return prbac.ErrUnauthorized
	}
	return globalManager.RemovePermission(roleName, permissionName)
}

// RemoveRole globally removes a role.
// An error is returned if the role does not exist.
func RemoveRole(cur realm, roleName string) error {
	return globalManager.RemoveRole(roleName)
}

// DeclareRole globally declares a role using the Functional Option pattern.
// This allows declarative registration of roles along with their permissions.
// Returns an error if the role already exists.
func DeclareRole(cur realm, roleName string, opts ...prbac.RoleOption) error {
	return globalManager.DeclareRole(roleName, opts...)
}

// GlobalManager returns the underlying global RBAC manager instance.
// This can be used if direct access to the RBAC manager is needed.
func GlobalManager() *prbac.RBAC {
	return globalManager
}

func callerIsOwner() bool {
	return globalManager.Ownable().OwnedByPrevious()
}
