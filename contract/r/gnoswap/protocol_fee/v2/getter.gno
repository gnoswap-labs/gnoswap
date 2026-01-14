package v2

// GetDevOpsPct returns the percentage allocated to devOps.
func (pf *protocolFeeV1) GetDevOpsPct() int64 {
	return pf.getProtocolFeeState().DevOpsPct()
}

// GetGovStakerPct returns the percentage allocated to gov/staker.
func (pf *protocolFeeV1) GetGovStakerPct() int64 {
	return pf.getProtocolFeeState().GovStakerPct()
}

// GetTokenListWithAmount returns the token path and amount.
func (pf *protocolFeeV1) GetTokenListWithAmount() map[string]int64 {
	return pf.getProtocolFeeState().TokenListWithAmounts()
}

// GetTokenList returns the list of token paths without amounts.
func (pf *protocolFeeV1) GetTokenList() []string {
	tokenListWithAmount := pf.getProtocolFeeState().TokenListWithAmounts()
	tokens := make([]string, 0, len(tokenListWithAmount))
	for token := range tokenListWithAmount {
		tokens = append(tokens, token)
	}

	return tokens
}

// GetAmountOfToken returns the amount of token.
func (pf *protocolFeeV1) GetAmountOfToken(tokenPath string) int64 {
	amount, exists := pf.getProtocolFeeState().TokenListWithAmounts()[tokenPath]
	if !exists {
		return 0
	}
	return amount
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

// GetHistoryOfDistributedToGovStakerByTokenPath returns the history of distributed to gov/staker by token path.
func (pf *protocolFeeV1) GetHistoryOfDistributedToGovStakerByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetDistributedToGovStakerHistoryByTokenPath(path)
}

// GetHistoryOfDistributedToDevOpsByTokenPath returns the history of distributed to devOps by token path.
func (pf *protocolFeeV1) GetHistoryOfDistributedToDevOpsByTokenPath(path string) int64 {
	return pf.getProtocolFeeState().GetDistributedToDevOpsHistoryByTokenPath(path)
}
