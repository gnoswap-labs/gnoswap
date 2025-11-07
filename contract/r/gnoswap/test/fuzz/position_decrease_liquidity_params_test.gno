package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// positionDecreaseLiquidityParams is the parameters for DecreaseLiquidity fuzzing test
type positionDecreaseLiquidityParams struct {
	positionId      uint64
	liquidity       string
	amount0Min      string
	amount1Min      string
	deadline        int64
	unwrapResult    bool
	actualLiquidity string // actual liquidity of the position for validation
}

func (p *positionDecreaseLiquidityParams) IsValid() bool {
	// Position ID must be non-zero
	if p.positionId == 0 {
		return false
	}

	// Liquidity must be parseable and positive
	liq, err := u256.FromDecimal(p.liquidity)
	if err != nil {
		return false
	}
	if liq.Lte(u256.Zero()) {
		return false
	}

	// Liquidity must not exceed actual position liquidity
	if p.actualLiquidity != "" {
		actualLiq, err := u256.FromDecimal(p.actualLiquidity)
		if err == nil && liq.Gt(actualLiq) {
			return false
		}
	}

	// Min amounts must be parseable and non-negative
	amount0Min, err0Min := u256.FromDecimal(p.amount0Min)
	amount1Min, err1Min := u256.FromDecimal(p.amount1Min)
	if err0Min != nil || err1Min != nil {
		return false
	}
	if amount0Min.Lt(u256.Zero()) || amount1Min.Lt(u256.Zero()) {
		return false
	}

	// Deadline must be positive
	if p.deadline <= 0 {
		return false
	}

	return true
}

func (p *positionDecreaseLiquidityParams) ToString() string {
	return ufmt.Sprintf("positionId: %d, liquidity: %s, unwrapResult: %t",
		p.positionId,
		p.liquidity,
		p.unwrapResult,
	)
}

func NewValidPositionDecreaseLiquidityParams(t *fuzz.T, existingPositionId uint64, maxLiquidity string) *positionDecreaseLiquidityParams {
	// Generate valid liquidity amount (percentage of max)
	percentage := fuzz.Int64Range(10, 90).Draw(t, "percentage").(int64) // 10% to 90%
	maxLiq, _ := u256.FromDecimal(maxLiquidity)

	// Calculate liquidity to decrease
	liq := u256.NewUint(0).Mul(maxLiq, u256.NewUint(uint64(percentage)))
	liq = liq.Div(liq, u256.NewUint(100))

	unwrapResult := fuzz.Bool().Draw(t, "unwrapResult").(bool)

	return &positionDecreaseLiquidityParams{
		positionId:      existingPositionId,
		liquidity:       liq.ToString(),
		amount0Min:      "0",
		amount1Min:      "0",
		deadline:        fuzz.Int64Range(1700000000, 2000000000).Draw(t, "deadline").(int64),
		unwrapResult:    unwrapResult,
		actualLiquidity: maxLiquidity,
	}
}

func NewRandomizedPositionDecreaseLiquidityParams(t *fuzz.T, existingPositionId uint64, actualLiquidity string) *positionDecreaseLiquidityParams {
	// Generate random liquidity amount
	liquidity := fuzz.Int64Range(1, 1000000000).Draw(t, "liquidity").(int64)
	unwrapResult := fuzz.Bool().Draw(t, "unwrapResult").(bool)

	return &positionDecreaseLiquidityParams{
		positionId:      existingPositionId,
		liquidity:       ufmt.Sprintf("%d", liquidity),
		amount0Min:      "0",
		amount1Min:      "0",
		deadline:        fuzz.Int64Range(1700000000, 2000000000).Draw(t, "deadline").(int64),
		unwrapResult:    unwrapResult,
		actualLiquidity: actualLiquidity,
	}
}
