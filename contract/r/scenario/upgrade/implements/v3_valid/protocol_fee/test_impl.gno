// Simplified test implementation for protocol_fee contract upgrade testing
package v3_valid

import (
	protocolFee "gno.land/r/gnoswap/protocol_fee"
	v1 "gno.land/r/gnoswap/protocol_fee/v1"
)

func NewV3ValidProtocolFee(store protocolFee.IProtocolFeeStore) protocolFee.IProtocolFee {
	return &TestProtocolFee{
		instance: v1.NewProtocolFeeV1(store),
	}
}

func init() {
	protocolFee.RegisterInitializer(cross, func(store protocolFee.IProtocolFeeStore) protocolFee.IProtocolFee {
		return NewV3ValidProtocolFee(store)
	})
}

// TestProtocolFee is a minimal test implementation that delegates to v1
type TestProtocolFee struct {
	instance protocolFee.IProtocolFee
}

// IProtocolFeeManager interface
func (t *TestProtocolFee) DistributeProtocolFee() map[string]int64 {
	return t.instance.DistributeProtocolFee()
}

func (t *TestProtocolFee) SetDevOpsPct(pct int64) {
	t.instance.SetDevOpsPct(pct)
}

func (t *TestProtocolFee) SetGovStakerPct(pct int64) {
	t.instance.SetGovStakerPct(pct)
}

func (t *TestProtocolFee) AddToProtocolFee(tokenPath string, amount int64) {
	t.instance.AddToProtocolFee(tokenPath, amount)
}

func (t *TestProtocolFee) ClearTokenListWithAmount() {
	t.instance.ClearTokenListWithAmount()
}

func (t *TestProtocolFee) ClearAccuTransferToGovStaker() {
	t.instance.ClearAccuTransferToGovStaker()
}

// IProtocolFeeGetter interface
func (t *TestProtocolFee) GetDevOpsPct() int64 {
	return t.instance.GetDevOpsPct()
}

func (t *TestProtocolFee) GetGovStakerPct() int64 {
	return t.instance.GetGovStakerPct()
}

func (t *TestProtocolFee) GetTokenListWithAmount() map[string]int64 {
	return t.instance.GetTokenListWithAmount()
}

func (t *TestProtocolFee) GetAmountOfToken(tokenPath string) int64 {
	return t.instance.GetAmountOfToken(tokenPath)
}

func (t *TestProtocolFee) GetAccuTransfersToGovStaker() map[string]int64 {
	return t.instance.GetAccuTransfersToGovStaker()
}

func (t *TestProtocolFee) GetAccuTransfersToDevOps() map[string]int64 {
	return t.instance.GetAccuTransfersToDevOps()
}

func (t *TestProtocolFee) GetTotalAccuTransfersToGovStaker() int64 {
	return t.instance.GetTotalAccuTransfersToGovStaker()
}

func (t *TestProtocolFee) GetTotalAccuTransfersToDevOps() int64 {
	return t.instance.GetTotalAccuTransfersToDevOps()
}

func (t *TestProtocolFee) GetTokenList() []string {
	return t.instance.GetTokenList()
}

func (t *TestProtocolFee) GetAccuTransferToGovStakerByTokenPath(path string) int64 {
	return t.instance.GetAccuTransferToGovStakerByTokenPath(path)
}

func (t *TestProtocolFee) GetAccuTransferToDevOpsByTokenPath(path string) int64 {
	return t.instance.GetAccuTransferToDevOpsByTokenPath(path)
}

func (t *TestProtocolFee) GetHistoryOfDistributedToGovStakerByTokenPath(path string) int64 {
	return t.instance.GetHistoryOfDistributedToGovStakerByTokenPath(path)
}

func (t *TestProtocolFee) GetHistoryOfDistributedToDevOpsByTokenPath(path string) int64 {
	return t.instance.GetHistoryOfDistributedToDevOpsByTokenPath(path)
}
