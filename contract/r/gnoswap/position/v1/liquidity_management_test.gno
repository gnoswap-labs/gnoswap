package v1

import (
	"testing"

	"gno.land/p/nt/uassert"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
)

func initialSetup(t *testing.T) {
	testing.SetRealm(adminRealm)

	pl.SetPoolCreationFee(cross, 0)
	CreatePool(t, gnsPath, barPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
	TokenFaucet(t, gnsPath, alice)
	TokenFaucet(t, barPath, alice)
}

func TestLiquidityManagement_addLiquidity(t *testing.T) {
	poolKey := computePoolPath(gnsPath, barPath, fee3000)

	tests := []struct {
		name            string
		params          AddLiquidityParams
		expectError     bool
		errorType       string // "panic" or "abort"
		expectedAmount0 string
		expectedAmount1 string
		expectedMessage string
	}{
		{
			name: "add liquidity is success by successful liquidity addition",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.MustFromDecimal("400000"),
				amount1Min:     u256.MustFromDecimal("800000"),
				caller:         alice,
			},
			expectError:     false,
			expectedAmount0: "1000000",
			expectedAmount1: "1000000",
		},
		{
			name: "add liquidity is failed by invalid slippage amount",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.MustFromDecimal("1100000"),
				amount1Min:     u256.MustFromDecimal("2200000"),
				caller:         alice,
			},
			expectError:     true,
			errorType:       "panic",
			expectedMessage: "[GNOSWAP-POSITION-002] slippage failed || Price Slippage Check(amount0(1000000) >= amount0Min(1100000), amount1(1000000) >= amount1Min(2200000))",
		},
		{
			name: "add liquidity is failed by zero liquidity",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -100,
				tickUpper:      100,
				amount0Desired: u256.Zero(),
				amount1Desired: u256.Zero(),
				amount0Min:     u256.Zero(),
				amount1Min:     u256.Zero(),
				caller:         alice,
			},
			expectError:     true,
			errorType:       "abort",
			expectedAmount0: "0",
			expectedAmount1: "0",
			expectedMessage: "[GNOSWAP-POOL-010] zero liquidity",
		},
		{
			name: "add liquidity is failed by invalid tick range",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      600,
				tickUpper:      -600,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.MustFromDecimal("900000"),
				amount1Min:     u256.MustFromDecimal("1800000"),
				caller:         alice,
			},
			expectError:     true,
			errorType:       "abort",
			expectedMessage: "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(600), tickUpper(-600)",
		},
		{
			name: "add liquidity is failed by non-existent pool",
			params: AddLiquidityParams{
				poolKey:        "invalid/pool/path",
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.MustFromDecimal("900000"),
				amount1Min:     u256.MustFromDecimal("1800000"),
				caller:         alice,
			},
			expectError:     true,
			errorType:       "abort",
			expectedMessage: "[GNOSWAP-POOL-008] requested data not found || expected poolPath(invalid/pool/path) to exist",
		},
		{
			name: "add liquidity is failed by insufficient balance",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("1000000000000"),
				amount1Desired: u256.MustFromDecimal("2000000000000"),
				amount0Min:     u256.MustFromDecimal("900000000000"),
				amount1Min:     u256.MustFromDecimal("1800000000000"),
				caller:         alice,
			},
			expectError:     true,
			errorType:       "abort",
			expectedMessage: "insufficient balance",
		},
		{
			name: "add liquidity is failed by same tick range",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      0,
				tickUpper:      0,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.MustFromDecimal("900000"),
				amount1Min:     u256.MustFromDecimal("1800000"),
				caller:         alice,
			},
			expectError:     true,
			errorType:       "panic",
			expectedMessage: "[GNOSWAP-COMMON-010] identical ticks || sqrtRatioAX96 (79228162514264337593543950336) and sqrtRatioBX96 (79228162514264337593543950336) are identical",
		},
		{
			name: "add liquidity with exact minimum amounts",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.MustFromDecimal("1000000"),
				amount1Min:     u256.MustFromDecimal("1000000"),
				caller:         alice,
			},
			expectError:     false,
			expectedAmount0: "1000000",
			expectedAmount1: "1000000",
		},
		{
			name: "add liquidity with zero minimum amounts",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.Zero(),
				amount1Min:     u256.Zero(),
				caller:         alice,
			},
			expectError:     false,
			expectedAmount0: "1000000",
			expectedAmount1: "1000000",
		},
		{
			name: "add liquidity slippage fails on amount0 only",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.MustFromDecimal("1100000"),
				amount1Min:     u256.MustFromDecimal("500000"),
				caller:         alice,
			},
			expectError:     true,
			errorType:       "panic",
			expectedMessage: "[GNOSWAP-POSITION-002] slippage failed || Price Slippage Check(amount0(1000000) >= amount0Min(1100000), amount1(1000000) >= amount1Min(500000))",
		},
		{
			name: "add liquidity slippage fails on amount1 only",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.MustFromDecimal("500000"),
				amount1Min:     u256.MustFromDecimal("1100000"),
				caller:         alice,
			},
			expectError:     true,
			errorType:       "panic",
			expectedMessage: "[GNOSWAP-POSITION-002] slippage failed || Price Slippage Check(amount0(1000000) >= amount0Min(500000), amount1(1000000) >= amount1Min(1100000))",
		},
		{
			name: "add liquidity with wide tick range",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -887220,
				tickUpper:      887220,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.MustFromDecimal("1"),
				amount1Min:     u256.MustFromDecimal("1"),
				caller:         alice,
			},
			expectedAmount0: "1000000",
			expectedAmount1: "1000000",
			expectError:     false,
		},
		{
			name: "add liquidity with narrow tick range",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -60,
				tickUpper:      60,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("2000000"),
				amount0Min:     u256.MustFromDecimal("1"),
				amount1Min:     u256.MustFromDecimal("1"),
				caller:         alice,
			},
			expectedAmount0: "1000000",
			expectedAmount1: "1000000",
			expectError:     false,
		},
		{
			name: "add liquidity with small amounts",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("100"),
				amount1Desired: u256.MustFromDecimal("200"),
				amount0Min:     u256.MustFromDecimal("50"),
				amount1Min:     u256.MustFromDecimal("50"),
				caller:         alice,
			},
			expectError:     false,
			expectedAmount0: "100",
			expectedAmount1: "100",
		},
		{
			name: "add liquidity with large amounts",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("100000000"),
				amount1Desired: u256.MustFromDecimal("200000000"),
				amount0Min:     u256.MustFromDecimal("50000000"),
				amount1Min:     u256.MustFromDecimal("50000000"),
				caller:         alice,
			},
			expectError:     false,
			expectedAmount0: "100000000",
			expectedAmount1: "100000000",
		},
		{
			name: "add liquidity with unbalanced amounts",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      600,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("100"),
				amount0Min:     u256.Zero(),
				amount1Min:     u256.Zero(),
				caller:         alice,
			},
			expectedAmount0: "100",
			expectedAmount1: "100",
			expectError:     false,
		},
		{
			name: "add liquidity with invalid tick range",
			params: AddLiquidityParams{
				poolKey:        poolKey,
				tickLower:      -600,
				tickUpper:      1,
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("1000000"),
				amount0Min:     u256.Zero(),
				amount1Min:     u256.Zero(),
				caller:         alice,
			},
			expectedAmount0: "100",
			expectedAmount1: "100",
			expectError:     true,
			expectedMessage: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(1) MOD tickSpacing(60) != 0(1)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			initialSetup(t)
			testing.SetRealm(posRealm)
			TokenApprove(t, gnsPath, alice, poolAddr, tt.params.amount0Desired.Int64())
			TokenApprove(t, barPath, alice, poolAddr, tt.params.amount1Desired.Int64())

			if tt.expectError {
				if tt.errorType == "panic" {
					uassert.PanicsWithMessage(t, tt.expectedMessage, func() {
						mockInstance.addLiquidity(tt.params)
					})
				} else {
					uassert.AbortsWithMessage(t, tt.expectedMessage, func() {
						mockInstance.addLiquidity(tt.params)
					})
				}
			} else {
				_, amount0, amount1 := mockInstance.addLiquidity(tt.params)
				uassert.Equal(t, tt.expectedAmount0, amount0.ToString())
				uassert.Equal(t, tt.expectedAmount1, amount1.ToString())
			}
		})
	}
}
