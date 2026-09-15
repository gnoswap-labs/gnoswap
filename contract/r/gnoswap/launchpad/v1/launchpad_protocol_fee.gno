package launchpad

import (
	"gno.land/r/gnoswap/access/v1"

	gov_staker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/halt/v1"
)

// CollectProtocolFee collects protocol fee from gov/staker for project recipient wallets.
// Only project recipients can call this function.
//
// Parameters:
//   - _: Noncrossing implementation-call discriminator; pass 0.
//   - rlm: Current realm context forwarded unchanged by the launchpad proxy; validated before collection.
func (lp *launchpadV1) CollectProtocolFee(_ int, rlm realm) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectRewardFromLaunchPad(cross(rlm), caller)
}

// CollectEmissionReward collects emission rewards from gov/staker for project recipient wallets.
// Only project recipients can call this function.
//
// Parameters:
//   - _: Noncrossing implementation-call discriminator; pass 0.
//   - rlm: Current realm context forwarded unchanged by the launchpad proxy; validated before collection.
func (lp *launchpadV1) CollectEmissionReward(_ int, rlm realm) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectEmissionRewardFromLaunchPad(cross(rlm), caller)
}

// CollectProtocolFeeReward collects one token path of protocol fee rewards from gov/staker for project recipient wallets.
// Only project recipients can call this function.
//
// Parameters:
//   - _: Noncrossing implementation-call discriminator; pass 0.
//   - rlm: Current realm context forwarded unchanged by the launchpad proxy; validated before collection.
//   - tokenPath: token contract path whose protocol-fee reward is collected.
func (lp *launchpadV1) CollectProtocolFeeReward(_ int, rlm realm, tokenPath string) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectProtocolFeeRewardFromLaunchPad(cross(rlm), caller, tokenPath)
}
