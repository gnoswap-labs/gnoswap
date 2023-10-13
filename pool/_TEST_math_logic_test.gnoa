package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	pos "gno.land/r/position"
)

var (
	gsa  = testutils.TestAddress("gsa")
	lp01 = testutils.TestAddress("lp01")

	pToken0          = "foo"
	pToken1          = "bar"
	pFee      uint16 = 500
	sqrtPrice bigint = 130621891405341611593710811006

	tickLower       int32  = 9000
	tickUpper       int32  = 11000
	liquidityAmount bigint = 123456789
	currentTick     int32  = 10000
)

func init() {
	std.TestSetOrigCaller(gsa)
	InitManual()
	CreatePool(pToken0, pToken1, pFee, sqrtPrice)
}

func TestGetSqrtRatioFromTick(t *testing.T) {
	sqrtX96 := GetSqrtRatioFromTick(currentTick)
	shouldEQ(t, sqrtX96, sqrtPrice)
}

func TestGetTickFromSqrtRatio(t *testing.T) {
	tick := GetTickFromSqrtRatio(sqrtPrice)
	shouldEQ(t, tick, 9999) // currentTick - 1
}

func TestDrySwap_ZeroForOneTrue_AmountSpecified_Positive_16000(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// no mint == no liquidity => swap will fail
	shouldPanic(t, func() { DrySwap(pToken0, pToken1, pFee, "_", true, 16000, MIN_PRICE) })

	// not enough mint == swap will fail
	pos.Mint(pToken0, pToken1, pFee, tickLower, tickUpper, 1000, 1000, 0, 0, 9999999999)
	shouldPanic(t, func() { DrySwap(pToken0, pToken1, pFee, "_", true, 16000, MIN_PRICE) })

	pos.Mint(pToken0, pToken1, pFee, tickLower, tickUpper, 100000, 100000, 0, 0, 9999999999)

	// zeroForOne true
	// amountSpecified 16000
	input, output := DrySwap(
		pToken0,   // pToken0
		pToken1,   // pToken1
		pFee,      // pFee
		"_",       // recipient
		true,      // zeroForOne
		16000,     // amountSpecified
		MIN_PRICE, // sqrtPriceLimitX96
	)
	shouldEQ(t, input, bigint(16000))
	shouldEQ(t, output, bigint(-42574))
}

func TestDrySwap_ZeroForOneTrue_AmountSpecified_Negative_16000(t *testing.T) {
	// zeroForOne true
	// amountSpecified -16000

	input, output := DrySwap(
		pToken0,          // pToken0
		pToken1,          // pToken1
		pFee,             // pFee
		"_",              // recipient
		true,             // zeroForOne
		-16000,           // amountSpecified
		MIN_SQRT_RATIO+1, // sqrtPriceLimitX96
	)

	shouldEQ(t, input, bigint(5934))
	shouldEQ(t, output, bigint(-15999))
}

func TestDrySwap_ZeroForOneFalse_AmountSpecified_Positive_16000(t *testing.T) {
	// zeroForOne false
	// amountSpecified 16000

	input, output := DrySwap(
		pToken0,          // pToken0
		pToken1,          // pToken1
		pFee,             // pFee
		"_",              // recipient
		false,            // zeroForOne
		16000,            // amountSpecified
		MAX_SQRT_RATIO-1, // sqrtPriceLimitX96
	)
	shouldEQ(t, input, bigint(-42574))
	shouldEQ(t, output, bigint(16000))
}

func TestDrySwap_ZeroForOneFalse_AmountSpecified_Negative_16000(t *testing.T) {
	// zeroForOne false
	// amountSpecified -16000

	input, output := DrySwap(
		pToken0,          // pToken0
		pToken1,          // pToken1
		pFee,             // pFee
		"_",              // recipient
		false,            // zeroForOne
		-16000,           // amountSpecified
		MAX_SQRT_RATIO-1, // sqrtPriceLimitX96
	)
	shouldEQ(t, input, bigint(-15999))
	shouldEQ(t, output, bigint(5934))
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}
