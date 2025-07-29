package protocol_fee

import (
	"std"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
)

// assertCallerHasAddProtocolFeePermission panics if the caller is not the pool, router, or staker contract.
func assertCallerHasAddProtocolFeePermission() {
	caller := std.PreviousRealm().Address()

	access.AssertHasAnyRole(
		caller,
		prbac.ROLE_POOL.String(),
		prbac.ROLE_ROUTER.String(),
		prbac.ROLE_STAKER.String(),
	)
}