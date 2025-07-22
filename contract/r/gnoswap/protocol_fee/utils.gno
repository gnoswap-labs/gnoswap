package protocol_fee

import (
	"std"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
)

func getPrev() (string, string) {
	prev := std.PreviousRealm()
	return prev.Address().String(), prev.PkgPath()
}

// assertOnlyPoolRouterStaker panics if the caller is not the pool, router, or staker contract.
func assertOnlyPoolRouterStaker() {
	caller := std.PreviousRealm().Address()

	access.AssertHasAnyRole(
		caller,
		prbac.ROLE_POOL.String(),
		prbac.ROLE_ROUTER.String(),
		prbac.ROLE_STAKER.String(),
	)
}

// assertOnlyGovStaker panics if the caller is not the gov/staker contract.
func assertOnlyGovStaker() {
	caller := std.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)
}
