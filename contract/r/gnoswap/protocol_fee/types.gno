package protocol_fee

import bptree "gno.land/p/nt/bptree/v0"

type IProtocolFee interface {
	IProtocolFeeManager
	IProtocolFeeGetter
}

type IProtocolFeeManager interface {
	DistributeProtocolFee() map[string]int64
	SetDevOpsPct(pct int64)
	SetGovStakerPct(pct int64)
	AddToProtocolFee(tokenPath string, amount int64) error
}

type IProtocolFeeGetter interface {
	GetDevOpsPct() int64
	GetGovStakerPct() int64
	GetTokenListWithAmount() map[string]int64
	GetTokenList() []string
	GetAmountOfToken(tokenPath string) int64
	GetAccuTransfersToGovStaker() map[string]int64
	GetAccuTransfersToDevOps() map[string]int64
	GetAccuTransferToGovStakerByTokenPath(path string) int64
	GetAccuTransferToDevOpsByTokenPath(path string) int64
	GetActualDistributedToGovStaker() map[string]int64
	GetActualDistributedToDevOps() map[string]int64
	GetActualDistributedToGovStakerByTokenPath(path string) int64
	GetActualDistributedToDevOpsByTokenPath(path string) int64
}

type IProtocolFeeStore interface {
	HasDevOpsPctStoreKey() bool
	InitializeDevOpsPct() error
	GetDevOpsPct() int64
	SetDevOpsPct(pct int64) error

	HasAccuToGovStakerStoreKey() bool
	InitializeAccuToGovStaker() error
	GetAccuToGovStaker() *bptree.BPTree
	GetAccuToGovStakerItem(tokenPath string) (int64, bool)
	SetAccuToGovStakerItem(tokenPath string, amount int64) error

	HasAccuToDevOpsStoreKey() bool
	InitializeAccuToDevOps() error
	GetAccuToDevOps() *bptree.BPTree
	GetAccuToDevOpsItem(tokenPath string) (int64, bool)
	SetAccuToDevOpsItem(tokenPath string, amount int64) error

	HasDistributedToGovStakerHistoryStoreKey() bool
	InitializeDistributedToGovStakerHistory() error
	GetDistributedToGovStakerHistory() *bptree.BPTree
	GetDistributedToGovStakerHistoryItem(tokenPath string) (int64, bool)
	SetDistributedToGovStakerHistoryItem(tokenPath string, amount int64) error

	HasDistributedToDevOpsHistoryStoreKey() bool
	InitializeDistributedToDevOpsHistory() error
	GetDistributedToDevOpsHistory() *bptree.BPTree
	GetDistributedToDevOpsHistoryItem(tokenPath string) (int64, bool)
	SetDistributedToDevOpsHistoryItem(tokenPath string, amount int64) error

	HasTokenListWithAmountsStoreKey() bool
	InitializeTokenListWithAmount() error
	GetTokenListWithAmounts() map[string]int64
	SetTokenListWithAmounts(tokenListWithAmounts map[string]int64) error
	GetTokenListWithAmountItem(tokenPath string) (int64, bool)
	SetTokenListWithAmountItem(tokenPath string, amount int64) error
}
