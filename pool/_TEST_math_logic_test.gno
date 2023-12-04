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
	pc01 = testutils.TestAddress("pc01")

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
	liquidityExpect = bigint(100_000_000_000)

	currentTick = int32(10000)
)

func init() {
	std.TestSetOrigCaller(gsa)
	InitManual()

	std.TestSetOrigCaller(pc01)
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
	Mint(fooPath, barPath, pFee, posAddr, -tickUpper, -tickLower, 1000)
	_, _, ok = DrySwap(fooPath, barPath, pFee, "_", true, 16000, MIN_PRICE)
	shouldEQ(t, ok, false)

	Mint(fooPath, barPath, pFee, posAddr, -tickUpper, -tickLower, liquidityExpect) // -11000  ~ -9000

	// zeroForOne true
	// amountSpecified 16000
	poolIn, poolOut, _ := DrySwap(
		fooPath,   // fooPath
		barPath,   // barPath
		pFee,      // pFee
		"_",       // recipient
		true,      // zeroForOne
		16000,     // amountSpecified
		MIN_PRICE, // sqrtPriceLimitX96
	)
	shouldEQ(t, poolIn, bigint(16000))
	shouldEQ(t, poolOut, bigint(-5884))
}

func TestDrySwap_ZeroForOneTrue_AmountSpecified_Negative_16000(t *testing.T) {
	// zeroForOne true
	// amountSpecified -16000

	poolIn, poolOut, _ := DrySwap(
		fooPath,   // fooPath
		barPath,   // barPath
		pFee,      // pFee
		"_",       // recipient
		true,      // zeroForOne
		-16000,    // amountSpecified
		MIN_PRICE, // sqrtPriceLimitX96
	)

	shouldEQ(t, poolIn, bigint(43506))
	shouldEQ(t, poolOut, bigint(-15999))
}

func TestDrySwap_ZeroForOneFalse_AmountSpecified_Positive_16000(t *testing.T) {
	// zeroForOne false
	// amountSpecified 16000

	poolOut, poolIn, _ := DrySwap(
		fooPath,   // fooPath
		barPath,   // barPath
		pFee,      // pFee
		"_",       // recipient
		false,     // zeroForOne
		16000,     // amountSpecified
		MAX_PRICE, // sqrtPriceLimitX96
	)

	shouldEQ(t, poolOut, bigint(-43464))
	shouldEQ(t, poolIn, bigint(16000))
}

func TestDrySwap_ZeroForOneFalse_AmountSpecified_Negative_16000(t *testing.T) {
	// zeroForOne false
	// amountSpecified -16000
	poolOut, poolIn, _ := DrySwap(
		fooPath,   // fooPath
		barPath,   // barPath
		pFee,      // pFee
		"_",       // recipient
		false,     // zeroForOne
		-16000,    // amountSpecified
		MAX_PRICE, // sqrtPriceLimitX96
	)
	shouldEQ(t, poolOut, bigint(-15999))
	shouldEQ(t, poolIn, bigint(5888))
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
