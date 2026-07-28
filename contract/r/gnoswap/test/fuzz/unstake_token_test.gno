package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	"gno.land/r/gnoswap/staker"
)

// TestFuzzUnStakeToken_InternalIncentive_Stateless fuzzes the StakeToken function.
func TestFuzzUnStakeToken_InternalIncentive_Stateless(cur realm, t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(cur, t)

		_, internalIncentiveTier, positionID := setupInternalIncentivePoolAndPosition(cur, ft)

		isStaked := internalIncentiveTier > 0 && fuzz.Bool().Draw(ft, "isStaked").(bool)
		if isStaked {
			setupStakePosition(cur, ft, positionID)
		}

		params := NewValidUnStakeTokenParams(ft, positionID, isStaked)

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestUnStakeToken(cur, ft, params)
	})
}

// TestFuzzUnStakeToken_ExternalIncentive_Stateless fuzzes the StakeToken function.
func TestFuzzUnStakeToken_ExternalIncentive_Stateless(cur realm, t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(cur, t)

		_, _, positionID := setupExternalRewardPoolAndPosition(cur, ft)

		isStaked := fuzz.Bool().Draw(ft, "isStaked").(bool)
		if isStaked {
			setupStakePosition(cur, ft, positionID)
		}

		params := NewValidUnStakeTokenParams(ft, positionID, isStaked)

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestUnStakeToken(cur, ft, params)
	})
}

// runTestStakeToken runs the test swap route.
func runTestUnStakeToken(cur realm, ft *fuzz.T, params *unStakeTokenParams) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	staker.UnStakeToken(
		cross(cur),
		params.positionID,
	)
}
