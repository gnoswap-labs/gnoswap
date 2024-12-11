package router

import (
	"testing"

	"gno.land/r/gnoswap/v1/common"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestCalculateSqrtPriceLimitForSwap(t *testing.T) {
    tests := []struct {
        name              string
        zeroForOne        bool
        fee              uint32
        sqrtPriceLimitX96 *u256.Uint
        expected         *u256.Uint
    }{
        {
			name:              "already set sqrtPriceLimit",
			zeroForOne:        true,
			fee:               500,
			sqrtPriceLimitX96: u256.NewUint(1000),
			expected:         u256.NewUint(1000),
        },
        {
			name:              "when zeroForOne is true, calculate min tick",
            zeroForOne:        true,
            fee:              500,
            sqrtPriceLimitX96: u256.Zero(),
            expected:         common.TickMathGetSqrtRatioAtTick(getMinTick(500)).Add(
                common.TickMathGetSqrtRatioAtTick(getMinTick(500)), 
                u256.One(),
            ),
        },
        {
            name:              "when zeroForOne is false, calculate max tick",
            zeroForOne:        false,
            fee:              500,
            sqrtPriceLimitX96: u256.Zero(),
            expected:         common.TickMathGetSqrtRatioAtTick(getMaxTick(500)).Sub(
                common.TickMathGetSqrtRatioAtTick(getMaxTick(500)), 
                u256.One(),
            ),
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := calculateSqrtPriceLimitForSwap(
                tt.zeroForOne,
                tt.fee,
                tt.sqrtPriceLimitX96,
            )
            
            if !result.Eq(tt.expected) {
                t.Errorf(
                    "case '%s': expected %s, actual %s", 
                    tt.name, 
                    tt.expected.ToString(), 
                    result.ToString(),
                )
            }
        })
    }
}
