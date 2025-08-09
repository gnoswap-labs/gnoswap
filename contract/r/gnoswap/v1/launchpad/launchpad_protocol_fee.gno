package launchpad

import (
	"std"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	gov_staker "gno.land/r/gnoswap/v1/gov/staker"
)

// CollectProtocolFee collects protocol fee from gov/staker for project recipient wallets.
// Only users can call this function.
func CollectProtocolFee(cur realm) {
	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := std.PreviousRealm()
	access.AssertIsUser(previousRealm)

	caller := previousRealm.Address()
	assertHasProject(caller)

	gov_staker.CollectRewardFromLaunchPad(cross, caller)
}
