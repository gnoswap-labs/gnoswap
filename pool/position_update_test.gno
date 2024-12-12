package pool

import (
	"strconv"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/consts"
)

func TestUpdatePosition(t *testing.T) {
	poolParams := &createPoolParams{
		token0Path:   "token0",
		token1Path:   "token1",
		fee:          500,
		tickSpacing:  10,
		sqrtPriceX96: u256.MustFromDecimal("1000000000000000000"), // 1.0
	}
	p := newPool(poolParams)

	tests := []struct {
		name            string
		positionParams  ModifyPositionParams
		expectLiquidity *u256.Uint
	}{
		{
			name: "add new position",
			positionParams: ModifyPositionParams{
				owner:          consts.POSITION_ADDR,
				tickLower:      -100,
				tickUpper:      100,
				liquidityDelta: i256.MustFromDecimal("1000000"),
			},
			expectLiquidity: u256.MustFromDecimal("1000000"),
		},
		{
			name: "add liquidity to existing position",
			positionParams: ModifyPositionParams{
				owner:          consts.POSITION_ADDR,
				tickLower:      -100,
				tickUpper:      100,
				liquidityDelta: i256.MustFromDecimal("500000"),
			},
			expectLiquidity: u256.MustFromDecimal("1500000"),
		},
		{
			name: "remove liquidity from position",
			positionParams: ModifyPositionParams{
				owner:          consts.POSITION_ADDR,
				tickLower:      -100,
				tickUpper:      100,
				liquidityDelta: i256.MustFromDecimal("-500000"),
			},
			expectLiquidity: u256.MustFromDecimal("1000000"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			position := p.updatePosition(tt.positionParams)

			if !position.liquidity.Eq(tt.expectLiquidity) {
				t.Errorf("liquidity mismatch: expected %s, got %s",
					tt.expectLiquidity.ToString(),
					position.liquidity.ToString())
			}

			if !tt.positionParams.liquidityDelta.IsZero() {
				iLowerTick, _ := p.ticks.Get(strconv.FormatInt(int64(tt.positionParams.tickLower), 10))
				iUpperTick, _ := p.ticks.Get(strconv.FormatInt(int64(tt.positionParams.tickUpper), 10))
				lowerTick := iLowerTick.(TickInfo)
				upperTick := iUpperTick.(TickInfo)

				if !lowerTick.initialized {
					t.Error("lower tick not initialized")
				}
				if !upperTick.initialized {
					t.Error("upper tick not initialized")
				}
			}
		})
	}
}
