package fuzz

import (
	"math"

	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

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

	tickLower, tickUpper := sampleRepositionTicks(t, poolPath, fee)

	amount0 := fuzz.Int64Range(1_000_000, 100_000_000).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(1_000_000, 100_000_000).Draw(t, "amount1").(int64)

	return &positionRepositionParams{
		positionId:     positionId,
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		poolPath:       poolPath,
	}
}

func sampleRepositionTicks(t *fuzz.T, poolPath string, fee uint32) (int32, int32) {
	currentTick := pool.GetSlot0Tick(poolPath)

	switch fuzz.IntRange(0, 1).Draw(t, "repositionTickScenario").(int) {
	case 0:
		return generateRandomTicks(t, currentTick, fee)
	default:
		return generateInRangeTick(t, currentTick, fee)
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

		return &positionRepositionParams{
			positionId:     existingPositionId,
			fee:            fee,
			tickLower:      tickLower,
			tickUpper:      tickUpper,
			amount0Desired: ufmt.Sprintf("%d", amount0),
			amount1Desired: ufmt.Sprintf("%d", amount1),
			amount0Min:     "0",
			amount1Min:     "0",
			poolPath:       "",
		}
	}
}
