package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"
)

var (
	gsa  = testutils.TestAddress("gsa")
	lp01 = testutils.TestAddress("lp01")

	poolAddr = std.DerivePkgAddr("gno.land/r/pool")
	posAddr  = std.DerivePkgAddr("gno.land/r/position")
)

var (
	fooPath          = "gno.land/r/foo" // token1
	barPath          = "gno.land/r/bar" // token2
	pFee             = uint16(500)
	sqrtPrice bigint = 130621891405341611593710811006

	tickLower       = int32(9000)
	tickUpper       = int32(11000)
	liquidityExpect = bigint(100_000_000)

	currentTick = int32(10000)
)

func init() {
	std.TestSetOrigCaller(gsa)
	InitManual()
	CreatePool(fooPath, barPath, pFee, sqrtPrice)
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
	std.TestSetPrevRealm("gno.land/r/position")
	std.TestSetOrigCaller(lp01)

	// no mint == no liquidity => swap will fail
	_, _, ok := DrySwap(fooPath, barPath, pFee, "_", true, 16000, MIN_PRICE)
	shouldEQ(t, ok, false)

	// not enough mint == swap will fail
	Mint(fooPath, barPath, pFee, posAddr, tickLower, tickUpper, 1000)
	_, _, ok = DrySwap(fooPath, barPath, pFee, "_", true, 16000, MIN_PRICE)
	shouldEQ(t, ok, false)

	Mint(fooPath, barPath, pFee, posAddr, tickLower, tickUpper, liquidityExpect)

	// zeroForOne true
	// amountSpecified 16000
	input, output, _ := DrySwap(
		fooPath,   // fooPath
		barPath,   // barPath
		pFee,      // pFee
		"_",       // recipient
		true,      // zeroForOne
		16000,     // amountSpecified
		MIN_PRICE, // sqrtPriceLimitX96
	)
	shouldEQ(t, input, bigint(16000))
	shouldEQ(t, output, bigint(-43457))
}

func TestDrySwap_ZeroForOneTrue_AmountSpecified_Negative_16000(t *testing.T) {
	// zeroForOne true
	// amountSpecified -16000

	input, output, _ := DrySwap(
		fooPath,          // fooPath
		barPath,          // barPath
		pFee,             // pFee
		"_",              // recipient
		true,             // zeroForOne
		-16000,           // amountSpecified
		MIN_SQRT_RATIO+1, // sqrtPriceLimitX96
	)

	shouldEQ(t, input, bigint(5888))
	shouldEQ(t, output, bigint(-16000))
}

func TestDrySwap_ZeroForOneFalse_AmountSpecified_Positive_16000(t *testing.T) {
	// zeroForOne false
	// amountSpecified 16000

	input, output, _ := DrySwap(
		fooPath,          // fooPath
		barPath,          // barPath
		pFee,             // pFee
		"_",              // recipient
		false,            // zeroForOne
		16000,            // amountSpecified
		MAX_SQRT_RATIO-1, // sqrtPriceLimitX96
	)
	shouldEQ(t, input, bigint(-43457))
	shouldEQ(t, output, bigint(16000))
}

func TestDrySwap_ZeroForOneFalse_AmountSpecified_Negative_16000(t *testing.T) {
	// zeroForOne false
	// amountSpecified -16000

	input, output, _ := DrySwap(
		fooPath,          // fooPath
		barPath,          // barPath
		pFee,             // pFee
		"_",              // recipient
		false,            // zeroForOne
		-16000,           // amountSpecified
		MAX_SQRT_RATIO-1, // sqrtPriceLimitX96
	)
	shouldEQ(t, input, bigint(-16000))
	shouldEQ(t, output, bigint(5888))
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
