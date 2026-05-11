package v3

import (
	"chain/runtime"

	"gno.land/r/gnoswap/halt"
	gov_staker "gno.land/r/gnoswap/gov/staker"
)

// CollectProtocolFee collects protocol fee from gov/staker for project recipient wallets.
// Only project recipients can call this function.
func (lp *launchpadV1) CollectProtocolFee() {
	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := runtime.PreviousRealm()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectRewardFromLaunchPad(cross, caller)
}
