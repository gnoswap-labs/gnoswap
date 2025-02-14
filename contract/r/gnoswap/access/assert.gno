package access

import (
	"std"

	"gno.land/r/gnoswap/v1/rbac"
)

// AdminOnly checks if the caller has admin role permission
func AdminOnly(caller std.Address) error {
	return rbac.CheckPermission(ROLE_ADMIN, PERM_ACCESS, caller)
}

// GovernanceOnly checks if the caller has governance role permission
func GovernanceOnly(caller std.Address) error {
	return rbac.CheckPermission(ROLE_GOVERNANCE, PERM_ACCESS, caller)
}

// GovStakerOnly checks if the caller has gov staker role permission
func GovStakerOnly(caller std.Address) error {
	return rbac.CheckPermission(ROLE_GOV_STAKER, PERM_ACCESS, caller)
}

// RouterOnly checks if the caller has router role permission
func RouterOnly(caller std.Address) error {
	return rbac.CheckPermission(ROLE_ROUTER, PERM_ACCESS, caller)
}

// PoolOnly checks if the caller has pool role permission
func PoolOnly(caller std.Address) error {
	return rbac.CheckPermission(ROLE_POOL, PERM_ACCESS, caller)
}

// PositionOnly checks if the caller has position role permission
func PositionOnly(caller std.Address) error {
	return rbac.CheckPermission(ROLE_POSITION, PERM_ACCESS, caller)
}

// StakerOnly checks if the caller has staker role permission
func StakerOnly(caller std.Address) error {
	return rbac.CheckPermission(ROLE_STAKER, PERM_ACCESS, caller)
}

// LaunchpadOnly checks if the caller has launchpad role permission
func LaunchpadOnly(caller std.Address) error {
	return rbac.CheckPermission(ROLE_LAUNCHPAD, PERM_ACCESS, caller)
}

// EmissionOnly checks if the caller has emission role permission
func EmissionOnly(caller std.Address) error {
	return rbac.CheckPermission(ROLE_EMISSION, PERM_ACCESS, caller)
}
