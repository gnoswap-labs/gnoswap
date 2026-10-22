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

// GetAccuTransfersToGovStaker returns Gov/Staker allocation lifetime statistics.
//
// Returns:
//   - transfers: token paths mapped to signed int64 statistics, wrapping modulo 2^64
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

// GetAccuTransfersToDevOps returns DevOps allocation lifetime statistics.
//
// Returns:
//   - transfers: token paths mapped to signed int64 statistics, wrapping modulo 2^64
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

// GetAccuTransferToGovStakerByTokenPath returns the Gov/Staker allocation lifetime
// statistic for path, wrapping modulo 2^64 in its signed int64 representation.
//
// Parameters:
//   - path: Token path whose cumulative Gov/Staker allocation should be read.
//
// Returns:
//   - amount: Cumulative Gov/Staker allocation statistic for path, or zero when absent.
func (pf *protocolFeeV1) GetAccuTransferToGovStakerByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetAccuTransferToGovStakerByTokenPath(path)
}

// GetAccuTransferToDevOpsByTokenPath returns the DevOps allocation lifetime
// statistic for path, wrapping modulo 2^64 in its signed int64 representation.
//
// Parameters:
//   - path: Token path whose cumulative DevOps allocation should be read.
//
// Returns:
//   - amount: Cumulative DevOps allocation statistic for path, or zero when absent.
func (pf *protocolFeeV1) GetAccuTransferToDevOpsByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetAccuTransferToDevOpsByTokenPath(path)
}

// GetActualDistributedToGovStaker returns Gov/Staker transfer lifetime statistics.
//
// Returns:
//   - transfers: token paths mapped to signed int64 statistics, wrapping modulo 2^64
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

// GetActualDistributedToDevOps returns DevOps transfer lifetime statistics.
//
// Returns:
//   - transfers: token paths mapped to signed int64 statistics, wrapping modulo 2^64
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

// GetActualDistributedToGovStakerByTokenPath returns the Gov/Staker transfer lifetime
// statistic for path, wrapping modulo 2^64 in its signed int64 representation.
//
// Parameters:
//   - path: Token path whose cumulative actual Gov/Staker distribution should be read.
//
// Returns:
//   - amount: Cumulative Gov/Staker transfer statistic for path, or zero when absent.
func (pf *protocolFeeV1) GetActualDistributedToGovStakerByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetActualDistributedToGovStakerByTokenPath(path)
}

// GetActualDistributedToDevOpsByTokenPath returns the DevOps transfer lifetime
// statistic for path, wrapping modulo 2^64 in its signed int64 representation.
//
// Parameters:
//   - path: Token path whose cumulative actual DevOps distribution should be read.
//
// Returns:
//   - amount: Cumulative DevOps transfer statistic for path, or zero when absent.
func (pf *protocolFeeV1) GetActualDistributedToDevOpsByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetActualDistributedToDevOpsByTokenPath(path)
}
