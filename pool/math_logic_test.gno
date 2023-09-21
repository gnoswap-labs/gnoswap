package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
)

var (
	gsa = testutils.TestAddress("gsa")

	pToken0 = "foo"
	pToken1 = "bar"
	pFee    = uint16(500)

	tickLower = int32(9000)
	tickUpper = int32(11000)

	liquidityAmount = bigint(123456789)

	currentTick = int32(10000)

	sqrtPrice bigint = 130621891405341611593710811006
)

func init() {
	std.TestSetOrigCaller(gsa)
	InitManual()
	CreatePool("foo", "bar", pFee, sqrtPrice)
}

func TestGetAmountsFromLiquidity(t *testing.T) {
	amount0, amount1 := getAmountsFromLiquidity(pToken0, pToken1, pFee, tickLower, tickUpper, liquidityAmount, currentTick)
	shouldEQ(t, amount0, bigint(3651869))
	shouldEQ(t, amount1, bigint(9926315))
}

func TestGetSqrtRatioFromTick(t *testing.T) {
	sqrtX96 := getSqrtRatioFromTick(currentTick) // tick 10000
	shouldEQ(t, sqrtX96, sqrtPrice)              // 130621891405341611593710811006
}

func TestGetTickFromSqrtRatio(t *testing.T) {
	tick := getTickFromSqrtRatio(sqrtPrice)
	shouldEQ(t, tick, 9999) // currentTick - 1
}

func TestSwapAmountZ_ZeroForOneTrue_AmountSpecified_Positive_16000(t *testing.T) {
	// zeroForOne true
	// amountSpecified 16000

	input, output := swapAmount(
		pToken0,          // pToken0
		pToken1,          // pToken1
		pFee,             // pFee
		"_",              // recipient
		true,             // zeroForOne
		16000,            // amountSpecified
		MIN_SQRT_RATIO+1, // sqrtPriceLimitX96
	)
	shouldEQ(t, input, bigint(16000))
	shouldEQ(t, output, bigint(-43459))
}

func TestSwapAmountZ_ZeroForOneTrue_AmountSpecified_Negative_16000(t *testing.T) {
	// zeroForOne true
	// amountSpecified -16000

	input, output := swapAmount(
		pToken0,          // pToken0
		pToken1,          // pToken1
		pFee,             // pFee
		"_",              // recipient
		true,             // zeroForOne
		-16000,           // amountSpecified
		MIN_SQRT_RATIO+1, // sqrtPriceLimitX96
	)

	shouldEQ(t, input, bigint(5888))
	shouldEQ(t, output, bigint(-15999))
}

func TestSwapAmountZ_ZeroForOneFalse_AmountSpecified_Positive_16000(t *testing.T) {
	// zeroForOne false
	// amountSpecified 16000

	input, output := swapAmount(
		pToken0,          // pToken0
		pToken1,          // pToken1
		pFee,             // pFee
		"_",              // recipient
		false,            // zeroForOne
		16000,            // amountSpecified
		MAX_SQRT_RATIO-1, // sqrtPriceLimitX96
	)
	shouldEQ(t, input, bigint(-43459))
	shouldEQ(t, output, bigint(16000))
}

func TestSwapAmountZ_ZeroForOneFalse_AmountSpecified_Negative_16000(t *testing.T) {
	// zeroForOne false
	// amountSpecified -16000

	input, output := swapAmount(
		pToken0,          // pToken0
		pToken1,          // pToken1
		pFee,             // pFee
		"_",              // recipient
		false,            // zeroForOne
		-16000,           // amountSpecified
		MAX_SQRT_RATIO-1, // sqrtPriceLimitX96
	)
	shouldEQ(t, input, bigint(-15999))
	shouldEQ(t, output, bigint(5888))
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, didn't expected %v", got, expected)
	}
}
