package launchpad

import (
	"std"

	gov_staker "gno.land/r/gnoswap/v1/gov/staker"
)

// CollectProtocolFee collects protocol fee from gov/staker
// each project's recipient wallet will be rewarded
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_reward.gno#collectprotocolfee
func CollectProtocolFee(cur realm) {
	callerAddress := std.PreviousRealm().Address()	
	
	gov_staker.CollectRewardFromLaunchPad(cross, callerAddress)
}