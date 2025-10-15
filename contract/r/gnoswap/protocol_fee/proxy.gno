package protocol_fee

func DistributeProtocolFee(cur realm) map[string]int64 {
	return getImpl().DistributeProtocolFee()
}

func SetDevOpsPct(cur realm, pct int64) {
	getImpl().SetDevOpsPct(pct)
}

func SetGovStakerPct(cur realm, pct int64) {
	getImpl().SetGovStakerPct(pct)
}

func AddToProtocolFee(cur realm, tokenPath string, amount int64) {
	getImpl().AddToProtocolFee(tokenPath, amount)
}

func ClearTokenListWithAmount(cur realm) {
	getImpl().ClearTokenListWithAmount()
}

func ClearAccuTransferToGovStaker(cur realm) {
	getImpl().ClearAccuTransferToGovStaker()
}

func GetDevOpsPct() int64 {
	return getImpl().GetDevOpsPct()
}

func GetGovStakerPct() int64 {
	return getImpl().GetGovStakerPct()
}

func GetTokenListWithAmount() map[string]int64 {
	return getImpl().GetTokenListWithAmount()
}

func GetAmountOfToken(tokenPath string) int64 {
	return getImpl().GetAmountOfToken(tokenPath)
}

func GetAccuTransfersToGovStaker() map[string]int64 {
	return getImpl().GetAccuTransfersToGovStaker()
}

func GetAccuTransfersToDevOps() map[string]int64 {
	return getImpl().GetAccuTransfersToDevOps()
}

func GetAccuTransferToGovStakerByTokenPath(tokenPath string) int64 {
	return getImpl().GetAccuTransferToGovStakerByTokenPath(tokenPath)
}

func GetAccuTransferToDevOpsByTokenPath(tokenPath string) int64 {
	return getImpl().GetAccuTransferToDevOpsByTokenPath(tokenPath)
}

func GetHistoryOfDistributedToGovStakerByTokenPath(tokenPath string) int64 {
	return getImpl().GetHistoryOfDistributedToGovStakerByTokenPath(tokenPath)
}

func GetHistoryOfDistributedToDevOpsByTokenPath(tokenPath string) int64 {
	return getImpl().GetHistoryOfDistributedToDevOpsByTokenPath(tokenPath)
}

func ApiGetAccuTransferToGovStaker() string {
	return getImpl().ApiGetAccuTransferToGovStaker()
}

func ApiGetAccuTransferToDevOps() string {
	return getImpl().ApiGetAccuTransferToDevOps()
}

func ApiGetHistoryTransferToGovStaker() string {
	return getImpl().ApiGetHistoryTransferToGovStaker()
}

func ApiGetHistoryTransferToDevOps() string {
	return getImpl().ApiGetHistoryTransferToDevOps()
}

func ApiGetActualBalance() string {
	return getImpl().ApiGetActualBalance()
}

func ApiGetRecordedBalance() string {
	return getImpl().ApiGetRecordedBalance()
}

func ApiGetUnrecordedBalance() string {
	return getImpl().ApiGetUnrecordedBalance()
}

func getImpl() IProtocolFee {
	return protocolFeeImpl
}
