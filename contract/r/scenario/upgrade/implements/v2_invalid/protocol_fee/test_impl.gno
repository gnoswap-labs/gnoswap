// Simplified test implementation for protocol_fee contract upgrade testing
package v2_invalid

import (
	protocolFee "gno.land/r/gnoswap/protocol_fee"
)

func init() {
	protocolFee.RegisterInitializer(cross, func(store protocolFee.IProtocolFeeStore) protocolFee.IProtocolFee {
		return &TestProtocolFee{}
	})
}

// TestProtocolFee is a minimal test implementation that panics on all methods
type TestProtocolFee struct{}

// IProtocolFeeManager interface
func (t *TestProtocolFee) DistributeProtocolFee() map[string]int64 {
	panic("test implementation: DistributeProtocolFee not supported")
}

func (t *TestProtocolFee) SetDevOpsPct(pct int64) {
	panic("test implementation: SetDevOpsPct not supported")
}

func (t *TestProtocolFee) SetGovStakerPct(pct int64) {
	panic("test implementation: SetGovStakerPct not supported")
}

func (t *TestProtocolFee) AddToProtocolFee(tokenPath string, amount int64) {
	panic("test implementation: AddToProtocolFee not supported")
}

func (t *TestProtocolFee) ClearTokenListWithAmount() {
	panic("test implementation: ClearTokenListWithAmount not supported")
}

func (t *TestProtocolFee) ClearAccuTransferToGovStaker() {
	panic("test implementation: ClearAccuTransferToGovStaker not supported")
}

// IProtocolFeeGetter interface
func (t *TestProtocolFee) GetDevOpsPct() int64 {
	panic("test implementation: GetDevOpsPct not supported")
}

func (t *TestProtocolFee) GetGovStakerPct() int64 {
	panic("test implementation: GetGovStakerPct not supported")
}

func (t *TestProtocolFee) GetTokenListWithAmount() map[string]int64 {
	panic("test implementation: GetTokenListWithAmount not supported")
}

func (t *TestProtocolFee) GetAmountOfToken(tokenPath string) int64 {
	panic("test implementation: GetAmountOfToken not supported")
}

func (t *TestProtocolFee) GetAccuTransfersToGovStaker() map[string]int64 {
	panic("test implementation: GetAccuTransfersToGovStaker not supported")
}

func (t *TestProtocolFee) GetAccuTransfersToDevOps() map[string]int64 {
	panic("test implementation: GetAccuTransfersToDevOps not supported")
}

func (t *TestProtocolFee) GetAccuTransferToGovStakerByTokenPath(path string) int64 {
	panic("test implementation: GetAccuTransferToGovStakerByTokenPath not supported")
}

func (t *TestProtocolFee) GetAccuTransferToDevOpsByTokenPath(path string) int64 {
	panic("test implementation: GetAccuTransferToDevOpsByTokenPath not supported")
}

func (t *TestProtocolFee) GetHistoryOfDistributedToGovStakerByTokenPath(path string) int64 {
	panic("test implementation: GetHistoryOfDistributedToGovStakerByTokenPath not supported")
}

func (t *TestProtocolFee) GetHistoryOfDistributedToDevOpsByTokenPath(path string) int64 {
	panic("test implementation: GetHistoryOfDistributedToDevOpsByTokenPath not supported")
}

// IProtocolFeeApi interface
func (t *TestProtocolFee) ApiGetAccuTransferToGovStaker() string {
	panic("test implementation: ApiGetAccuTransferToGovStaker not supported")
}

func (t *TestProtocolFee) ApiGetAccuTransferToDevOps() string {
	panic("test implementation: ApiGetAccuTransferToDevOps not supported")
}

func (t *TestProtocolFee) ApiGetHistoryTransferToGovStaker() string {
	panic("test implementation: ApiGetHistoryTransferToGovStaker not supported")
}

func (t *TestProtocolFee) ApiGetHistoryTransferToDevOps() string {
	panic("test implementation: ApiGetHistoryTransferToDevOps not supported")
}

func (t *TestProtocolFee) ApiGetActualBalance() string {
	panic("test implementation: ApiGetActualBalance not supported")
}

func (t *TestProtocolFee) ApiGetRecordedBalance() string {
	panic("test implementation: ApiGetRecordedBalance not supported")
}

func (t *TestProtocolFee) ApiGetUnrecordedBalance() string {
	panic("test implementation: ApiGetUnrecordedBalance not supported")
}
