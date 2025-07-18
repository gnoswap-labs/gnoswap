package position

import (
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/v1/pool"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

func TestMintInternal_PositionMint(t *testing.T) {
	tests := []struct {
		name              string
		params            MintParams
		expectPanic       bool
		expectedMsg       string
		expectedId        uint64
		expectedLiquidity string
		expectedAmount0   string
		expectedAmount1   string
	}{
		{
			name: "mint is success by successful mint",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      -120,
				tickUpper:      120,
				amount0Desired: u256.MustFromDecimal("100000"),
				amount1Desired: u256.MustFromDecimal("100000"),
				amount0Min:     u256.MustFromDecimal("90000"),
				amount1Min:     u256.MustFromDecimal("90000"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "16717549",
			expectedAmount0:   "100000",
			expectedAmount1:   "100000",
		},
		{
			name: "mint is failed by zero liquidity",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      -120,
				tickUpper:      120,
				amount0Desired: u256.MustFromDecimal("0"),
				amount1Desired: u256.MustFromDecimal("0"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         testutils.TestAddress("caller"),
				mintTo:         testutils.TestAddress("recipient"),
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-010] zero liquidity",
		},
		{
			name: "mint fails at full range due to tick spacing",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      -887272, // MIN_TICK (not multiple of 60)
				tickUpper:      887272,  // MAX_TICK
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-887272) MOD tickSpacing(60) != 0(-52)",
		},
		{
			name: "mint at adjusted full range for fee tier",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      -887220, // adjusted to multiple of 60
				tickUpper:      887220,  // adjusted to multiple of 60
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1", // minimal liquidity for full range
			expectedAmount0:   "1",
			expectedAmount1:   "1",
		},
		{
			name: "mint fails with invalid tick spacing",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000, // tick spacing 60
				tickLower:      -125, // not multiple of 60
				tickUpper:      120,
				amount0Desired: u256.MustFromDecimal("100000"),
				amount1Desired: u256.MustFromDecimal("100000"),
				amount0Min:     u256.MustFromDecimal("90000"),
				amount1Min:     u256.MustFromDecimal("90000"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-125) MOD tickSpacing(60) != 0(-5)",
		},
		{
			name: "mint fails with inverted tick range",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      120, // upper < lower
				tickUpper:      -120,
				amount0Desired: u256.MustFromDecimal("100000"),
				amount1Desired: u256.MustFromDecimal("100000"),
				amount0Min:     u256.MustFromDecimal("90000"),
				amount1Min:     u256.MustFromDecimal("90000"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(120), tickUpper(-120)",
		},
		{
			name: "mint succeeds at safe extreme range",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      -300000, // safe extreme
				tickUpper:      300000,
				amount0Desired: u256.MustFromDecimal("1000"),
				amount1Desired: u256.MustFromDecimal("1000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1000",
			expectedAmount0:   "1000",
			expectedAmount1:   "1000",
		},
		{
			name: "mint with single-sided liquidity (out of range)",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      1020, // above current tick (must be multiple of 60)
				tickUpper:      2040,
				amount0Desired: u256.MustFromDecimal("100000"),
				amount1Desired: u256.MustFromDecimal("100000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "2116539",
			expectedAmount0:   "100000",
			expectedAmount1:   "0",
		},
		{
			name: "mint with extreme liquidity amount fails due to insufficient balance",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      -500040, // must be multiple of 60
				tickUpper:      500040,
				amount0Desired: u256.MustFromDecimal("9223372036854775807"), // int64 max
				amount1Desired: u256.MustFromDecimal("9223372036854775807"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-021] token transfer failed || insufficient balance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFeeByAdmin(cross, 0)
			CreatePool(t, tt.params.token0, tt.params.token1, tt.params.fee, "79228162514264337593543950336", adminAddr)

			TokenFaucet(t, tt.params.token0, alice)
			TokenFaucet(t, tt.params.token1, alice)

			testing.SetRealm(posRealm)
			TokenApprove(t, tt.params.token0, alice, poolAddr, maxApprove)
			TokenApprove(t, tt.params.token1, alice, poolAddr, maxApprove)

			bar.Approve(cross, poolAddr, maxApprove)
			baz.Approve(cross, poolAddr, maxApprove)

			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedMsg, func() {
					mint(tt.params)
				})
			} else {
				id, liquidity, amount0, amount1 := mint(tt.params)
				uassert.Equal(t, tt.expectedId, id)
				uassert.Equal(t, tt.expectedLiquidity, liquidity.ToString())
				uassert.Equal(t, tt.expectedAmount0, amount0.ToString())
				uassert.Equal(t, tt.expectedAmount1, amount1.ToString())
			}
		})
	}
}

// Separate test for panic cases
func TestMintInternal_PanicCases(t *testing.T) {
	tests := []struct {
		name        string
		params      MintParams
		expectedMsg string
	}{
		{
			name: "mint fails when slippage protection triggered",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      -120,
				tickUpper:      120,
				amount0Desired: u256.MustFromDecimal("100000"),
				amount1Desired: u256.MustFromDecimal("100000"),
				amount0Min:     u256.MustFromDecimal("200000"), // min > desired
				amount1Min:     u256.MustFromDecimal("200000"),
				caller:         alice,
				mintTo:         alice,
			},
			expectedMsg: "[GNOSWAP-POSITION-002] slippage failed || Price Slippage Check(amount0(100000) >= amount0Min(200000), amount1(100000) >= amount1Min(200000))",
		},
		{
			name: "mint fails when tickLower equals tickUpper",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      120,
				tickUpper:      120, // same tick
				amount0Desired: u256.MustFromDecimal("100000"),
				amount1Desired: u256.MustFromDecimal("100000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectedMsg: "[GNOSWAP-COMMON-010] identical ticks || sqrtRatioAX96 (79704936542881920863903188246) and sqrtRatioBX96 (79704936542881920863903188246) are identical",
		},
		{
			name: "mint fails with invalid tick range - out of MIN/MAX bounds",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      -887273, // below MIN_TICK
				tickUpper:      0,
				amount0Desired: u256.MustFromDecimal("1000"),
				amount1Desired: u256.MustFromDecimal("1000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectedMsg: "[GNOSWAP-COMMON-003] value out of range || tick is out of range (smaller than -887272), tick: -887273",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFeeByAdmin(cross, 0)
			CreatePool(t, tt.params.token0, tt.params.token1, tt.params.fee, "79228162514264337593543950336", adminAddr)

			TokenFaucet(t, tt.params.token0, alice)
			TokenFaucet(t, tt.params.token1, alice)

			testing.SetRealm(posRealm)
			TokenApprove(t, tt.params.token0, alice, poolAddr, maxApprove)
			TokenApprove(t, tt.params.token1, alice, poolAddr, maxApprove)

			bar.Approve(cross, poolAddr, maxApprove)
			baz.Approve(cross, poolAddr, maxApprove)

			uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
				mint(tt.params)
			})
		})
	}
}

