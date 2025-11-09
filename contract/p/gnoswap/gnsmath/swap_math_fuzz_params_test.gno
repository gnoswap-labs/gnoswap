package gnsmath

import (
	"math"

	"gno.land/p/gnoswap/fuzz"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

var (
	MAX_UINT128 = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 128), u256.One())
	MAX_INT190  = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 190), u256.One())
	MIN_INT190  = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 190), u256.One())
)

// Parameters for SwapMathComputeSwapStep fuzzing test
type swapMathComputeSwapStepParams struct {
	sqrtRatioCurrentX96 *u256.Uint
	sqrtRatioTargetX96  *u256.Uint
	liquidity           *u256.Uint
	amountRemaining     *i256.Int
	feePips             uint64
}

func (p *swapMathComputeSwapStepParams) IsValid() bool {
	if p.sqrtRatioCurrentX96 == nil ||
		p.sqrtRatioTargetX96 == nil ||
		p.liquidity == nil ||
		p.amountRemaining == nil ||
		p.feePips == 0 {
		return false
	}

	if p.sqrtRatioCurrentX96.IsZero() || p.sqrtRatioTargetX96.IsZero() || p.liquidity.IsZero() {
		return false
	}

	if p.feePips >= 1_000_000 {
		return false
	}

	return true
}

func (p *swapMathComputeSwapStepParams) ToString() string {
	return ufmt.Sprintf(
		"sqrtRatioCurrentX96: %s, sqrtRatioTargetX96: %s, liquidity: %s, amountRemaining: %s, feePips: %d",
		p.sqrtRatioCurrentX96.ToString(),
		p.sqrtRatioTargetX96.ToString(),
		p.liquidity.ToString(),
		p.amountRemaining.ToString(),
		p.feePips,
	)
}

func NewValidSwapMathComputeSwapStepParams(t *fuzz.T) *swapMathComputeSwapStepParams {
	sqrtCurrent := fuzz.Uint256Range(MIN_SQRT_RATIO.ToString(), MAX_SQRT_RATIO.ToString()).Draw(t, "sqrtRatioCurrentX96").(*u256.Uint)
	sqrtTarget := fuzz.Uint256Range(MIN_SQRT_RATIO.ToString(), MAX_SQRT_RATIO.ToString()).Draw(t, "sqrtRatioTargetX96").(*u256.Uint)
	liquidity := fuzz.Uint256Range("1", MAX_UINT128.ToString()).Draw(t, "liquidity").(*u256.Uint)

	feePips := fuzz.Uint64Range(1, 999_999).Draw(t, "feePips").(uint64)

	amountRemainingInt64 := fuzz.Int64Range(math.MinInt64, math.MaxInt64).Draw(t, "amountRemaining").(int64)
	amountRemaining := i256.NewInt(amountRemainingInt64)

	return &swapMathComputeSwapStepParams{
		sqrtRatioCurrentX96: sqrtCurrent,
		sqrtRatioTargetX96:  sqrtTarget,
		liquidity:           liquidity,
		amountRemaining:     amountRemaining,
		feePips:             feePips,
	}
}

func NewRandomizedSwapMathComputeSwapStepParams(t *fuzz.T) *swapMathComputeSwapStepParams {
	maxUint256 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 256), u256.One())

	sqrtCurrent := fuzz.Uint256Range("0", maxUint256.ToString()).Draw(t, "sqrtRatioCurrentX96").(*u256.Uint)
	sqrtTarget := fuzz.Uint256Range("0", maxUint256.ToString()).Draw(t, "sqrtRatioTargetX96").(*u256.Uint)
	liquidity := fuzz.Uint256Range("0", maxUint256.ToString()).Draw(t, "liquidity").(*u256.Uint)

	feePips := fuzz.Uint64Range(0, math.MaxUint64).Draw(t, "feePips").(uint64)

	amountRemainingInt64 := fuzz.Int64Range(math.MinInt64, math.MaxInt64).Draw(t, "amountRemaining").(int64)
	amountRemaining := i256.NewInt(amountRemainingInt64)

	return &swapMathComputeSwapStepParams{
		sqrtRatioCurrentX96: sqrtCurrent,
		sqrtRatioTargetX96:  sqrtTarget,
		liquidity:           liquidity,
		amountRemaining:     amountRemaining,
		feePips:             feePips,
	}
}
