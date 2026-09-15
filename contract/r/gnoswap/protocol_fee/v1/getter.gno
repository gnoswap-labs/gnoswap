package protocol_fee

// GetDevOpsPct returns the percentage allocated to devOps.
//
// Returns:
//   - pct: DevOps' protocol-fee allocation percentage in basis points (0 through 10000).
func (pf *protocolFeeV1) GetDevOpsPct() int64 {
	return pf.getProtocolFeeState().DevOpsPct()
}

// GetGovStakerPct returns the percentage allocated to gov/staker.
//
// Returns:
//   - pct: Gov/Staker's protocol-fee allocation percentage in basis points, computed as 10000 minus the stored DevOps percentage.
func (pf *protocolFeeV1) GetGovStakerPct() int64 {
	return pf.getProtocolFeeState().GovStakerPct()
}

// GetReservedTokens returns token paths reserved for distribution.
//
// Returns:
//   - tokenPaths: Token paths currently reserved for protocol-fee distribution.
func (pf *protocolFeeV1) GetReservedTokens() []string {
	return pf.getProtocolFeeState().ReservedTokens()
}

// GetAccrualEpoch returns the accrual epoch fees are currently bucketed under.
//
// Returns:
//   - epoch: Current accrual epoch under which newly collected Gov/Staker amounts are bucketed.
func (pf *protocolFeeV1) GetAccrualEpoch() int64 {
	return pf.getProtocolFeeState().store.GetAccrualEpoch()
}

// GetAccrualPendingTokens returns the token paths that still own pending accrual buckets.
//
// Returns:
//   - tokenPaths: Token paths that still have one or more pending Gov/Staker accrual buckets.
func (pf *protocolFeeV1) GetAccrualPendingTokens() []string {
	return pf.getProtocolFeeState().store.GetAccrualPendingTokens()
}

// GetAccrualBuckets returns up to limit of the oldest pending buckets of tokenPath
// without clearing them. A limit of zero or less returns every pending bucket.
//
// Parameters:
//   - tokenPath: Token path whose pending Gov/Staker accrual buckets should be read.
//   - limit: Maximum number of buckets to return; zero or a negative value returns all pending buckets.
//
// Returns:
//   - epochs: Epoch numbers for the returned buckets in ascending epoch order.
//   - amounts: Gov/Staker amounts for the returned epochs; amounts[i] corresponds to epochs[i].
func (pf *protocolFeeV1) GetAccrualBuckets(tokenPath string, limit int) ([]int64, []int64) {
	return pf.getProtocolFeeState().store.GetAccrualBuckets(tokenPath, limit)
}

// GetAccuTransfersToGovStaker returns all accumulated transfers to gov/staker.
//
// Returns:
//   - transfers: Snapshot map from token path to cumulative amount allocated to Gov/Staker, including amounts still pending distribution.
func (pf *protocolFeeV1) GetAccuTransfersToGovStaker() map[string]int64 {
	accuTransfers := make(map[string]int64)

	pf.getProtocolFeeState().AccuToGovStaker().Iterate("", "", func(key string, value any) bool {
		amount, ok := value.(int64)
		if !ok {
			return false
		}

		accuTransfers[key] = amount
		return false
	})

	return accuTransfers
}

// GetAccuTransfersToDevOps returns all accumulated transfers to devOps.
//
// Returns:
//   - transfers: Snapshot map from token path to cumulative amount allocated to DevOps, including amounts still pending distribution.
func (pf *protocolFeeV1) GetAccuTransfersToDevOps() map[string]int64 {
	accuTransfers := make(map[string]int64)

	pf.getProtocolFeeState().AccuToDevOps().Iterate("", "", func(key string, value any) bool {
		amount, ok := value.(int64)
		if !ok {
			return false
		}

		accuTransfers[key] = amount
		return false
	})

	return accuTransfers
}

// GetAccuTransferToGovStakerByTokenPath returns the accumulated transfer to gov/staker by token path.
//
// Parameters:
//   - path: Token path whose cumulative Gov/Staker allocation should be read.
//
// Returns:
//   - amount: Cumulative Gov/Staker amount allocated for path, or zero when no allocation is recorded.
func (pf *protocolFeeV1) GetAccuTransferToGovStakerByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetAccuTransferToGovStakerByTokenPath(path)
}

// GetAccuTransferToDevOpsByTokenPath returns the accumulated transfer to devOps by token path.
//
// Parameters:
//   - path: Token path whose cumulative DevOps allocation should be read.
//
// Returns:
//   - amount: Cumulative DevOps amount allocated for path, or zero when no allocation is recorded.
func (pf *protocolFeeV1) GetAccuTransferToDevOpsByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetAccuTransferToDevOpsByTokenPath(path)
}

// GetActualDistributedToGovStaker returns all actual transfers to gov/staker.
//
// Returns:
//   - transfers: Snapshot map from token path to cumulative amount actually distributed to Gov/Staker.
func (pf *protocolFeeV1) GetActualDistributedToGovStaker() map[string]int64 {
	actualDistributed := make(map[string]int64)

	pf.getProtocolFeeState().ActualDistributedToGovStaker().Iterate("", "", func(key string, value any) bool {
		amount, ok := value.(int64)
		if !ok {
			return false
		}

		actualDistributed[key] = amount
		return false
	})

	return actualDistributed
}

// GetActualDistributedToDevOps returns all actual transfers to devOps.
//
// Returns:
//   - transfers: Snapshot map from token path to cumulative amount actually distributed to DevOps.
func (pf *protocolFeeV1) GetActualDistributedToDevOps() map[string]int64 {
	actualDistributed := make(map[string]int64)

	pf.getProtocolFeeState().ActualDistributedToDevOps().Iterate("", "", func(key string, value any) bool {
		amount, ok := value.(int64)
		if !ok {
			return false
		}

		actualDistributed[key] = amount
		return false
	})

	return actualDistributed
}

// GetActualDistributedToGovStakerByTokenPath returns the actual transfer to gov/staker by token path.
//
// Parameters:
//   - path: Token path whose cumulative actual Gov/Staker distribution should be read.
//
// Returns:
//   - amount: Cumulative amount actually distributed to Gov/Staker for path, or zero when no history is recorded.
func (pf *protocolFeeV1) GetActualDistributedToGovStakerByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetActualDistributedToGovStakerByTokenPath(path)
}

// GetActualDistributedToDevOpsByTokenPath returns the actual transfer to devOps by token path.
//
// Parameters:
//   - path: Token path whose cumulative actual DevOps distribution should be read.
//
// Returns:
//   - amount: Cumulative amount actually distributed to DevOps for path, or zero when no history is recorded.
func (pf *protocolFeeV1) GetActualDistributedToDevOpsByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetActualDistributedToDevOpsByTokenPath(path)
}
