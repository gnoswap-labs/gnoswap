package protocol_fee

import "gno.land/p/nt/avl"

type IProtocolFee interface {
	IProtocolFeeManager
	IProtocolFeeGetter
	IProtocolFeeApi
}

type IProtocolFeeManager interface {
	DistributeProtocolFee() map[string]int64
	SetDevOpsPct(pct int64)
	SetGovStakerPct(pct int64)
	AddToProtocolFee(tokenPath string, amount int64)
	SetDustClaimMinAmount(amount int64)
	SetDustClaimMaxAmount(amount int64)
	ClaimDustToGns(tokenPaths []string, amounts []int64, routeArrs []string, quoteArrs []string, amountOutMins []string, deadline int64, referrer string, recipient address) int64
	ClearTokenListWithAmount()
	ClearAccuTransferToGovStaker()
}

type IProtocolFeeGetter interface {
	GetDevOpsPct() int64
	GetGovStakerPct() int64
	GetDustClaimMinAmount() int64
	GetDustClaimMaxAmount() int64
	GetTokenListWithAmount() map[string]int64
	GetAmountOfToken(tokenPath string) int64
	GetAccuTransfersToGovStaker() map[string]int64
	GetAccuTransfersToDevOps() map[string]int64
	GetAccuTransferToGovStakerByTokenPath(path string) int64
	GetAccuTransferToDevOpsByTokenPath(path string) int64
	GetHistoryOfDistributedToGovStakerByTokenPath(path string) int64
	GetHistoryOfDistributedToDevOpsByTokenPath(path string) int64
}

type IProtocolFeeApi interface {
	ApiGetAccuTransferToGovStaker() string
	ApiGetAccuTransferToDevOps() string
	ApiGetHistoryTransferToGovStaker() string
	ApiGetHistoryTransferToDevOps() string
	ApiGetActualBalance() string
	ApiGetRecordedBalance() string
	ApiGetUnrecordedBalance() string
}

type IProtocolFeeStore interface {
	HasDevOpsPctStoreKey() bool
	InitializeDevOpsPct() error
	GetDevOpsPct() int64
	SetDevOpsPct(pct int64) error

	HasDustClaimMinAmountStoreKey() bool
	InitializeDustClaimMinAmount() error
	GetDustClaimMinAmount() int64
	SetDustClaimMinAmount(amount int64) error

	HasDustClaimMaxAmountStoreKey() bool
	InitializeDustClaimMaxAmount() error
	GetDustClaimMaxAmount() int64
	SetDustClaimMaxAmount(amount int64) error

	HasAccuToGovStakerStoreKey() bool
	InitializeAccuToGovStaker() error
	GetAccuToGovStaker() *avl.Tree
	GetAccuToGovStakerItem(tokenPath string) (int64, bool)
	SetAccuToGovStakerItem(tokenPath string, amount int64) error

	HasAccuToDevOpsStoreKey() bool
	InitializeAccuToDevOps() error
	GetAccuToDevOps() *avl.Tree
	GetAccuToDevOpsItem(tokenPath string) (int64, bool)
	SetAccuToDevOpsItem(tokenPath string, amount int64) error

	HasDistributedToGovStakerHistoryStoreKey() bool
	InitializeDistributedToGovStakerHistory() error
	GetDistributedToGovStakerHistory() *avl.Tree
	GetDistributedToGovStakerHistoryItem(tokenPath string) (int64, bool)
	SetDistributedToGovStakerHistoryItem(tokenPath string, amount int64) error

	HasDistributedToDevOpsHistoryStoreKey() bool
	InitializeDistributedToDevOpsHistory() error
	GetDistributedToDevOpsHistory() *avl.Tree
	GetDistributedToDevOpsHistoryItem(tokenPath string) (int64, bool)
	SetDistributedToDevOpsHistoryItem(tokenPath string, amount int64) error

	HasTokenListWithAmountsStoreKey() bool
	InitializeTokenListWithAmount() error
	GetTokenListWithAmounts() map[string]int64
	SetTokenListWithAmounts(tokenListWithAmounts map[string]int64) error
	GetTokenListWithAmountItem(tokenPath string) (int64, bool)
	SetTokenListWithAmountItem(tokenPath string, amount int64) error
}
