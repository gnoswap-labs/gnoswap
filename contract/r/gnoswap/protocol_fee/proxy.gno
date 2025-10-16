package protocol_fee

func DistributeProtocolFee(cur realm) map[string]int64 {
	return getImplementation().DistributeProtocolFee()
}

func SetDevOpsPct(cur realm, pct int64) {
	getImplementation().SetDevOpsPct(pct)
}

func SetGovStakerPct(cur realm, pct int64) {
	getImplementation().SetGovStakerPct(pct)
}

func AddToProtocolFee(cur realm, tokenPath string, amount int64) {
	getImplementation().AddToProtocolFee(tokenPath, amount)
}

func ClearTokenListWithAmount(cur realm) {
	getImplementation().ClearTokenListWithAmount()
}

func ClearAccuTransferToGovStaker(cur realm) {
	getImplementation().ClearAccuTransferToGovStaker()
}

func GetDevOpsPct() int64 {
	return getImplementation().GetDevOpsPct()
}

func GetGovStakerPct() int64 {
	return getImplementation().GetGovStakerPct()
}

func GetTokenListWithAmount() map[string]int64 {
	return getImplementation().GetTokenListWithAmount()
}

func GetAmountOfToken(tokenPath string) int64 {
	return getImplementation().GetAmountOfToken(tokenPath)
}

func GetAccuTransfersToGovStaker() map[string]int64 {
	return getImplementation().GetAccuTransfersToGovStaker()
}

func GetAccuTransfersToDevOps() map[string]int64 {
	return getImplementation().GetAccuTransfersToDevOps()
}

func GetAccuTransferToGovStakerByTokenPath(tokenPath string) int64 {
	return getImplementation().GetAccuTransferToGovStakerByTokenPath(tokenPath)
}

func GetAccuTransferToDevOpsByTokenPath(tokenPath string) int64 {
	return getImplementation().GetAccuTransferToDevOpsByTokenPath(tokenPath)
}

func GetHistoryOfDistributedToGovStakerByTokenPath(tokenPath string) int64 {
	return getImplementation().GetHistoryOfDistributedToGovStakerByTokenPath(tokenPath)
}

func GetHistoryOfDistributedToDevOpsByTokenPath(tokenPath string) int64 {
	return getImplementation().GetHistoryOfDistributedToDevOpsByTokenPath(tokenPath)
}

func ApiGetAccuTransferToGovStaker() string {
	return getImplementation().ApiGetAccuTransferToGovStaker()
}

func ApiGetAccuTransferToDevOps() string {
	return getImplementation().ApiGetAccuTransferToDevOps()
}

func ApiGetHistoryTransferToGovStaker() string {
	return getImplementation().ApiGetHistoryTransferToGovStaker()
}

func ApiGetHistoryTransferToDevOps() string {
	return getImplementation().ApiGetHistoryTransferToDevOps()
}

func ApiGetActualBalance() string {
	return getImplementation().ApiGetActualBalance()
}

func ApiGetRecordedBalance() string {
	return getImplementation().ApiGetRecordedBalance()
}

func ApiGetUnrecordedBalance() string {
	return getImplementation().ApiGetUnrecordedBalance()
}
