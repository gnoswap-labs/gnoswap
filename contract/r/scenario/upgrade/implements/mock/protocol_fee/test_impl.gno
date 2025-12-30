// Simplified test implementation for protocol_fee contract upgrade testing
package mock

import (
	"gno.land/p/nt/avl/rotree"
	protocolFee "gno.land/r/gnoswap/protocol_fee"
	"gno.land/r/gnoswap/protocol_fee/v1"
)

func NewV3ValidProtocolFee(store protocolFee.IProtocolFeeStore) protocolFee.IProtocolFee {
	instance := v1.NewProtocolFeeV1(store)

	return &TestProtocolFee{
		instance: instance,
		mockFns:  make(map[string]func(args ...any) any),
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
	mockFns  map[string]func(args ...any) any
}

func (t *TestProtocolFee) SetMockFn(fnName string, fn func(args ...any) any) {
	t.mockFns[fnName] = fn
}

func (t *TestProtocolFee) ExecuteFn(fnName string, actualFn func(args ...any) any, args ...any) any {
	fn, ok := t.mockFns[fnName]
	if !ok {
		return actualFn(args...)
	}

	return fn(args...)
}

// IProtocolFeeManager interface
func (t *TestProtocolFee) DistributeProtocolFee() map[string]int64 {
	return t.ExecuteFn(
		"DistributeProtocolFee",
		func(args ...any) any { return t.instance.DistributeProtocolFee() },
	).(map[string]int64)
}

func (t *TestProtocolFee) SetDevOpsPct(pct int64) {
	t.ExecuteFn(
		"SetDevOpsPct",
		func(args ...any) any { t.instance.SetDevOpsPct(args[0].(int64)); return nil },
		pct,
	)
}

func (t *TestProtocolFee) SetGovStakerPct(pct int64) {
	t.ExecuteFn(
		"SetGovStakerPct",
		func(args ...any) any { t.instance.SetGovStakerPct(args[0].(int64)); return nil },
		pct,
	)
}

func (t *TestProtocolFee) AddToProtocolFee(tokenPath string, amount int64) {
	t.ExecuteFn(
		"AddToProtocolFee",
		func(args ...any) any { t.instance.AddToProtocolFee(args[0].(string), args[1].(int64)); return nil },
		tokenPath, amount,
	)
}

func (t *TestProtocolFee) ClearTokenListWithAmount() {
	t.ExecuteFn(
		"ClearTokenListWithAmount",
		func(args ...any) any { t.instance.ClearTokenListWithAmount(); return nil },
	)
}

func (t *TestProtocolFee) ClearAccuTransferToGovStaker() {
	t.ExecuteFn(
		"ClearAccuTransferToGovStaker",
		func(args ...any) any { t.instance.ClearAccuTransferToGovStaker(); return nil },
	)
}

// IProtocolFeeGetter interface
func (t *TestProtocolFee) GetDevOpsPct() int64 {
	return t.ExecuteFn(
		"GetDevOpsPct",
		func(args ...any) any { return t.instance.GetDevOpsPct() },
	).(int64)
}

func (t *TestProtocolFee) GetGovStakerPct() int64 {
	return t.ExecuteFn(
		"GetGovStakerPct",
		func(args ...any) any { return t.instance.GetGovStakerPct() },
	).(int64)
}

func (t *TestProtocolFee) GetTokenListWithAmount() *rotree.ReadOnlyTree {
	return t.ExecuteFn(
		"GetTokenListWithAmount",
		func(args ...any) any { return t.instance.GetTokenListWithAmount() },
	).(*rotree.ReadOnlyTree)
}

func (t *TestProtocolFee) GetAmountOfToken(tokenPath string) int64 {
	return t.ExecuteFn(
		"GetAmountOfToken",
		func(args ...any) any { return t.instance.GetAmountOfToken(args[0].(string)) },
		tokenPath,
	).(int64)
}

func (t *TestProtocolFee) GetAccuTransfersToGovStaker() map[string]int64 {
	return t.ExecuteFn(
		"GetAccuTransfersToGovStaker",
		func(args ...any) any { return t.instance.GetAccuTransfersToGovStaker() },
	).(map[string]int64)
}

func (t *TestProtocolFee) GetAccuTransfersToDevOps() map[string]int64 {
	return t.ExecuteFn(
		"GetAccuTransfersToDevOps",
		func(args ...any) any { return t.instance.GetAccuTransfersToDevOps() },
	).(map[string]int64)
}

func (t *TestProtocolFee) GetAccuTransferToGovStakerByTokenPath(path string) int64 {
	return t.ExecuteFn(
		"GetAccuTransferToGovStakerByTokenPath",
		func(args ...any) any { return t.instance.GetAccuTransferToGovStakerByTokenPath(args[0].(string)) },
		path,
	).(int64)
}

func (t *TestProtocolFee) GetAccuTransferToDevOpsByTokenPath(path string) int64 {
	return t.ExecuteFn(
		"GetAccuTransferToDevOpsByTokenPath",
		func(args ...any) any { return t.instance.GetAccuTransferToDevOpsByTokenPath(args[0].(string)) },
		path,
	).(int64)
}

func (t *TestProtocolFee) GetHistoryOfDistributedToGovStakerByTokenPath(path string) int64 {
	return t.ExecuteFn(
		"GetHistoryOfDistributedToGovStakerByTokenPath",
		func(args ...any) any {
			return t.instance.GetHistoryOfDistributedToGovStakerByTokenPath(args[0].(string))
		},
		path,
	).(int64)
}

func (t *TestProtocolFee) GetHistoryOfDistributedToDevOpsByTokenPath(path string) int64 {
	return t.ExecuteFn(
		"GetHistoryOfDistributedToDevOpsByTokenPath",
		func(args ...any) any { return t.instance.GetHistoryOfDistributedToDevOpsByTokenPath(args[0].(string)) },
		path,
	).(int64)
}

// IProtocolFeeApi interface
func (t *TestProtocolFee) ApiGetAccuTransferToGovStaker() string {
	return t.ExecuteFn(
		"ApiGetAccuTransferToGovStaker",
		func(args ...any) any { return t.instance.ApiGetAccuTransferToGovStaker() },
	).(string)
}

func (t *TestProtocolFee) ApiGetAccuTransferToDevOps() string {
	return t.ExecuteFn(
		"ApiGetAccuTransferToDevOps",
		func(args ...any) any { return t.instance.ApiGetAccuTransferToDevOps() },
	).(string)
}

func (t *TestProtocolFee) ApiGetHistoryTransferToGovStaker() string {
	return t.ExecuteFn(
		"ApiGetHistoryTransferToGovStaker",
		func(args ...any) any { return t.instance.ApiGetHistoryTransferToGovStaker() },
	).(string)
}

func (t *TestProtocolFee) ApiGetHistoryTransferToDevOps() string {
	return t.ExecuteFn(
		"ApiGetHistoryTransferToDevOps",
		func(args ...any) any { return t.instance.ApiGetHistoryTransferToDevOps() },
	).(string)
}

func (t *TestProtocolFee) ApiGetActualBalance() string {
	return t.ExecuteFn(
		"ApiGetActualBalance",
		func(args ...any) any { return t.instance.ApiGetActualBalance() },
	).(string)
}

func (t *TestProtocolFee) ApiGetRecordedBalance() string {
	return t.ExecuteFn(
		"ApiGetRecordedBalance",
		func(args ...any) any { return t.instance.ApiGetRecordedBalance() },
	).(string)
}

func (t *TestProtocolFee) ApiGetUnrecordedBalance() string {
	return t.ExecuteFn(
		"ApiGetUnrecordedBalance",
		func(args ...any) any { return t.instance.ApiGetUnrecordedBalance() },
	).(string)
}
