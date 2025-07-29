package protocol_fee

// TokenList returns only the list of token path.
// If positive is true, it returns only the token path with amount > 0.
// If positive is false, it returns all the token path.
func TokenList(positive bool) []string {
	tokens := []string{}
	for tokenPath, amount := range protocolFeeState.tokenListWithAmount {
		if positive && amount == 0 {
			continue
		}
		tokens = append(tokens, tokenPath)
	}
	return tokens
}

func GetDevOpsPct() uint64 {
	return protocolFeeState.GetDevOpsPct()
}

func GetGovStakerPct() uint64 {
	return protocolFeeState.GetGovStakerPct()
}

// GetTokenListWithAmount returns the token path and amount.
func GetTokenListWithAmount() map[string]uint64 {
	return protocolFeeState.tokenListWithAmount
}

// GetAmountOfToken returns the amount of token.
func GetAmountOfToken(tokenPath string) uint64 {
	amount, exists := protocolFeeState.tokenListWithAmount[tokenPath]
	if !exists {
		return 0
	}
	return amount
}

func GetAccuTransfersToGovStaker() map[string]int64 {
	accuTransfers := make(map[string]int64)

	protocolFeeState.accuToGovStaker.Iterate("", "", func(key string, value interface{}) bool {
		amount, ok := value.(uint64)
		if !ok {
			return false
		}

		accuTransfers[key] = int64(amount)
		return false
	})

	return accuTransfers
}

func GetAccuTransfersToDevOps() map[string]int64 {
	accuTransfers := make(map[string]int64)

	protocolFeeState.accuToDevOps.Iterate("", "", func(key string, value interface{}) bool {
		amount, ok := value.(uint64)
		if !ok {
			return false
		}

		accuTransfers[key] = int64(amount)
		return false
	})

	return accuTransfers
}

// GetAccuTransferToGovStakerByTokenPath returns the accumulated transfer to gov/staker by token path.
func GetAccuTransferToGovStakerByTokenPath(path string) uint64 {
	return protocolFeeState.GetAccuTransferToGovStakerByTokenPath(path)
}

// GetAccuTransferToDevOpsByTokenPath returns the accumulated transfer to devOps by token path.
func GetAccuTransferToDevOpsByTokenPath(path string) uint64 {
	return protocolFeeState.GetAccuTransferToDevOpsByTokenPath(path)
}

// GetHistoryOfDistributedToGovStakerByTokenPath returns the history of distributed to gov/staker by token path.
func GetHistoryOfDistributedToGovStakerByTokenPath(path string) uint64 {
	amountI, exists := protocolFeeState.distributedToGovStakerHistory.Get(path)
	if !exists {
		return 0
	}
	return amountI.(uint64)
}

// GetHistoryOfDistributedToDevOpsByTokenPath returns the history of distributed to devOps by token path.
func GetHistoryOfDistributedToDevOpsByTokenPath(path string) uint64 {
	amountI, exists := protocolFeeState.distributedToDevOpsHistory.Get(path)
	if !exists {
		return 0
	}
	return amountI.(uint64)
}
