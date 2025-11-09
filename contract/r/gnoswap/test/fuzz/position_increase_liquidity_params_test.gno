package fuzz

import (
	"math"
	"time"

	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// positionIncreaseLiquidityParams is the parameters for IncreaseLiquidity fuzzing test
type positionIncreaseLiquidityParams struct {
	positionId     uint64
	amount0Desired string
	amount1Desired string
	amount0Min     string
	amount1Min     string
	deadline       int64
	poolPath       string
}

func (p *positionIncreaseLiquidityParams) IsValid() bool {
	// Position ID must be non-zero
	if p.positionId == 0 {
		return false
	}

	_, exists := position.GetPosition(p.positionId)
	if !exists {
		return false
	}

	poolPath := position.GetPositionPoolKey(p.positionId)
	if poolPath == "" || !pool.ExistsPoolPath(poolPath) {
		return false
	}

	if p.poolPath != "" && p.poolPath != poolPath {
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
	if p.deadline <= time.Now().Unix() {
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
	return newValidPositionIncreaseLiquidityParams(t, existingPositionId)
}

func NewRandomizedPositionIncreaseLiquidityParams(t *fuzz.T, existingPositionId uint64) *positionIncreaseLiquidityParams {
	scenario := fuzz.IntRange(0, 4).Draw(t, "increaseScenario").(int)

	switch scenario {
	case 0:
		return newValidPositionIncreaseLiquidityParams(t, existingPositionId)
	case 1:
		params := newValidPositionIncreaseLiquidityParams(t, existingPositionId)
		params.amount0Desired = "0"
		return params
	case 2:
		params := newValidPositionIncreaseLiquidityParams(t, existingPositionId)
		amount := u256.MustFromDecimal(params.amount0Desired)
		params.amount0Min = amount.Add(amount, u256.NewUint(1)).ToString()
		return params
	case 3:
		params := newValidPositionIncreaseLiquidityParams(t, existingPositionId)
		params.deadline = time.Now().Add(-time.Minute).Unix()
		return params
	default:
		return &positionIncreaseLiquidityParams{
			positionId:     existingPositionId + uint64(fuzz.Int64Range(1, math.MaxInt32).Draw(t, "positionOffset").(int64)),
			amount0Desired: "1000",
			amount1Desired: "1000",
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       time.Now().Add(time.Hour).Unix(),
			poolPath:       "",
		}
	}
}

func newValidPositionIncreaseLiquidityParams(t *fuzz.T, positionId uint64) *positionIncreaseLiquidityParams {
	poolPath := position.GetPositionPoolKey(positionId)
	if poolPath == "" {
		panic("poolPath must exist for position")
	}

	amount0 := fuzz.Int64Range(1_000_000, 100_000_000).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(1_000_000, 100_000_000).Draw(t, "amount1").(int64)

	deadlineSeconds := fuzz.Int64Range(30, 600).Draw(t, "deadlineBufferSeconds").(int64)
	deadline := time.Now().Add(time.Duration(deadlineSeconds) * time.Second).Unix()

	return &positionIncreaseLiquidityParams{
		positionId:     positionId,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       deadline,
		poolPath:       poolPath,
	}
}
