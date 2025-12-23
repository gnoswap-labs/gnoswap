package staker

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	"gno.land/r/gnoswap/staker"
)

// TestFuzzUnStakeToken_InternalIncentive_Stateless fuzzes the StakeToken function.
func TestFuzzUnStakeToken_InternalIncentive_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(t)

		_, internalIncentiveTier, positionID := setupInternalIncentivePoolAndPosition(ft)

		isStaked := internalIncentiveTier > 0 && fuzz.Bool().Draw(ft, "isStaked").(bool)
		if isStaked {
			setupStakePosition(ft, positionID)
		}

		params := NewValidUnStakeTokenParams(ft, positionID, isStaked)

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestUnStakeToken(ft, params)
	})
}

// TestFuzzUnStakeToken_ExternalIncentive_Stateless fuzzes the StakeToken function.
func TestFuzzUnStakeToken_ExternalIncentive_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(t)

		_, _, positionID := setupExternalRewardPoolAndPosition(ft)

		isStaked := fuzz.Bool().Draw(ft, "isStaked").(bool)
		if isStaked {
			setupStakePosition(ft, positionID)
		}

		params := NewValidUnStakeTokenParams(ft, positionID, isStaked)

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestUnStakeToken(ft, params)
	})
}

// runTestStakeToken runs the test swap route.
func runTestUnStakeToken(ft *fuzz.T, params *unStakeTokenParams) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	staker.UnStakeToken(
		cross,
		params.positionID,
		false,
	)
}
