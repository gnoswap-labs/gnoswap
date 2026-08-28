package launchpad

import (
	"chain"
	"errors"

	gov_staker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/halt"
)

// CollectProtocolFee collects protocol fee from gov/staker for project recipient wallets.
// Only project recipients can call this function.
func (lp *launchpadV1) CollectProtocolFee(_ int, rlm realm) {
	if !rlm.IsCurrent() {
		panic(errors.New(errSpoofedRealm))
	}

	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectRewardFromLaunchPad(cross(rlm), caller)

	chain.Emit(
		"CollectProtocolFee",
		"packagePath", rlm.PkgPath(),
		"version", "sapphire-2026-08-10",
	)
}

// CollectEmissionReward collects emission rewards from gov/staker for project recipient wallets.
// Only project recipients can call this function.
func (lp *launchpadV1) CollectEmissionReward(_ int, rlm realm) {
	if !rlm.IsCurrent() {
		panic(errors.New(errSpoofedRealm))
	}

	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectEmissionRewardFromLaunchPad(cross(rlm), caller)

	chain.Emit(
		"CollectEmissionReward",
		"packagePath", rlm.PkgPath(),
		"version", "sapphire-2026-08-10",
	)
}

// CollectProtocolFeeReward collects one token path of protocol fee rewards from gov/staker for project recipient wallets.
// Only project recipients can call this function.
func (lp *launchpadV1) CollectProtocolFeeReward(_ int, rlm realm, tokenPath string) {
	if !rlm.IsCurrent() {
		panic(errors.New(errSpoofedRealm))
	}

	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()

	caller := previousRealm.Address()
	lp.assertHasProject(caller)

	gov_staker.CollectProtocolFeeRewardFromLaunchPad(cross(rlm), caller, tokenPath)

	chain.Emit(
		"CollectProtocolFeeReward",
		"packagePath", rlm.PkgPath(),
		"version", "sapphire-2026-08-10",
	)
}
