package fuzz

import (
	"time"

	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// positionDecreaseLiquidityParams is the parameters for DecreaseLiquidity fuzzing test
type positionDecreaseLiquidityParams struct {
	positionId   uint64
	liquidity    string
	amount0Min   string
	amount1Min   string
	deadline     int64
	unwrapResult bool
	poolPath     string
}

func (p *positionDecreaseLiquidityParams) IsValid() bool {
	// Position ID must be non-zero
	if p.positionId == 0 {
		return false
	}

	_, err := position.GetPosition(p.positionId)
	if err != nil {
		return false
	}

	poolPath := position.GetPositionPoolKey(p.positionId)
	if poolPath == "" || !pool.ExistsPoolPath(poolPath) {
		return false
	}

	if p.poolPath != "" && p.poolPath != poolPath {
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

	// Liquidity must not exceed current position liquidity
	currentLiquidity := position.GetPositionLiquidity(p.positionId)
	if liq.Gt(currentLiquidity) {
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

	// Deadline must be positive
	if p.deadline <= time.Now().Unix() {
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

func NewValidPositionDecreaseLiquidityParams(t *fuzz.T, existingPositionId uint64) *positionDecreaseLiquidityParams {
	return newValidPositionDecreaseLiquidityParams(t, existingPositionId)
}

func NewRandomizedPositionDecreaseLiquidityParams(t *fuzz.T, existingPositionId uint64) *positionDecreaseLiquidityParams {
	scenario := fuzz.IntRange(0, 4).Draw(t, "decreaseScenario").(int)

	switch scenario {
	case 0:
		return newValidPositionDecreaseLiquidityParams(t, existingPositionId)
	case 1:
		params := newValidPositionDecreaseLiquidityParams(t, existingPositionId)
		liq, _ := u256.FromDecimal(params.liquidity)
		liqudity := u256.NewUint(0).Add(liq, u256.NewUint(1))
		params.liquidity = liqudity.ToString()
		return params
	case 2:
		params := newValidPositionDecreaseLiquidityParams(t, existingPositionId)
		params.liquidity = "0"
		return params
	case 3:
		params := newValidPositionDecreaseLiquidityParams(t, existingPositionId)
		params.deadline = time.Now().Add(-time.Minute).Unix()
		return params
	default:
		return &positionDecreaseLiquidityParams{
			positionId:   existingPositionId + uint64(fuzz.Int64Range(1, 1_000_000).Draw(t, "positionOffset").(int64)),
			liquidity:    "1000",
			amount0Min:   "0",
			amount1Min:   "0",
			deadline:     time.Now().Add(time.Hour).Unix(),
			unwrapResult: fuzz.Bool().Draw(t, "unwrapResult").(bool),
			poolPath:     "",
		}
	}
}

func newValidPositionDecreaseLiquidityParams(t *fuzz.T, positionId uint64) *positionDecreaseLiquidityParams {
	currentLiquidity := position.GetPositionLiquidity(positionId)
	if currentLiquidity.IsZero() {
		panic("position liquidity must be positive for valid decrease fuzz case")
	}

	percentage := fuzz.Int64Range(10, 100).Draw(t, "percentage").(int64)

	liq := u256.NewUint(0).Mul(currentLiquidity, u256.NewUint(uint64(percentage)))
	liq = liq.Div(liq, u256.NewUint(100))

	deadlineSeconds := fuzz.Int64Range(30, 600).Draw(t, "deadlineBufferSeconds").(int64)
	deadline := time.Now().Add(time.Duration(deadlineSeconds) * time.Second).Unix()

	return &positionDecreaseLiquidityParams{
		positionId:   positionId,
		liquidity:    liq.ToString(),
		amount0Min:   "0",
		amount1Min:   "0",
		deadline:     deadline,
		unwrapResult: fuzz.Bool().Draw(t, "unwrapResult").(bool),
		poolPath:     position.GetPositionPoolKey(positionId),
	}
}
