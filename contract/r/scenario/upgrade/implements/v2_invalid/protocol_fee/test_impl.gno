// Simplified test implementation for protocol_fee contract upgrade testing
package v2_invalid

import (
	protocolFee "gno.land/r/gnoswap/protocol_fee"
	v1 "gno.land/r/gnoswap/protocol_fee/v1"
)

func NewV2InvalidProtocolFee(store protocolFee.IProtocolFeeStore) protocolFee.IProtocolFee {
	instance := v1.NewProtocolFeeV1(store)

	return &TestProtocolFee{
		instance:      instance,
		activeMethods: make(map[string]bool),
	}
}

func init() {
	protocolFee.RegisterInitializer(cross, func(store protocolFee.IProtocolFeeStore) protocolFee.IProtocolFee {
		return NewV2InvalidProtocolFee(store)
	})
}

// TestProtocolFee is a minimal test implementation that delegates to v1 only when method is activated
type TestProtocolFee struct {
	instance      protocolFee.IProtocolFee
	activeMethods map[string]bool
}

func (t *TestProtocolFee) SetActiveMethod(fnName string, activated bool) {
	t.activeMethods[fnName] = activated
}

func (t *TestProtocolFee) isActive(fnName string) bool {
	active, ok := t.activeMethods[fnName]
	return ok && active
}

// IProtocolFeeManager interface
func (t *TestProtocolFee) DistributeProtocolFee() map[string]int64 {
	if !t.isActive("DistributeProtocolFee") {
		panic("test implementation: DistributeProtocolFee not supported")
	}
	return t.instance.DistributeProtocolFee()
}

func (t *TestProtocolFee) SetDevOpsPct(pct int64) {
	if !t.isActive("SetDevOpsPct") {
		panic("test implementation: SetDevOpsPct not supported")
	}
	t.instance.SetDevOpsPct(pct)
}

func (t *TestProtocolFee) SetGovStakerPct(pct int64) {
	if !t.isActive("SetGovStakerPct") {
		panic("test implementation: SetGovStakerPct not supported")
	}
	t.instance.SetGovStakerPct(pct)
}

func (t *TestProtocolFee) AddToProtocolFee(tokenPath string, amount int64) {
	if !t.isActive("AddToProtocolFee") {
		panic("test implementation: AddToProtocolFee not supported")
	}
	t.instance.AddToProtocolFee(tokenPath, amount)
}

func (t *TestProtocolFee) SetDustClaimMinAmount(amount int64) {
	if !t.isActive("SetDustClaimMinAmount") {
		panic("test implementation: SetDustClaimMinAmount not supported")
	}
	t.instance.SetDustClaimMinAmount(amount)
}

func (t *TestProtocolFee) SetDustClaimMaxAmount(amount int64) {
	if !t.isActive("SetDustClaimMaxAmount") {
		panic("test implementation: SetDustClaimMaxAmount not supported")
	}
	t.instance.SetDustClaimMaxAmount(amount)
}

func (t *TestProtocolFee) ClaimDustToGns(tokenPaths []string, amounts []int64, routeArrs []string, quoteArrs []string, amountOutMins []string, deadline int64, referrer string, recipient address) int64 {
	if !t.isActive("ClaimDustToGns") {
		panic("test implementation: ClaimDustToGns not supported")
	}
	return t.instance.ClaimDustToGns(tokenPaths, amounts, routeArrs, quoteArrs, amountOutMins, deadline, referrer, recipient)
}

func (t *TestProtocolFee) ClearTokenListWithAmount() {
	if !t.isActive("ClearTokenListWithAmount") {
		panic("test implementation: ClearTokenListWithAmount not supported")
	}
	t.instance.ClearTokenListWithAmount()
}

func (t *TestProtocolFee) ClearAccuTransferToGovStaker() {
	if !t.isActive("ClearAccuTransferToGovStaker") {
		panic("test implementation: ClearAccuTransferToGovStaker not supported")
	}
	t.instance.ClearAccuTransferToGovStaker()
}

// IProtocolFeeGetter interface
func (t *TestProtocolFee) GetDevOpsPct() int64 {
	if !t.isActive("GetDevOpsPct") {
		panic("test implementation: GetDevOpsPct not supported")
	}
	return t.instance.GetDevOpsPct()
}

func (t *TestProtocolFee) GetGovStakerPct() int64 {
	if !t.isActive("GetGovStakerPct") {
		panic("test implementation: GetGovStakerPct not supported")
	}
	return t.instance.GetGovStakerPct()
}

func (t *TestProtocolFee) GetDustClaimMinAmount() int64 {
	if !t.isActive("GetDustClaimMinAmount") {
		panic("test implementation: GetDustClaimMinAmount not supported")
	}
	return t.instance.GetDustClaimMinAmount()
}

