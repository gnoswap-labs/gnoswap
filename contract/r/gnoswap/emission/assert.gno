package emission

import (
	"gno.land/p/demo/ufmt"
)

// assertValidDistributionTarget panics if the target is invalid.
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

// assertValidDistributionPct ensures the sum of all distribution percentages is 100%
func assertValidDistributionPct(pct01, pct02, pct03, pct04 int64) {
	sum := pct01 + pct02 + pct03 + pct04
	if sum != 10000 {
		panic(makeErrorWithDetails(
			errInvalidEmissionTarget,
			ufmt.Sprintf("sum of percentages must be 10000, got %d", sum),
		))
	}
}