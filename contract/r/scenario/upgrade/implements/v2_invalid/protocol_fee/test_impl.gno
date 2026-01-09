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

func (t *TestProtocolFee) GetTokenList() []string {
	if !t.isActive("GetTokenList") {
		panic("test implementation: GetTokenList not supported")
	}
	return t.instance.GetTokenList()
}