func TestMintInternal_FeeTierEdgeCases(t *testing.T) {
	tests := []struct {
		name              string
		params            MintParams
		expectPanic       bool
		expectedMsg       string
		expectedId        uint64
		expectedLiquidity string
		expectedAmount0   string
		expectedAmount1   string
	}{
		// 0.01% pool (tick spacing 1)
		{
			name: "single tick liquidity - 0.01% pool",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            100, // 0.01%, tick spacing 1
				tickLower:      0,
				tickUpper:      1, // single tick range
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("1000000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "20001499987",
			expectedAmount0:   "1000000",
			expectedAmount1:   "0",
		},
		{
			name: "extreme narrow range in 0.01% pool",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            100, // 0.01%
				tickLower:      -887271,
				tickUpper:      -887270, // single tick at extreme
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "368911457866216265417270",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			name: "full range mint in 0.01% pool",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            100, // 0.01%, tick spacing 1
				tickLower:      -887272,
				tickUpper:      887272, // full range valid for spacing 1
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1",
			expectedAmount0:   "1",
			expectedAmount1:   "1",
		},
		{
			name: "concentrated liquidity overflow - 0.01% pool",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            100,
				tickLower:      -1,
				tickUpper:      1,                                           // 2 tick range
				amount0Desired: u256.MustFromDecimal("9223372036854775807"), // int64 max
				amount1Desired: u256.MustFromDecimal("9223372036854775807"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-021] token transfer failed || insufficient balance",
		},
		// 0.05% pool (tick spacing 10)
		{
			name: "single tick liquidity - 0.05% pool",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            500, // 0.05%, tick spacing 10
				tickLower:      -10,
				tickUpper:      0, // single tick range
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("1000000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "2000600039", // 수정됨
			expectedAmount0:   "0",
			expectedAmount1:   "1000000",
		},
		{
			name: "invalid tick for 0.05% pool - not multiple of 10",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            500, // 0.05%, tick spacing 10
				tickLower:      -15, // not multiple of 10
				tickUpper:      20,
				amount0Desired: u256.MustFromDecimal("1000"),
				amount1Desired: u256.MustFromDecimal("1000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-15) MOD tickSpacing(10) != 0(-5)",
		},
		// 0.3% pool (tick spacing 60)
		{
			name: "single tick liquidity - 0.3% pool",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000, // 0.3%, tick spacing 60
				tickLower:      -60,
				tickUpper:      0, // single tick range
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("1000000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "333850249",
			expectedAmount0:   "0",
			expectedAmount1:   "1000000",
		},
		// 1% pool (tick spacing 200)
		{
			name: "single tick liquidity - 1% pool",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            10000, // 1%, tick spacing 200
				tickLower:      -200,
				tickUpper:      0, // single tick range
				amount0Desired: u256.MustFromDecimal("1000000"),
				amount1Desired: u256.MustFromDecimal("1000000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "100505833",
			expectedAmount0:   "0",
			expectedAmount1:   "1000000",
		},
		{
			name: "tick spacing boundary test - 1% pool",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            10000, // 1%, spacing 200
				tickLower:      -199,  // invalid, not multiple of 200
				tickUpper:      200,
				amount0Desired: u256.MustFromDecimal("1000"),
				amount1Desired: u256.MustFromDecimal("1000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-199) MOD tickSpacing(200) != 0(-199)",
		},
		// Edge cases for extreme ticks
		{
			name: "negative tick extreme with 0.01% pool",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            100,
				tickLower:      -500000,
				tickUpper:      -499999, // single tick at negative extreme
				amount0Desired: u256.MustFromDecimal("1000"),
				amount1Desired: u256.MustFromDecimal("1000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1438335065300305010",
			expectedAmount0:   "0",
			expectedAmount1:   "1000",
		},
		// XXX this needs to debug: [TickMathGetSqrtRatioAtTick] ratio is zero
		{
			name: "positive tick extreme with 0.01% pool",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            100,
				tickLower:      499999,
				tickUpper:      500000, // single tick at positive extreme
				amount0Desired: u256.MustFromDecimal("1000"),
				amount1Desired: u256.MustFromDecimal("1000"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectedId: 1,
			expectedLiquidity: "1438335065300290965",
			expectedAmount0: "1000",
			expectedAmount1: "0",
			expectPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFeeByAdmin(cross, 0)
			CreatePool(t, tt.params.token0, tt.params.token1, tt.params.fee, "79228162514264337593543950336", adminAddr)

			TokenFaucet(t, tt.params.token0, alice)
			TokenFaucet(t, tt.params.token1, alice)

			testing.SetRealm(posRealm)
			TokenApprove(t, tt.params.token0, alice, poolAddr, maxApprove)
			TokenApprove(t, tt.params.token1, alice, poolAddr, maxApprove)

			bar.Approve(cross, poolAddr, maxApprove)
			baz.Approve(cross, poolAddr, maxApprove)

			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedMsg, func() {
					mint(tt.params)
				})
			} else {
				id, liquidity, amount0, amount1 := mint(tt.params)
				uassert.Equal(t, tt.expectedId, id)
				uassert.Equal(t, tt.expectedLiquidity, liquidity.ToString())
				uassert.Equal(t, tt.expectedAmount0, amount0.ToString())
				uassert.Equal(t, tt.expectedAmount1, amount1.ToString())
			}
		})
	}
}

func TestMintInternal_TickBoundaries(t *testing.T) {
	tests := []struct {
		name              string
		params            MintParams
		expectPanic       bool
		expectedMsg       string
		expectedId        uint64
		expectedLiquidity string
		expectedAmount0   string
		expectedAmount1   string
	}{
		// 0.01% pool (tick spacing 1) - MIN/MAX boundaries
		{
			// XXX this needs to debug: [TickMathGetSqrtRatioAtTick] ratio is zero
			name: "Test1",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            100,
				tickLower:      -1, // MIN_TICK (valid for spacing 1)
				tickUpper:      424288,
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "368930354290617215256478",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			// XXX this needs to debug: [TickMathGetSqrtRatioAtTick] ratio is zero
			name: "0.01% pool - valid at MIN_TICK boundary",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            100,
				tickLower:      -887272, // MIN_TICK (valid for spacing 1)
				tickUpper:      -887271,
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "368930354290617215256478",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			name: "0.01% pool - valid at MAX_TICK boundary",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            100,
				tickLower:      887271,
				tickUpper:      887272, // MAX_TICK (valid for spacing 1)
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "368930237016745472596742",
			expectedAmount0:   "1",
			expectedAmount1:   "0",
		},
		// 0.05% pool (tick spacing 10) - boundaries
		{
			name: "0.05% pool - valid near MIN_TICK",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            500,
				tickLower:      -887270, // closest valid multiple of 10 to MIN_TICK
				tickUpper:      -887260,
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "36881048070887147610261",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			name: "0.05% pool - invalid tick not multiple of 10 near MIN",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            500,
				tickLower:      -887272, // MIN_TICK but not multiple of 10
				tickUpper:      -887262,
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-887272) MOD tickSpacing(10) != 0(-2)",
		},
		// 0.3% pool (tick spacing 60) - boundaries
		{
			name: "0.3% pool - valid near MIN_TICK",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      -887220, // closest valid multiple of 60 to MIN_TICK
				tickUpper:      -887160,
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "6123830742008175932125",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			name: "0.3% pool - invalid tick not multiple of 60",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      -887272, // MIN_TICK but not multiple of 60
				tickUpper:      -887212,
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-887272) MOD tickSpacing(60) != 0(-52)",
		},
		// 1% pool (tick spacing 200) - boundaries
		{
			name: "1% pool - valid near MIN_TICK",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            10000,
				tickLower:      -887200, // closest valid multiple of 200 to MIN_TICK
				tickUpper:      -887000,
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1828894101765470541727",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			name: "1% pool - invalid tick not multiple of 200",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            10000,
				tickLower:      -887272, // MIN_TICK but not multiple of 200
				tickUpper:      -887072,
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-887272) MOD tickSpacing(200) != 0(-72)",
		},
		// Testing valid MAX_TICK boundaries for fee tiers
		{
			name: "0.05% pool - valid near MAX_TICK",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            500,
				tickLower:      887260,
				tickUpper:      887270, // closest valid multiple of 10 to MAX_TICK
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "36881035636152488417312",
			expectedAmount0:   "1",
			expectedAmount1:   "0",
		},
		{
			name: "0.3% pool - valid near MAX_TICK",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            3000,
				tickLower:      887160,
				tickUpper:      887220, // closest valid multiple of 60 to MAX_TICK
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "6123830707127201836443",
			expectedAmount0:   "1",
			expectedAmount1:   "0",
		},
		{
			name: "1% pool - valid near MAX_TICK",
			params: MintParams{
				token0:         "gno.land/r/onbloc/bar",
				token1:         "gno.land/r/onbloc/baz",
				fee:            10000,
				tickLower:      887000,
				tickUpper:      887200, // closest valid multiple of 200 to MAX_TICK
				amount0Desired: u256.MustFromDecimal("1"),
				amount1Desired: u256.MustFromDecimal("1"),
				amount0Min:     u256.MustFromDecimal("0"),
				amount1Min:     u256.MustFromDecimal("0"),
				caller:         alice,
				mintTo:         alice,
			},
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1828894091554004031808",
			expectedAmount0:   "1",
			expectedAmount1:   "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFeeByAdmin(cross, 0)
			CreatePool(t, tt.params.token0, tt.params.token1, tt.params.fee, "79228162514264337593543950336", adminAddr)

			TokenFaucet(t, tt.params.token0, alice)
			TokenFaucet(t, tt.params.token1, alice)

			testing.SetRealm(posRealm)
			TokenApprove(t, tt.params.token0, alice, poolAddr, maxApprove)
			TokenApprove(t, tt.params.token1, alice, poolAddr, maxApprove)

			bar.Approve(cross, poolAddr, maxApprove)
			baz.Approve(cross, poolAddr, maxApprove)

			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedMsg, func() {
					mint(tt.params)
				})
			} else {
				id, liquidity, amount0, amount1 := mint(tt.params)
				println("id:", id)
				uassert.Equal(t, tt.expectedId, id)
				uassert.Equal(t, tt.expectedLiquidity, liquidity.ToString())
				uassert.Equal(t, tt.expectedAmount0, amount0.ToString())
				uassert.Equal(t, tt.expectedAmount1, amount1.ToString())
			}
		})
	}
}
