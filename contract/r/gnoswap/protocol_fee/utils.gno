package protocol_fee

import (
	"std"

	"gno.land/r/gnoswap/v1/access"
)

func getPrev() (string, string) {
	prev := std.PreviousRealm()
	return prev.Address().String(), prev.PkgPath()
}

// assertOnlyPoolRouterStaker panics if the caller is not the pool, router, or staker contract.
func assertOnlyPoolRouterStaker() {
	caller := std.PreviousRealm().Address()

	access.AssertIsPool(caller)
	access.AssertIsRouter(caller)
	access.AssertIsStaker(caller)
}

// assertOnlyGovStaker panics if the caller is not the gov/staker contract.
func assertOnlyGovStaker() {
	caller := std.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)
}
