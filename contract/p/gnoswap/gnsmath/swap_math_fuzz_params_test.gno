package gnsmath

import (
	"gno.land/p/gnoswap/fuzz"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// Parameters for SwapMathComputeSwapStep fuzzing test
type swapMathComputeSwapStepParams struct {
	sqrtRatioCurrentX96 string
	sqrtRatioTargetX96  string
	liquidity           string
	amountRemaining     string
	feePips             uint64
}

func (p *swapMathComputeSwapStepParams) IsValid() bool {
	// Check feePips range (line 38-39)
	if p.feePips > 1_000_000 {
		return false
	}

	liquidity := u256.MustFromDecimal(p.liquidity)

	// Check: Lsh overflow in getAmount0DeltaHelper/getAmount1DeltaHelper
	// Both helpers do liquidity << 96 which must not overflow
	max160 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One())
	if liquidity.Gt(max160) {
		return false
	}

	return true
}

func (p *swapMathComputeSwapStepParams) ToString() string {
	return ufmt.Sprintf(
		"sqrtRatioCurrentX96: %s, sqrtRatioTargetX96: %s, liquidity: %s, amountRemaining: %s, feePips: %d",
		p.sqrtRatioCurrentX96,
		p.sqrtRatioTargetX96,
		p.liquidity,
		p.amountRemaining,
		p.feePips,
	)
}

func NewValidSwapMathComputeSwapStepParams(t *fuzz.T) *swapMathComputeSwapStepParams {
	// Generate valid sqrt ratios within range
	sqrtCurrent := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioCurrentX96").(*u256.Uint)

	sqrtTarget := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioTargetX96").(*u256.Uint)

	// Ensure current and target are within bounds
	if sqrtCurrent.Gte(MAX_SQRT_RATIO) {
		sqrtCurrent = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}
	if sqrtTarget.Gte(MAX_SQRT_RATIO) {
		sqrtTarget = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}

	// Generate valid liquidity (can be zero or non-zero)
	liquidityVal := fuzz.Uint64Range(0, 1000000000000000000).Draw(t, "liquidity").(uint64)
	liquidity := u256.NewUint(liquidityVal)

	// Generate valid amount remaining (both positive for exact in and negative for exact out)
	isExactIn := fuzz.Bool().Draw(t, "isExactIn").(bool)
	var amountRemaining *i256.Int

	if isExactIn {
		// Positive amount for exact in
		amount := fuzz.Uint64Range(1, 1000000000000).Draw(t, "amountRemainingPositive").(uint64)
		amountRemaining = i256.FromUint256(u256.NewUint(amount))
	} else {
		// Negative amount for exact out
		amount := fuzz.Uint64Range(1, 1000000000000).Draw(t, "amountRemainingNegative").(uint64)
		amountRemaining = i256.FromUint256(u256.NewUint(amount))
		amountRemaining = amountRemaining.Neg(amountRemaining)
	}

	// Generate valid feePips (standard fee tiers or random valid value)
	// Avoid 1_000_000 (100% fee) as it causes division by zero in fee calculation
	standardFees := []uint64{100, 500, 3000, 10000}
	useStandardFee := fuzz.Bool().Draw(t, "useStandardFee").(bool)

	var feePips uint64
	if useStandardFee {
		feeIndex := fuzz.Uint64Range(0, 3).Draw(t, "feeIndex").(uint64)
		feePips = standardFees[feeIndex]
	} else {
		feePips = fuzz.Uint64Range(0, 999_999).Draw(t, "feePips").(uint64)
	}

	return &swapMathComputeSwapStepParams{
		sqrtRatioCurrentX96: sqrtCurrent.ToString(),
		sqrtRatioTargetX96:  sqrtTarget.ToString(),
		liquidity:           liquidity.ToString(),
		amountRemaining:     amountRemaining.ToString(),
		feePips:             feePips,
	}
}

func NewRandomizedSwapMathComputeSwapStepParams(t *fuzz.T) *swapMathComputeSwapStepParams {
	// Generate completely random values (may be out of range)
	sqrtCurrent := fuzz.Uint256().Draw(t, "sqrtRatioCurrentX96").(*u256.Uint)
	sqrtTarget := fuzz.Uint256().Draw(t, "sqrtRatioTargetX96").(*u256.Uint)
	liquidity := fuzz.Uint256().Draw(t, "liquidity").(*u256.Uint)
	amountRemaining := fuzz.Int256().Draw(t, "amountRemaining").(*i256.Int)

	// Generate random feePips (may exceed denominator)
	feePips := fuzz.Uint64Range(0, 2_000_000).Draw(t, "feePips").(uint64)

	return &swapMathComputeSwapStepParams{
		sqrtRatioCurrentX96: sqrtCurrent.ToString(),
		sqrtRatioTargetX96:  sqrtTarget.ToString(),
		liquidity:           liquidity.ToString(),
		amountRemaining:     amountRemaining.ToString(),
		feePips:             feePips,
	}
}