func (t *TestProtocolFee) GetDustClaimMaxAmount() int64 {
	if !t.isActive("GetDustClaimMaxAmount") {
		panic("test implementation: GetDustClaimMaxAmount not supported")
	}
	return t.instance.GetDustClaimMaxAmount()
}

func (t *TestProtocolFee) GetTokenListWithAmount() map[string]int64 {
	if !t.isActive("GetTokenListWithAmount") {
		panic("test implementation: GetTokenListWithAmount not supported")
	}
	return t.instance.GetTokenListWithAmount()
}

func (t *TestProtocolFee) GetAmountOfToken(tokenPath string) int64 {
	if !t.isActive("GetAmountOfToken") {
		panic("test implementation: GetAmountOfToken not supported")
	}
	return t.instance.GetAmountOfToken(tokenPath)
}

func (t *TestProtocolFee) GetAccuTransfersToGovStaker() map[string]int64 {
	if !t.isActive("GetAccuTransfersToGovStaker") {
		panic("test implementation: GetAccuTransfersToGovStaker not supported")
	}
	return t.instance.GetAccuTransfersToGovStaker()
}

func (t *TestProtocolFee) GetAccuTransfersToDevOps() map[string]int64 {
	if !t.isActive("GetAccuTransfersToDevOps") {
		panic("test implementation: GetAccuTransfersToDevOps not supported")
	}
	return t.instance.GetAccuTransfersToDevOps()
}

func (t *TestProtocolFee) GetAccuTransferToGovStakerByTokenPath(path string) int64 {
	if !t.isActive("GetAccuTransferToGovStakerByTokenPath") {
		panic("test implementation: GetAccuTransferToGovStakerByTokenPath not supported")
	}
	return t.instance.GetAccuTransferToGovStakerByTokenPath(path)
}

func (t *TestProtocolFee) GetAccuTransferToDevOpsByTokenPath(path string) int64 {
	if !t.isActive("GetAccuTransferToDevOpsByTokenPath") {
		panic("test implementation: GetAccuTransferToDevOpsByTokenPath not supported")
	}
	return t.instance.GetAccuTransferToDevOpsByTokenPath(path)
}

func (t *TestProtocolFee) GetHistoryOfDistributedToGovStakerByTokenPath(path string) int64 {
	if !t.isActive("GetHistoryOfDistributedToGovStakerByTokenPath") {
		panic("test implementation: GetHistoryOfDistributedToGovStakerByTokenPath not supported")
	}
	return t.instance.GetHistoryOfDistributedToGovStakerByTokenPath(path)
}

func (t *TestProtocolFee) GetHistoryOfDistributedToDevOpsByTokenPath(path string) int64 {
	if !t.isActive("GetHistoryOfDistributedToDevOpsByTokenPath") {
		panic("test implementation: GetHistoryOfDistributedToDevOpsByTokenPath not supported")
	}
	return t.instance.GetHistoryOfDistributedToDevOpsByTokenPath(path)
}

// IProtocolFeeApi interface
func (t *TestProtocolFee) ApiGetAccuTransferToGovStaker() string {
	if !t.isActive("ApiGetAccuTransferToGovStaker") {
		panic("test implementation: ApiGetAccuTransferToGovStaker not supported")
	}
	return t.instance.ApiGetAccuTransferToGovStaker()
}

func (t *TestProtocolFee) ApiGetAccuTransferToDevOps() string {
	if !t.isActive("ApiGetAccuTransferToDevOps") {
		panic("test implementation: ApiGetAccuTransferToDevOps not supported")
	}
	return t.instance.ApiGetAccuTransferToDevOps()
}

func (t *TestProtocolFee) ApiGetHistoryTransferToGovStaker() string {
	if !t.isActive("ApiGetHistoryTransferToGovStaker") {
		panic("test implementation: ApiGetHistoryTransferToGovStaker not supported")
	}
	return t.instance.ApiGetHistoryTransferToGovStaker()
}

func (t *TestProtocolFee) ApiGetHistoryTransferToDevOps() string {
	if !t.isActive("ApiGetHistoryTransferToDevOps") {
		panic("test implementation: ApiGetHistoryTransferToDevOps not supported")
	}
	return t.instance.ApiGetHistoryTransferToDevOps()
}

func (t *TestProtocolFee) ApiGetActualBalance() string {
	if !t.isActive("ApiGetActualBalance") {
		panic("test implementation: ApiGetActualBalance not supported")
	}
	return t.instance.ApiGetActualBalance()
}

func (t *TestProtocolFee) ApiGetRecordedBalance() string {
	if !t.isActive("ApiGetRecordedBalance") {
		panic("test implementation: ApiGetRecordedBalance not supported")
	}
	return t.instance.ApiGetRecordedBalance()
}

func (t *TestProtocolFee) ApiGetUnrecordedBalance() string {
	if !t.isActive("ApiGetUnrecordedBalance") {
		panic("test implementation: ApiGetUnrecordedBalance not supported")
	}
	return t.instance.ApiGetUnrecordedBalance()
}
