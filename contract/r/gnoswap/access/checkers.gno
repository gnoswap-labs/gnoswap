package access

import (
	"std"
)

func AdminOnly(caller std.Address) error {
	return CheckCaller(ROLE_ADMIN, caller)
}

func GovernanceOnly(caller std.Address) error {
	return CheckCaller(ROLE_GOVERNANCE, caller)
}

func RouterOnly(caller std.Address) error {
	return CheckCaller(ROLE_ROUTER, caller)
}

func PoolOnly(caller std.Address) error {
	return CheckCaller(ROLE_POOL, caller)
}

func PositionOnly(caller std.Address) error {
	return CheckCaller(ROLE_POSITION, caller)
}

func StakerOnly(caller std.Address) error {
	return CheckCaller(ROLE_STAKER, caller)
}

func LaunchpadOnly(caller std.Address) error {
	return CheckCaller(ROLE_LAUNCHPAD, caller)
}

func EmissionOnly(caller std.Address) error {
	return CheckCaller(ROLE_EMISSION, caller)
}
