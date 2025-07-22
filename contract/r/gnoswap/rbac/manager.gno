package rbac

import (
	prbac "gno.land/p/gnoswap/rbac"
)

// globalManager is the single RBAC manager instance created internally in the package.
// This instance is used to manage global role and permission information.
var globalManager = prbac.New()

// RegisterRole globally registers a role with the given name.
// Returns an error if the role already exists.
func RegisterRole(cur realm, roleName string) error {
	if !callerIsOwner() {
		return prbac.ErrUnauthorized
	}
	return globalManager.RegisterRole(roleName)
}

// RemoveRole globally removes a role.
// An error is returned if the role does not exist.
func RemoveRole(cur realm, roleName string) error {
	if !callerIsOwner() {
		return prbac.ErrUnauthorized
	}
	return globalManager.RemoveRole(roleName)
}

// DeclareRole globally declares a role using the Functional Option pattern.
// This allows declarative registration of roles along with their permissions.
// Returns an error if the role already exists.
func DeclareRole(cur realm, roleName string, opts ...prbac.RoleOption) error {
	if !callerIsOwner() {
		return prbac.ErrUnauthorized
	}
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
