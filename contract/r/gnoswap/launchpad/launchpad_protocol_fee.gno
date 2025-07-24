package launchpad

import (
	"std"

	"gno.land/p/demo/ufmt"
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
	hasProject := false

	// check if the caller has a project,
	// if owner, break the loop
	projects.Iterate("", "", func(key string, value interface{}) bool {
		project := value.(*Project)
		hasProject = project.IsOwner(caller)

		// if true, break the loop
		return hasProject
	})

	if !hasProject {
		panic(makeErrorWithDetails(
			errInvalidOwner,
			ufmt.Sprintf("caller %s is not the owner of any project", caller.String()),
		))
	}

	gov_staker.CollectRewardFromLaunchPad(cross, caller)
}
