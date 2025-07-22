package protocol_fee

import (
	"std"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/halt"
)

func getPrev() (string, string) {
	prev := std.PreviousRealm()
	return prev.Address().String(), prev.PkgPath()
}

// assertOnlyNotHalted panics if the contract is halted.
func assertOnlyNotHalted() {
	// Protocol fee halting is handled in the router.
	// So, we only need to check if withdrawals are allowed here.
	if halt.IsHaltedWithdraw() {
		panic("protocol fee contract withdrawals are currently disabled")
	}
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
