package v1

// GetDevOpsPct returns the percentage allocated to devOps.
func (pf *protocolFeeV1) GetDevOpsPct() int64 {
	return pf.getProtocolFeeState().DevOpsPct()
}

// GetGovStakerPct returns the percentage allocated to gov/staker.
func (pf *protocolFeeV1) GetGovStakerPct() int64 {
	return pf.getProtocolFeeState().GovStakerPct()
}

// GetReservedTokens returns token paths reserved for distribution.
func (pf *protocolFeeV1) GetReservedTokens() []string {
	return pf.getProtocolFeeState().ReservedTokens()
}

// GetAccuTransfersToGovStaker returns all accumulated transfers to gov/staker.
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
func (pf *protocolFeeV1) GetAccuTransferToGovStakerByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetAccuTransferToGovStakerByTokenPath(path)
}

// GetAccuTransferToDevOpsByTokenPath returns the accumulated transfer to devOps by token path.
func (pf *protocolFeeV1) GetAccuTransferToDevOpsByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetAccuTransferToDevOpsByTokenPath(path)
}

// GetActualDistributedToGovStaker returns all actual transfers to gov/staker.
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
func (pf *protocolFeeV1) GetActualDistributedToGovStakerByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetActualDistributedToGovStakerByTokenPath(path)
}

// GetActualDistributedToDevOpsByTokenPath returns the actual transfer to devOps by token path.
func (pf *protocolFeeV1) GetActualDistributedToDevOpsByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetActualDistributedToDevOpsByTokenPath(path)
}
