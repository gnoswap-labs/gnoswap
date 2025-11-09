package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// Parameters for TickMathGetSqrtRatioAtTick fuzzing test
type tickMathGetSqrtRatioAtTickParams struct {
	tick int32
}

func (p *tickMathGetSqrtRatioAtTickParams) IsValid() bool {
	return p.tick >= MIN_TICK && p.tick <= MAX_TICK
}

func (p *tickMathGetSqrtRatioAtTickParams) ToString() string {
	return ufmt.Sprintf("tick: %d", p.tick)
}

func NewValidTickMathGetSqrtRatioAtTickParams(t *fuzz.T) *tickMathGetSqrtRatioAtTickParams {
	tick := fuzz.Int32Range(MIN_TICK, MAX_TICK).Draw(t, "tick").(int32)
	return &tickMathGetSqrtRatioAtTickParams{tick: tick}
}

func NewRandomizedTickMathGetSqrtRatioAtTickParams(t *fuzz.T) *tickMathGetSqrtRatioAtTickParams {
	tick := fuzz.Int32().Draw(t, "tick").(int32)
	return &tickMathGetSqrtRatioAtTickParams{tick: tick}
}

// Parameters for TickMathGetTickAtSqrtRatio fuzzing test
type tickMathGetTickAtSqrtRatioParams struct {
	sqrtPriceX96 string
}

func (p *tickMathGetTickAtSqrtRatioParams) IsValid() bool {
	minSqrtRatio := u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)

	sqrtPrice := u256.MustFromDecimal(p.sqrtPriceX96)
	return sqrtPrice.Gte(minSqrtRatio) && sqrtPrice.Lt(maxSqrtRatio)
}

func (p *tickMathGetTickAtSqrtRatioParams) ToString() string {
	return ufmt.Sprintf("sqrtPriceX96: %s", p.sqrtPriceX96)
}

func NewValidTickMathGetTickAtSqrtRatioParams(t *fuzz.T) *tickMathGetTickAtSqrtRatioParams {
	minSqrtRatio := u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)

	// Generate valid sqrtPriceX96 within range [minSqrtRatio, maxSqrtRatio)
	sqrtPrice := fuzz.Uint256Range(
		minSqrtRatio.ToString(),
		maxSqrtRatio.ToString(),
	).Draw(t, "sqrtPriceX96").(*u256.Uint)

	// Ensure it's strictly less than maxSqrtRatio
	if sqrtPrice.Gte(maxSqrtRatio) {
		sqrtPrice = u256.Zero().Sub(maxSqrtRatio, u256.One())
	}

	return &tickMathGetTickAtSqrtRatioParams{
		sqrtPriceX96: sqrtPrice.ToString(),
	}
}

func NewRandomizedTickMathGetTickAtSqrtRatioParams(t *fuzz.T) *tickMathGetTickAtSqrtRatioParams {
	// Generate random uint256
	sqrtPrice := fuzz.Uint256().Draw(t, "sqrtPriceX96").(*u256.Uint)

	return &tickMathGetTickAtSqrtRatioParams{
		sqrtPriceX96: sqrtPrice.ToString(),
	}
}
