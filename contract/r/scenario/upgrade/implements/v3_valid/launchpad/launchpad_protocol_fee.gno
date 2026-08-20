package v3_valid

import (
	"gno.land/r/gnoswap/access"
	gov_staker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/halt"
)

// CollectProtocolFee collects protocol fee from gov/staker for project recipient wallets.
// Only project recipients can call this function.
func (lp *launchpadV1) CollectProtocolFee(_ int, rlm realm) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectRewardFromLaunchPad(cross(rlm), caller)
}

// CollectEmissionReward collects emission rewards from gov/staker for project recipient wallets.
// Only project recipients can call this function.
func (lp *launchpadV1) CollectEmissionReward(_ int, rlm realm) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectEmissionRewardFromLaunchPad(cross(rlm), caller)
}

// CollectProtocolFeeReward collects one token path of protocol fee rewards from gov/staker for project recipient wallets.
// Only project recipients can call this function.
func (lp *launchpadV1) CollectProtocolFeeReward(_ int, rlm realm, tokenPath string) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectProtocolFeeRewardFromLaunchPad(cross(rlm), caller, tokenPath)
}
