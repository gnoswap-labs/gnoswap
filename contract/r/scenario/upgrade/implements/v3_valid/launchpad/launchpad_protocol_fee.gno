package v3

import (
	"chain/runtime"

	"gno.land/r/gnoswap/access"
	gov_staker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/halt"
)

// CollectProtocolFee collects protocol fee from gov/staker for project recipient wallets.
// Only users can call this function.
func (lp *launchpadV1) CollectProtocolFee() {
	halt.AssertCanRecover(halt.OpTypeLaunchpad)

	previousRealm := runtime.PreviousRealm()
	access.AssertIsUser(previousRealm)

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectRewardFromLaunchPad(cross, caller)
}
