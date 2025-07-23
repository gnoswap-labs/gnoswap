package common

import (
	"std"

	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/access"
)

const (
	ErrNoPermission = "caller(%s) has no permission"
)

// AssertCaller checks if the caller is the given address.
func AssertCaller(caller, addr std.Address) error {
	if caller != addr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

func SatisfyCond(cond bool) error {
	if !cond {
		return ufmt.Errorf("given condition is not satisfied the permission check")
	}
	return nil
}

// UserOnly checks if the caller is a user.
func UserOnly(prev std.Realm) error {
	if !prev.IsUser() {
		return ufmt.Errorf("caller(%s) is not a user", prev.PkgPath())
	}
	return nil
}

// AdminOnly checks if the caller is the admin.
func AdminOnly(caller std.Address) error {
	adminAddr, ok := access.GetAddress(prbac.ROLE_ADMIN.String())
	if !ok || caller != adminAddr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

// GovernanceOnly checks if the caller is the governance.
func GovernanceOnly(caller std.Address) error {
	govAddr, ok := access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	if !ok || caller != govAddr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

// GovStakerOnly checks if the caller is the governance staker.
func GovStakerOnly(caller std.Address) error {
	govStakerAddr, ok := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	if !ok || caller != govStakerAddr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

// RouterOnly checks if the caller is the router.
func RouterOnly(caller std.Address) error {
	routerAddr, ok := access.GetAddress(prbac.ROLE_ROUTER.String())
	if !ok || caller != routerAddr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

// PositionOnly checks if the caller is the position.
func PositionOnly(caller std.Address) error {
	positionAddr, ok := access.GetAddress(prbac.ROLE_POSITION.String())
	if !ok || caller != positionAddr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

// PoolOnly checks if the caller is the pool.
func PoolOnly(caller std.Address) error {
	poolAddr, ok := access.GetAddress(prbac.ROLE_POOL.String())
	if !ok || caller != poolAddr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

// StakerOnly checks if the caller is the staker.
func StakerOnly(caller std.Address) error {
	stakerAddr, ok := access.GetAddress(prbac.ROLE_STAKER.String())
	if !ok || caller != stakerAddr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

// LaunchpadOnly checks if the caller is the launchpad.
func LaunchpadOnly(caller std.Address) error {
	launchpadAddr, ok := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	if !ok || caller != launchpadAddr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

// EmissionOnly checks if the caller is the emission.
func EmissionOnly(caller std.Address) error {
	emissionAddr, ok := access.GetAddress(prbac.ROLE_EMISSION.String())
	if !ok || caller != emissionAddr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}
