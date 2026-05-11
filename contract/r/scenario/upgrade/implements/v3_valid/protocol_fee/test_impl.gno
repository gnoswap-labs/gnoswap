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
func (t *TestProtocolFee) DistributeProtocolFee() {
	t.instance.DistributeProtocolFee()
}

func (t *TestProtocolFee) SetDevOpsPct(pct int64) {
	t.instance.SetDevOpsPct(pct)
}

func (t *TestProtocolFee) SetGovStakerPct(pct int64) {
	t.instance.SetGovStakerPct(pct)
}

func (t *TestProtocolFee) AddToProtocolFee(tokenPath string, amount int64) error {
	return t.instance.AddToProtocolFee(tokenPath, amount)
}

// IProtocolFeeGetter interface
func (t *TestProtocolFee) GetDevOpsPct() int64 {
	return t.instance.GetDevOpsPct()
}

func (t *TestProtocolFee) GetGovStakerPct() int64 {
	return t.instance.GetGovStakerPct()
}

func (t *TestProtocolFee) GetReservedTokens() []string {
	return t.instance.GetReservedTokens()
}

func (t *TestProtocolFee) GetAccuTransfersToGovStaker() map[string]int64 {
	return t.instance.GetAccuTransfersToGovStaker()
}

func (t *TestProtocolFee) GetAccuTransfersToDevOps() map[string]int64 {
	return t.instance.GetAccuTransfersToDevOps()
}

func (t *TestProtocolFee) GetAccuTransferToGovStakerByTokenPath(path string) int64 {
	return t.instance.GetAccuTransferToGovStakerByTokenPath(path)
}

func (t *TestProtocolFee) GetAccuTransferToDevOpsByTokenPath(path string) int64 {
	return t.instance.GetAccuTransferToDevOpsByTokenPath(path)
}

func (t *TestProtocolFee) GetActualDistributedToGovStaker() map[string]int64 {
	return t.instance.GetActualDistributedToGovStaker()
}

func (t *TestProtocolFee) GetActualDistributedToDevOps() map[string]int64 {
	return t.instance.GetActualDistributedToDevOps()
}

func (t *TestProtocolFee) GetActualDistributedToGovStakerByTokenPath(path string) int64 {
	return t.instance.GetActualDistributedToGovStakerByTokenPath(path)
}

func (t *TestProtocolFee) GetActualDistributedToDevOpsByTokenPath(path string) int64 {
	return t.instance.GetActualDistributedToDevOpsByTokenPath(path)
}
