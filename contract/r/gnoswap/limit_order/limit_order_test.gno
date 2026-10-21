package limit_order

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256/v1"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestMinimumUserOutputRoundsFractionUp(t *testing.T) {
	order := newModelTestOrder(3, 2, 0)

	minimum := order.MinimumUserOutput(u256.NewUint(1))

	uassert.Equal(t, minimum.ToString(), "1")
	uassert.Equal(t, order.GetMinimumOutput(u256.NewUint(1)).ToString(), "1")
}

func TestCumulativeExecutionFeeAcrossSplitFills(t *testing.T) {
	order := newModelTestOrder(20, 1, 0)

	order.ApplyFill(u256.NewUint(10), u256.NewUint(100))
	uassert.Equal(t, order.ExecutionFee().Uint64(), uint64(0))
	order.ApplyFill(u256.NewUint(10), u256.NewUint(100))

	uassert.Equal(t, order.FilledInput().Uint64(), uint64(20))
	uassert.Equal(t, order.GrossOutput().Uint64(), uint64(200))
	uassert.Equal(t, order.ExecutionFee().Uint64(), uint64(1))
	uassert.Equal(t, uint8(order.Status()), uint8(OrderStatusExecuted))
}

func TestGetMinimumOutputIncludesIncrementalFee(t *testing.T) {
	order := newModelTestOrder(1000, 1000, 100)
	fillInput := u256.NewUint(500)
	minimumUserOutput := order.MinimumUserOutput(fillInput)
	uassert.Equal(t, minimumUserOutput.ToString(), "495")

	firstMinimum := order.GetMinimumOutput(fillInput)
	uassert.Equal(t, firstMinimum.ToString(), "497")
	order.ApplyFill(fillInput, firstMinimum)
	firstFee := order.ExecutionFee().Uint64()
	uassert.Equal(t, uint64(firstMinimum.Uint64())-firstFee, uint64(495))

	secondMinimum := order.GetMinimumOutput(fillInput)
	uassert.Equal(t, secondMinimum.ToString(), "497")
	feeBefore := order.ExecutionFee().Uint64()
	order.ApplyFill(fillInput, secondMinimum)
	incrementalFee := order.ExecutionFee().Uint64() - feeBefore
	uassert.Equal(t, uint64(secondMinimum.Uint64())-incrementalFee, uint64(495))
	uassert.Equal(t, order.GrossOutput().Uint64(), uint64(994))
	uassert.Equal(t, order.ExecutionFee().Uint64(), uint64(4))
}

func TestRejectedFillLeavesAccountingUnchanged(t *testing.T) {
	order := newModelTestOrder(1000, 1000, 0)
	order.ApplyFill(u256.NewUint(500), u256.NewUint(503))

	filledBefore := order.FilledInput().Uint64()
	remainingBefore := order.RemainingInput().Uint64()
	grossBefore := order.GrossOutput().Uint64()
	feeBefore := order.ExecutionFee().Uint64()
	statusBefore := order.Status()

	assertModelPanic(t, ErrSlippageExceeded, func() {
		order.ApplyFill(u256.NewUint(500), u256.NewUint(500))
	})

	uassert.Equal(t, order.FilledInput().Uint64(), filledBefore)
	uassert.Equal(t, order.RemainingInput().Uint64(), remainingBefore)
	uassert.Equal(t, order.GrossOutput().Uint64(), grossBefore)
	uassert.Equal(t, order.ExecutionFee().Uint64(), feeBefore)
	uassert.Equal(t, uint8(order.Status()), uint8(statusBefore))
}

func TestCumulativeOutputOverflowLeavesAccountingUnchanged(t *testing.T) {
	order := newModelTestOrder(2, 1, 0)
	order.ApplyFill(u256.NewUint(1), u256.NewUint(MAX_TOKEN_AMOUNT))

	filledBefore := order.FilledInput().Uint64()
	grossBefore := order.GrossOutput().Uint64()
	feeBefore := order.ExecutionFee().Uint64()
	statusBefore := order.Status()

	assertModelPanic(t, ErrAmountOverflow, func() {
		order.ApplyFill(u256.NewUint(1), u256.NewUint(1))
	})

	uassert.Equal(t, order.FilledInput().Uint64(), filledBefore)
	uassert.Equal(t, order.GrossOutput().Uint64(), grossBefore)
	uassert.Equal(t, order.ExecutionFee().Uint64(), feeBefore)
	uassert.Equal(t, uint8(order.Status()), uint8(statusBefore))
}

func newModelTestOrder(making, taking, slippage uint64) *LimitOrder {
	return NewLimitOrder(
		1,
		"g1owner",
		"gno.land/r/token0:gno.land/r/token1:500",
		"gno.land/r/token0",
		"gno.land/r/token1",
		u256.NewUint(making),
		u256.NewUint(taking),
		slippage,
		"g1devops",
		time.Now().Unix()+3600,
	)
}

func assertModelPanic(t *testing.T, expected error, run func()) {
	var caught any
	func() {
		defer func() {
			caught = recover()
		}()
		run()
	}()
	if caught == nil {
		t.Fatal("expected model operation to panic")
		return
	}
	err, ok := caught.(error)
	if !ok {
		t.Fatalf("unexpected panic type: %v", caught)
		return
	}
	uassert.Equal(t, expected.Error(), err.Error())
}
