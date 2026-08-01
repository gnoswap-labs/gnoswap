package emission

import (
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
)

const defaultInitialPoolTierPath = "gno.land/r/gnoland/wugnot.wugnot:gno.land/r/gnoswap/gns.GNS:3000"

// defaultInitialPoolChecker verifies the canonical default initial pool exists.
// It is registered by pool/v1 at initialization time so that emission does not
// need a compile-time dependency on the pool realm.
var defaultInitialPoolChecker func() bool

// SetDefaultInitialPoolChecker registers the callback that verifies the
// canonical default initial pool exists before emission starts.
//
// Only callable by the pool contract.
func SetDefaultInitialPoolChecker(cur realm, checker func() bool) {
	caller := cur.Previous().Address()
	access.AssertIsPool(caller)

	if checker == nil {
		panic(makeErrorWithDetails(errInvalidEmissionStart, "default initial pool checker cannot be nil"))
	}

	defaultInitialPoolChecker = checker
}

func assertDefaultInitialPoolExists() {
	if defaultInitialPoolChecker == nil {
		panic(makeErrorWithDetails(errInvalidEmissionStart, "default initial pool checker is not registered"))
	}

	if !defaultInitialPoolChecker() {
		panic(makeErrorWithDetails(errInvalidEmissionStart, "default initial pool does not exist: "+defaultInitialPoolTierPath))
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
