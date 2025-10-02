package emission

import (
	"gno.land/p/nt/ufmt"
)

// assertValidDistributionTargets panics if any of the four distribution targets is invalid
// or if there are duplicate targets. All four distribution targets must be unique and valid.
func assertValidDistributionTargets(target01, target02, target03, target04 int) {
	validTargets := map[int]bool{
		LIQUIDITY_STAKER: false,
		DEVOPS:           false,
		COMMUNITY_POOL:   false,
		GOV_STAKER:       false,
	}

	currentTargets := []int{target01, target02, target03, target04}

	for _, target := range currentTargets {
		if _, ok := validTargets[target]; !ok {
			panic(makeErrorWithDetails(
				errInvalidEmissionTarget,
				ufmt.Sprintf("invalid target(%d)", target),
			))
		}

		validTargets[target] = true
	}

	for _, valid := range validTargets {
		if !valid {
			panic(errDuplicateTarget)
		}
	}
}

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
func assertValidDistributionPct(pct01, pct02, pct03, pct04 int64) {
	// Validate individual percentages are non-negative and reasonable
	percentages := []int64{pct01, pct02, pct03, pct04}
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

	sum := pct01 + pct02 + pct03 + pct04
	if sum != 10000 {
		panic(makeErrorWithDetails(
			errInvalidEmissionPct,
			ufmt.Sprintf("sum of percentages must be 10000, got %d", sum),
		))
	}
}
