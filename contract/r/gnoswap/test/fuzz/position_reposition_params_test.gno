package fuzz

import (
	"math"

	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// positionRepositionParams is the parameters for Reposition fuzzing test
type positionRepositionParams struct {
	positionId     uint64
	fee            uint32
	tickLower      int32
	tickUpper      int32
	amount0Desired string
	amount1Desired string
	amount0Min     string
	amount1Min     string
	deadline       int64
	poolPath       string
}

func (p *positionRepositionParams) IsValid() bool {
	if p.positionId == 0 {
		return false
	}

	if _, exists := position.GetPosition(p.positionId); !exists {
		return false
	}

	poolPath := position.GetPositionPoolKey(p.positionId)
	if poolPath == "" || !pool.ExistsPoolPath(poolPath) {
		return false
	}

	_, _, fee := parsePoolKey(poolPath)

	tickSpacing, ok := defaultTickSpacings[fee]
	if !ok {
		return false
	}

	if p.tickLower >= p.tickUpper {
		return false
	}

	if p.tickLower%tickSpacing != 0 || p.tickUpper%tickSpacing != 0 {
		return false
	}

	if p.tickUpper-p.tickLower < tickSpacing {
		return false
	}

	amount0, err0 := u256.FromDecimal(p.amount0Desired)
	amount1, err1 := u256.FromDecimal(p.amount1Desired)
	if err0 != nil || err1 != nil {
		return false
	}
	if amount0.Lt(u256.Zero()) || amount1.Lt(u256.Zero()) {
		return false
	}

	if amount0.IsZero() || amount1.IsZero() {
		return false
	}

	maxSafeAmount := u256.NewUint(uint64(math.MaxInt64 / 1000))
	if amount0.Gt(maxSafeAmount) || amount1.Gt(maxSafeAmount) {
		return false
	}

	amount0Min, err0Min := u256.FromDecimal(p.amount0Min)
	amount1Min, err1Min := u256.FromDecimal(p.amount1Min)
	if err0Min != nil || err1Min != nil {
		return false
	}
	if amount0Min.Lt(u256.Zero()) || amount1Min.Lt(u256.Zero()) {
		return false
	}

	if amount0Min.Gt(amount0) || amount1Min.Gt(amount1) {
		return false
	}

	if !p.IsValidLiquidity() {
		return false
	}

	return true
}

func (p *positionRepositionParams) IsValidLiquidity() (isValid bool) {
	defer func() {
		if r := recover(); r != nil {
			isValid = false
		}
	}()

	amount0, err0 := u256.FromDecimal(p.amount0Desired)
	amount1, err1 := u256.FromDecimal(p.amount1Desired)
	if err0 != nil || err1 != nil {
		return false
	}
	sqrtPriceX96 := pool.GetSlot0SqrtPriceX96(p.poolPath)
	sqrtRatioAX96 := common.TickMathGetSqrtRatioAtTick(p.tickLower)
	sqrtRatioBX96 := common.TickMathGetSqrtRatioAtTick(p.tickUpper)

	liquidity := common.GetLiquidityForAmounts(
		sqrtPriceX96,
		sqrtRatioAX96,
		sqrtRatioBX96,
		amount0,
		amount1,
	)

	if liquidity.IsZero() || liquidity.Gt(MAX_UINT128) {
		return false
	}

	return true
}

func (p *positionRepositionParams) ToString() string {
	return ufmt.Sprintf("positionId: %d, fee: %d, tickLower: %d, tickUpper: %d, poolPath: %s, amount0Desired: %s, amount1Desired: %s",
		p.positionId,
		p.fee,
		p.tickLower,
		p.tickUpper,
		p.poolPath,
		p.amount0Desired,
		p.amount1Desired,
	)
}

func NewValidPositionRepositionParams(t *fuzz.T, existingPositionId uint64) *positionRepositionParams {
	return newValidPositionRepositionParams(t, existingPositionId)
}

func newValidPositionRepositionParams(t *fuzz.T, positionId uint64) *positionRepositionParams {
	token0Path, token1Path, fee := getPoolInfoFromPosition(positionId)
	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	currentTick := pool.GetSlot0Tick(poolPath)
	tickLower, tickUpper := generateRandomTicks(t, currentTick, fee)

	amount0 := fuzz.Int64Range(1, 1_000_000_000_000).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(1, 1_000_000_000_000).Draw(t, "amount1").(int64)
	deadline := randomFutureDeadline(t)

	return &positionRepositionParams{
		positionId:     positionId,
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       deadline,
		poolPath:       poolPath,
	}
}

func NewRandomizedPositionRepositionParams(t *fuzz.T, existingPositionId uint64) *positionRepositionParams {
	scenario := fuzz.IntRange(0, 3).Draw(t, "repositionScenario").(int)

	switch scenario {
	case 0:
		return newValidPositionRepositionParams(t, existingPositionId)
	case 1:
		params := newValidPositionRepositionParams(t, existingPositionId)
		params.tickLower = params.tickUpper // invalid range
		return params
	case 2:
		params := newValidPositionRepositionParams(t, existingPositionId)
		params.amount0Desired = "0"
		params.amount1Desired = "0"
		return params
	default:
		fee := fuzz.Uint32Range(0, math.MaxUint32).Draw(t, "fee").(uint32)
		tickLower := fuzz.Int32Range(math.MinInt32, math.MaxInt32).Draw(t, "tickLower").(int32)
		tickUpper := fuzz.Int32Range(math.MinInt32, math.MaxInt32).Draw(t, "tickUpper").(int32)
		amount0 := fuzz.Int64Range(math.MinInt64, math.MaxInt64).Draw(t, "amount0").(int64)
		amount1 := fuzz.Int64Range(math.MinInt64, math.MaxInt64).Draw(t, "amount1").(int64)
		deadline := randomFutureDeadline(t)

		return &positionRepositionParams{
			positionId:     existingPositionId,
			fee:            fee,
			tickLower:      tickLower,
			tickUpper:      tickUpper,
			amount0Desired: ufmt.Sprintf("%d", amount0),
			amount1Desired: ufmt.Sprintf("%d", amount1),
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       deadline,
			poolPath:       "",
		}
	}
}
