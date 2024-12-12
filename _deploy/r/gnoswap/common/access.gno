package common

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/consts"
)

const (
	ErrNoPermission = "caller(%s) has no permission"
)

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

func AdminOnly(caller std.Address) error {
	if caller != consts.ADMIN {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

func GovernanceOnly(caller std.Address) error {
	if caller != consts.GOV_GOVERNANCE_ADDR {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

func GovStakerOnly(caller std.Address) error {
	if caller != consts.GOV_STAKER_ADDR {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

func RouterOnly(caller std.Address) error {
	if caller != consts.ROUTER_ADDR {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

func PositionOnly(caller std.Address) error {
	if caller != consts.POSITION_ADDR {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

func StakerOnly(caller std.Address) error {
	if caller != consts.STAKER_ADDR {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

func LaunchpadOnly(caller std.Address) error {
	if caller != consts.LAUNCHPAD_ADDR {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

func EmissionOnly(caller std.Address) error {
	if caller != consts.EMISSION_ADDR {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

// DEPRECATED
// TODO: remove after r/grc20reg is applied for all contracts
func TokenRegisterOnly(caller std.Address) error {
	if caller != consts.TOKEN_REGISTER {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

// realm assertion

func UserOnly(prev std.Realm) error {
	if !prev.IsUser() {
		return ufmt.Errorf("caller(%s) is not a user", prev.PkgPath())
	}
	return nil
}
