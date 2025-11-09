package fuzz

import (
	"math"
	"time"

	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// positionIncreaseLiquidityParams is the parameters for IncreaseLiquidity fuzzing test
type positionIncreaseLiquidityParams struct {
	positionId      uint64
	amount0Desired  string
	amount1Desired  string
	amount0Min      string
	amount1Min      string
	deadline        int64
}

func (p *positionIncreaseLiquidityParams) IsValid() bool {
	// Position ID must be non-zero
	if p.positionId == 0 {
		return false
	}

	// Amounts must be parseable and non-negative
	amount0, err0 := u256.FromDecimal(p.amount0Desired)
	amount1, err1 := u256.FromDecimal(p.amount1Desired)
	if err0 != nil || err1 != nil {
		return false
	}
	if amount0.Lt(u256.Zero()) || amount1.Lt(u256.Zero()) {
		return false
	}

	// Both amounts must be non-zero to avoid zero liquidity issues
	if amount0.IsZero() || amount1.IsZero() {
		return false
	}

	// Prevent token mint overflow in stateful tests
	// Similar to position mint, limit amounts to prevent cumulative overflow
	maxSafeAmount := u256.NewUint(uint64(math.MaxInt64 / 1000))
	if amount0.Gt(maxSafeAmount) || amount1.Gt(maxSafeAmount) {
		return false
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

	// Min amounts must not exceed desired amounts
	if amount0Min.Gt(amount0) || amount1Min.Gt(amount1) {
		return false
	}

	// Deadline must be in the future
	if p.deadline < time.Now().Unix() {
		return false
	}

	return true
}

func (p *positionIncreaseLiquidityParams) ToString() string {
	return ufmt.Sprintf("positionId: %d, amount0Desired: %s, amount1Desired: %s",
		p.positionId,
		p.amount0Desired,
		p.amount1Desired,
	)
}

func NewValidPositionIncreaseLiquidityParams(t *fuzz.T, existingPositionId uint64) *positionIncreaseLiquidityParams {
	// Generate valid amounts
	amount0 := fuzz.Int64Range(1000000, 100000000).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(1000000, 100000000).Draw(t, "amount1").(int64)

	return &positionIncreaseLiquidityParams{
		positionId:     existingPositionId,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       fuzz.Int64Range(1700000000, 2000000000).Draw(t, "deadline").(int64),
	}
}

func NewRandomizedPositionIncreaseLiquidityParams(t *fuzz.T, existingPositionId uint64) *positionIncreaseLiquidityParams {
	// Generate randomized amounts - full range to test edge cases
	amount0 := fuzz.Int64Range(math.MinInt64, math.MaxInt64).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(math.MinInt64, math.MaxInt64).Draw(t, "amount1").(int64)

	// Randomized deadline - can be past, present, or future
	deadline := fuzz.Int64Range(0, math.MaxInt64).Draw(t, "deadline").(int64)

	return &positionIncreaseLiquidityParams{
		positionId:     existingPositionId,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       deadline,
	}
}
