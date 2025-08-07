package xgns

import (
	"std"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
)

// assertCallerHasBurnPermission asserts that the caller has the permission to burn xGNS.
// This function is used to prevent unauthorized burning of xGNS.
func assertCallerHasBurnPermission() {
	caller := std.PreviousRealm().Address()

	access.AssertHasAnyRole(
		caller,
		prbac.ROLE_GOV_STAKER.String(),
		prbac.ROLE_LAUNCHPAD.String(),
	)
}