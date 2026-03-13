package emission

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

// assertValidDistributionTarget panics if the given distribution target is invalid.
func assertValidDistributionTarget(target int) {
	validTargets := map[int]bool{
		LIQUIDITY_STAKER: false,
		DEVOPS:           false,
		COMMUNITY_POOL:   false,
		GOV_STAKER:       false,
	}

	if _, ok := validTargets[target]; !ok {
		panic(makeErrorWithDetails(
			errInvalidEmissionTarget,
			ufmt.Sprintf("invalid target(%d)", target),
		))
	}
}

// assertValidDistributionPct ensures the sum of all distribution percentages equals 10000 (100%).
// Panics if the sum does not equal exactly 10000 basis points.
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
