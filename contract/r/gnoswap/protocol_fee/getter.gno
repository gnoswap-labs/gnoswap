package protocol_fee

import (
	"gno.land/p/demo/avl"
)

// GetAccuTransferToGovStaker returns the accuToGovStaker.
func GetAccuTransferToGovStaker() *avl.Tree {
	return accuToGovStaker
}

// GetAccuTransferToDevOps returns the accuToDevOps.
func GetAccuTransferToDevOps() *avl.Tree {
	return accuToDevOps
}

// GetAccuTransferToGovStakerByTokenPath returns the accumulated transfer to gov/staker by token path.
func GetAccuTransferToGovStakerByTokenPath(path string) uint64 {
	amountI, exists := accuToGovStaker.Get(path)
	if !exists {
		return 0
	}

	return amountI.(uint64)
}

// GetAccuTransferToDevOpsByTokenPath returns the accumulated transfer to devOps by token path.
func GetAccuTransferToDevOpsByTokenPath(path string) uint64 {
	amountI, exists := accuToDevOps.Get(path)
	if !exists {
		return 0
	}

	return amountI.(uint64)
}

// GetHistoryOfDistributedToGovStaker returns the history of distributed to gov/staker.
func GetHistoryOfDistributedToGovStaker() *avl.Tree {
	return distributedToGovStakerHistory
}

// GetHistoryOfDistributedToDevOps returns the history of distributed to devOps.
func GetHistoryOfDistributedToDevOps() *avl.Tree {
	return distributedToDevOpsHistory
}

// GetHistoryOfDistributedToGovStakerByTokenPath returns the history of distributed to gov/staker by token path.
func GetHistoryOfDistributedToGovStakerByTokenPath(path string) uint64 {
	amountI, exists := distributedToGovStakerHistory.Get(path)
	if !exists {
		return 0
	}

	return amountI.(uint64)
}

// GetHistoryOfDistributedToDevOpsByTokenPath returns the history of distributed to devOps by token path.
func GetHistoryOfDistributedToDevOpsByTokenPath(path string) uint64 {
	amountI, exists := distributedToDevOpsHistory.Get(path)
	if !exists {
		return 0
	}

	return amountI.(uint64)
}
