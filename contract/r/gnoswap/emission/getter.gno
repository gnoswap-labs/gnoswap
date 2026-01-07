package emission

// GetLeftGNSAmount returns the amount of undistributed GNS tokens from previous distributions.
func GetLeftGNSAmount() int64 {
	return leftGNSAmount
}

// GetDistributionStartTimestamp returns the timestamp when emission distribution started.
// Returns 0 if distribution has not been started yet.
func GetDistributionStartTimestamp() int64 {
	return distributionStartTimestamp
}

// GetLastExecutedTimestamp returns the timestamp of the last emission distribution execution.
func GetLastExecutedTimestamp() int64 {
	return lastExecutedTimestamp
}

// GetAllDistributionBpsPct returns all distribution percentages in basis points.
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
func GetTotalAccuDistributed() int64 {
	return safeAddInt64(
		safeAddInt64(accuDistributedToStaker, accuDistributedToDevOps),
		safeAddInt64(accuDistributedToCommunityPool, accuDistributedToGovStaker),
	)
}

// GetTotalDistributed returns the total pending distributed GNS amount.
func GetTotalDistributed() int64 {
	return safeAddInt64(
		safeAddInt64(distributedToStaker, distributedToDevOps),
		safeAddInt64(distributedToCommunityPool, distributedToGovStaker),
	)
}

// GetDistributionEndTimestamp returns the timestamp when emission distribution ends.
// Returns 0 if distribution has not been started yet.
func GetDistributionEndTimestamp() int64 {
	if distributionStartTimestamp == 0 {
		return 0
	}

	return safeAddInt64(distributionStartTimestamp, totalDistributionDuration-1)
}

// DistributionSummaryView is a read-only snapshot of distribution state.
type DistributionSummaryView struct {
	DistributionBpsPct map[int]int64
	PendingTotal       int64
	AccuTotal          int64
}

// GetDistributionSummaryView returns a snapshot of distribution ratios and totals.
func GetDistributionSummaryView() DistributionSummaryView {
	return DistributionSummaryView{
		DistributionBpsPct: GetAllDistributionBpsPct(),
		PendingTotal:       GetTotalDistributed(),
		AccuTotal:          GetTotalAccuDistributed(),
	}
}
