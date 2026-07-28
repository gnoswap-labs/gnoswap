package emission

import (
	gnsmath "gno.land/p/gnoswap/gnsmath"
)

// GetLeftGNSAmount returns the amount of undistributed GNS tokens from previous distributions.
//
// Returns:
//   - amount: undistributed GNS amount
func GetLeftGNSAmount() int64 {
	return leftGNSAmount
}

// GetDistributionStartTimestamp returns the timestamp when emission distribution started.
//
// Returns:
//   - timestamp: distribution start timestamp, or 0 if not started
func GetDistributionStartTimestamp() int64 {
	return distributionStartTimestamp
}

// GetLastExecutedTimestamp returns the timestamp of the last emission distribution execution.
//
// Returns:
//   - timestamp: last execution timestamp
func GetLastExecutedTimestamp() int64 {
	return lastExecutedTimestamp
}

// GetAllDistributionBpsPct returns all distribution percentages in basis points.
//
// Returns:
//   - percentages: map of target to percentage in basis points
func GetAllDistributionBpsPct() map[int]int64 {
	result := make(map[int]int64, len(distributionBpsPct))
	if distributionBpsPct == nil {
		return result
	}

	for target, pct := range distributionBpsPct {
		result[target] = pct
	}

	return result
}

// GetTotalAccuDistributed returns the total accumulated distributed GNS amount.
//
// Returns:
//   - amount: total accumulated distributed GNS
func GetTotalAccuDistributed() int64 {
	return gnsmath.SafeAddInt64(
		gnsmath.SafeAddInt64(accuDistributedToStaker, accuDistributedToDevOps),
		gnsmath.SafeAddInt64(accuDistributedToCommunityPool, accuDistributedToGovStaker),
	)
}

// GetTotalDistributed returns the total pending distributed GNS amount.
//
// Returns:
//   - amount: total pending distributed GNS
func GetTotalDistributed() int64 {
	return gnsmath.SafeAddInt64(
		gnsmath.SafeAddInt64(distributedToStaker, distributedToDevOps),
		gnsmath.SafeAddInt64(distributedToCommunityPool, distributedToGovStaker),
	)
}

// GetDistributionEndTimestamp returns the timestamp when emission distribution ends.
//
// Returns:
//   - timestamp: distribution end timestamp, or 0 if not started
func GetDistributionEndTimestamp() int64 {
	if distributionStartTimestamp == 0 {
		return 0
	}

	return gnsmath.SafeAddInt64(distributionStartTimestamp, totalDistributionDuration-1)
}

// GetDistributableAmount returns distribution amounts by target and the remainder.
// If timestamp is outside the distribution window, it returns an empty map and the full amount as left.
//
// Parameters:
//   - amount: total amount to distribute
//   - timestamp: timestamp to check distribution window
//
// Returns:
//   - distributions: map of target to distribution amount
//   - remainder: undistributed amount
func GetDistributableAmount(amount, timestamp int64) (map[int]int64, int64) {
	if distributionStartTimestamp == 0 || timestamp < distributionStartTimestamp {
		return make(map[int]int64), amount
	}

	endTimestamp := GetDistributionEndTimestamp()
	if endTimestamp != 0 && timestamp > endTimestamp {
		return make(map[int]int64), amount
	}

	return calculateDistributableAmounts(amount)
}
