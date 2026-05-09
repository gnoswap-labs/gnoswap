// Simplified test implementation for protocol_fee contract upgrade testing
package mock

import (
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

func (t *TestProtocolFee) AddToProtocolFee(tokenPath string, amount int64) error {
	return t.ExecuteFn(
		"AddToProtocolFee",
		func(args ...any) any { return t.instance.AddToProtocolFee(args[0].(string), args[1].(int64)) },
		tokenPath, amount,
	).(error)
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

func (t *TestProtocolFee) GetReservedTokens() []string {
	return t.ExecuteFn(
		"GetReservedTokens",
		func(args ...any) any { return t.instance.GetReservedTokens() },
	).([]string)
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

func (t *TestProtocolFee) GetActualDistributedToGovStaker() map[string]int64 {
	return t.ExecuteFn(
		"GetActualDistributedToGovStaker",
		func(args ...any) any { return t.instance.GetActualDistributedToGovStaker() },
	).(map[string]int64)
}

func (t *TestProtocolFee) GetActualDistributedToDevOps() map[string]int64 {
	return t.ExecuteFn(
		"GetActualDistributedToDevOps",
		func(args ...any) any { return t.instance.GetActualDistributedToDevOps() },
	).(map[string]int64)
}

func (t *TestProtocolFee) GetActualDistributedToGovStakerByTokenPath(path string) int64 {
	return t.ExecuteFn(
		"GetActualDistributedToGovStakerByTokenPath",
		func(args ...any) any { return t.instance.GetActualDistributedToGovStakerByTokenPath(args[0].(string)) },
		path,
	).(int64)
}

func (t *TestProtocolFee) GetActualDistributedToDevOpsByTokenPath(path string) int64 {
	return t.ExecuteFn(
		"GetActualDistributedToDevOpsByTokenPath",
		func(args ...any) any { return t.instance.GetActualDistributedToDevOpsByTokenPath(args[0].(string)) },
		path,
	).(int64)
}
