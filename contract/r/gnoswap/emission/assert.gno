package emission

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

func assertDefaultInitialPoolExists() {
	if defaultInitialPoolChecker == nil {
		panic(makeErrorWithDetails(errInvalidEmissionStart, "default initial pool checker is not registered"))
	}

	if !defaultInitialPoolChecker(DefaultInitialPoolTierPath) {
		panic(makeErrorWithDetails(errInvalidEmissionStart, "default initial pool does not exist: "+DefaultInitialPoolTierPath))
	}
}

// validateDistributionTarget returns an error if the given distribution target is invalid.
//
// Parameters:
//   - target: distribution target identifier to validate
//
// Returns:
//   - error: nil for a supported target; an invalid-emission-target error otherwise
func validateDistributionTarget(target int) error {
	validTargets := map[int]bool{
		LIQUIDITY_STAKER: false,
		DEVOPS:           false,
		COMMUNITY_POOL:   false,
		GOV_STAKER:       false,
	}

	if _, ok := validTargets[target]; !ok {
		return makeErrorWithDetails(
			errInvalidEmissionTarget,
			ufmt.Sprintf("invalid target(%d)", target),
		)
	}

	return nil
}

// assertValidDistributionTarget panics if the given distribution target is invalid.
// Kept for internal invariant checks.
//
// Parameters:
//   - target: distribution target identifier that must be supported
func assertValidDistributionTarget(target int) {
	if err := validateDistributionTarget(target); err != nil {
		panic(err)
	}
}

// assertValidDistributionPct ensures the sum of all distribution percentages equals 10000 (100%).
// Panics if the sum does not equal exactly 10000 basis points.
//
// Parameters:
//   - liquidityStakerPct: liquidity-staker share in basis points, from 0 through 10000
//   - devOpsPct: development and operations share in basis points, from 0 through 10000
//   - communityPoolPct: community-pool share in basis points, from 0 through 10000
//   - govStakerPct: governance-staker share in basis points, from 0 through 10000
func assertValidDistributionPct(liquidityStakerPct, devOpsPct, communityPoolPct, govStakerPct int64) {
	// Validate individual percentages are non-negative and reasonable
	percentages := []int64{liquidityStakerPct, devOpsPct, communityPoolPct, govStakerPct}
	for i, pct := range percentages {
		if pct < 0 {
			panic(makeErrorWithDetails(
				errInvalidEmissionPct,
				ufmt.Sprintf("percentage %d cannot be negative: %d", i+1, pct),
			))
		}

		if pct > 10000 {
			panic(makeErrorWithDetails(
				errInvalidEmissionPct,
				ufmt.Sprintf("percentage %d cannot exceed 100%%: %d", i+1, pct),
			))
		}
	}

	sum := liquidityStakerPct + devOpsPct + communityPoolPct + govStakerPct
	if sum != 10000 {
		panic(makeErrorWithDetails(
			errInvalidEmissionPct,
			ufmt.Sprintf("sum of percentages must be 10000, got %d", sum),
		))
	}
}
