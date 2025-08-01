package launchpad

import (
	"std"

	"gno.land/r/gnoswap/v1/access"
	gov_staker "gno.land/r/gnoswap/v1/gov/staker"
	"gno.land/r/gnoswap/v1/halt"
)

// CollectProtocolFee collects protocol fee from gov/staker
// each project's recipient wallet will be rewarded
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_reward.gno#collectprotocolfee
func CollectProtocolFee(cur realm) {
	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := std.PreviousRealm()
	access.AssertIsUser(previousRealm)

	caller := previousRealm.Address()
	assertHasProject(caller)

	gov_staker.CollectRewardFromLaunchPad(cross, caller)
}
