package protocol_fee

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

// GetDevOpsPct returns the percentage allocated to devOps.
func GetDevOpsPct() int64 {
	return protocolFeeState.DevOpsPct()
}

// GetGovStakerPct returns the percentage allocated to gov/staker.
func GetGovStakerPct() int64 {
	return protocolFeeState.GovStakerPct()
}

// GetTokenListWithAmount returns the token path and amount.
func GetTokenListWithAmount() map[string]int64 {
	return protocolFeeState.tokenListWithAmount
}

// GetAmountOfToken returns the amount of token.
func GetAmountOfToken(tokenPath string) int64 {
	amount, exists := protocolFeeState.tokenListWithAmount[tokenPath]
	if !exists {
		return 0
	}
	return amount
}

// GetAccuTransfersToGovStaker returns all accumulated transfers to gov/staker.
func GetAccuTransfersToGovStaker() map[string]int64 {
	accuTransfers := make(map[string]int64)

	protocolFeeState.accuToGovStaker.Iterate("", "", func(key string, value any) bool {
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
func GetAccuTransfersToDevOps() map[string]int64 {
	accuTransfers := make(map[string]int64)

	protocolFeeState.accuToDevOps.Iterate("", "", func(key string, value any) bool {
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
func GetAccuTransferToGovStakerByTokenPath(path string) int64 {
	return protocolFeeState.GetAccuTransferToGovStakerByTokenPath(path)
}

// GetAccuTransferToDevOpsByTokenPath returns the accumulated transfer to devOps by token path.
func GetAccuTransferToDevOpsByTokenPath(path string) int64 {
	return protocolFeeState.GetAccuTransferToDevOpsByTokenPath(path)
}

// GetHistoryOfDistributedToGovStakerByTokenPath returns the history of distributed to gov/staker by token path.
func GetHistoryOfDistributedToGovStakerByTokenPath(path string) int64 {
	history := protocolFeeState.distributedToGovStakerHistory
	return retrieveHistory(history, path)
}

// GetHistoryOfDistributedToDevOpsByTokenPath returns the history of distributed to devOps by token path.
func GetHistoryOfDistributedToDevOpsByTokenPath(path string) int64 {
	history := protocolFeeState.distributedToDevOpsHistory
	return retrieveHistory(history, path)
}

// retrieveHistory retrieves distribution history amount from AVL tree.
func retrieveHistory(tree *avl.Tree, key string) int64 {
	amountI, exists := tree.Get(key)
	if !exists {
		return 0
	}
	res, ok := amountI.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast amount to int64: %T", amountI))
	}
	return res
}
