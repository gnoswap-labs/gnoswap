package v1

import (
	"gno.land/r/gnoswap/halt"
	gov_staker "gno.land/r/gnoswap/gov/staker"
)

// CollectProtocolFee collects protocol fee from gov/staker for project recipient wallets.
// Only project recipients can call this function.
func (lp *launchpadV1) CollectProtocolFee(_ int, rlm realm) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectRewardFromLaunchPad(cross(rlm), caller)
}
