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
	ClearTokenListWithAmount()
	ClearAccuTransferToGovStaker()
}

type IProtocolFeeGetter interface {
	GetDevOpsPct() int64
	GetGovStakerPct() int64
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
	GetProtocolFeeState() ProtocolFeeState
	SetProtocolFeeState(protocolFeeState ProtocolFeeState) error
}

type ProtocolFeeState interface {
	DevOpsPct() int64
	GovStakerPct() int64
	AccuToGovStaker() *avl.Tree
	AccuToDevOps() *avl.Tree
}
