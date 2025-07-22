package access

import (
	"std"

	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"
)

// AdminOnly checks if the caller is the admin and optionally updates the admin address
func AdminOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_ADMIN.String(), caller)
}

// GovernanceOnly checks if the caller is the governance and optionally updates the governance address
func GovernanceOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller)
}

// GovStakerOnly checks if the caller is the gov staker and optionally updates the gov staker address
func GovStakerOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_GOV_STAKER.String(), caller)
}

// RouterOnly checks if the caller is the router and optionally updates the router address
func RouterOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_ROUTER.String(), caller)
}

// PoolOnly checks if the caller is the pool and optionally updates the pool address
func PoolOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_POOL.String(), caller)
}

// PositionOnly checks if the caller is the position and optionally updates the position address
func PositionOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_POSITION.String(), caller)
}

// StakerOnly checks if the caller is the staker and optionally updates the staker address
func StakerOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_STAKER.String(), caller)
}

// LaunchpadOnly checks if the caller is the launchpad and optionally updates the launchpad address
func LaunchpadOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_LAUNCHPAD.String(), caller)
}

// EmissionOnly checks if the caller is the emission and optionally updates the emission address
func EmissionOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_EMISSION.String(), caller)
}

// ProtocolFeeOnly checks if the caller is the protocol fee and optionally updates the protocol fee address
func ProtocolFeeOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_PROTOCOL_FEE.String(), caller)
}

// GovXGNSOnly checks if the caller is the gov xgns and optionally updates the gov xgns address
func GovXGNSOnly(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_XGNS.String(), caller)
}

// AssertIsAuthorized checks if the caller has the given role by comparing addresses
func AssertIsAuthorized(roleName string, caller std.Address) {
	roleAddr, ok := GetAddress(roleName)
	if !ok {
		panic(ufmt.Errorf("role %s does not exist", roleName))
	}

	if caller != roleAddr {
		panic(ufmt.Errorf("unauthorized: caller %s is not %s", caller, roleName))
	}
}