package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
)

// TODO: Unify the test abstractions into a single file

// Position Strategy Constants - Representing real LP strategies
const (
	// Tick ranges for different LP strategies
	CONCENTRATED_LOWER = int32(-100) // Tight range for concentrated liquidity
	CONCENTRATED_UPPER = int32(100)

	MODERATE_LOWER = int32(-500) // Moderate range for balanced strategy
	MODERATE_UPPER = int32(500)

	WIDE_LOWER = int32(-2000) // Wide range for conservative strategy
	WIDE_UPPER = int32(2000)

	// Liquidity amounts representing different LP sizes
	DUST_LIQUIDITY  = "100"         // Minimum position size
	WHALE_LIQUIDITY = "10000000000" // Whale position

	// Fee growth scenarios (in X128 format)
	NO_FEE_GROWTH     = "0"
	LOW_FEE_GROWTH    = "1000000"     // Low trading activity
	MEDIUM_FEE_GROWTH = "100000000"   // Normal trading activity
	HIGH_FEE_GROWTH   = "10000000000" // High trading activity

	// Common test addresses
	LP_ALICE = "alice_lp_address"
	LP_BOB   = "bob_lp_address"
	LP_WHALE = "whale_lp_address"
)

// Test scenario structures for better organization
type PositionScenario struct {
	name             string
	description      string
	owner            std.Address
	tickLower        int32
	tickUpper        int32
	liquidity        string
	strategy         string // "concentrated", "moderate", "wide", "full-range"
	expectedBehavior string
}

type LiquidityUpdateScenario struct {
	name             string
	description      string
	initialLiquidity string
	liquidityDelta   string
	feeGrowthToken0  string
	feeGrowthToken1  string
	expectedOutcome  string
	businessContext  string
}

type FeeCollectionScenario struct {
	name                string
	description         string
	positionLiquidity   string
	tradingVolume       string // Represents fee generation level
	timeElapsed         int64
	expectedFeeLevel    string // "none", "low", "medium", "high"
	businessImplication string
}

type PositionModificationScenario struct {
	name           string
	description    string
	action         string // "add", "remove", "compound"
	priceMovement  string // "none", "up", "down", "volatile"
	expectedImpact string
	riskAssessment string
}

// setupTestPool creates a pool with specified parameters for testing
func setupTestPool(t *testing.T, token0, token1 string, fee uint32, sqrtPrice string) *Pool {
	t.Helper()

	tickSpacing := GetFeeAmountTickSpacing(fee)
	poolParams := newPoolParams(token0, token1, fee, sqrtPrice, tickSpacing)
	return newPool(poolParams)
}

// setupPoolAtPrice creates a pool at a specific tick price
func setupPoolAtPrice(t *testing.T, tick int32) *Pool {
	t.Helper()

	sqrtPrice := common.TickMathGetSqrtRatioAtTick(tick).ToString()
	return setupTestPool(t, barPath, fooPath, FeeTier500, sqrtPrice)
}

// createPositionWithValidation creates a position and validates the output
func createPositionWithValidation(t *testing.T, pool *Pool, scenario PositionScenario) (positionKey string, amount0, amount1 *u256.Uint) {
	t.Helper()

	// Get position key
	positionKey, err := getPositionKey(scenario.owner, scenario.tickLower, scenario.tickUpper)
	if err != nil {
		t.Fatalf("Failed to get position key: %v", err)
	}

	// Create position through modifyPosition
	liquidityDelta := i256.MustFromDecimal(scenario.liquidity)
	params := ModifyPositionParams{
		owner:          scenario.owner,
		tickLower:      scenario.tickLower,
		tickUpper:      scenario.tickUpper,
		liquidityDelta: liquidityDelta,
	}

	_, amount0, amount1, err = pool.modifyPosition(params)
	if err != nil {
		t.Fatalf("Failed to create position: %v", err)
	}

	// Validate position was created
	positionValue, exists := pool.positions.Get(positionKey)
	if !exists {
		t.Fatalf("Position was not created with key: %s", positionKey)
	}
	position := positionValue.(PositionInfo)

	// Validate liquidity
	if position.liquidity.ToString() != scenario.liquidity {
		t.Errorf("Position liquidity mismatch: expected %s, got %s",
			scenario.liquidity, position.liquidity.ToString())
	}

	return positionKey, amount0, amount1
}

// updatePositionLiquidity modifies an existing position's liquidity
func updatePositionLiquidity(t *testing.T, pool *Pool, owner std.Address, tickLower, tickUpper int32, liquidityDelta string) (amount0, amount1 *u256.Uint) {
	t.Helper()

	delta := i256.MustFromDecimal(liquidityDelta)
	params := ModifyPositionParams{
		owner:          owner,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		liquidityDelta: delta,
	}

	_, amount0, amount1, err := pool.modifyPosition(params)
	if err != nil {
		t.Fatalf("Failed to update position liquidity: %v", err)
	}

	return amount0, amount1
}

// simulateFeeGrowth updates the pool's fee growth globals to simulate trading activity
func simulateFeeGrowth(t *testing.T, pool *Pool, feeGrowth0, feeGrowth1 string) {
	t.Helper()

	pool.feeGrowthGlobal0X128 = u256.MustFromDecimal(feeGrowth0)
	pool.feeGrowthGlobal1X128 = u256.MustFromDecimal(feeGrowth1)
}

// validatePositionFees checks if position has accumulated expected fees
func validatePositionFees(t *testing.T, position PositionInfo, expectedLevel string) {
	t.Helper()

	hasToken0Fees := position.tokensOwed0.Gt(u256.Zero())
	hasToken1Fees := position.tokensOwed1.Gt(u256.Zero())

	switch expectedLevel {
	case "none":
		if hasToken0Fees || hasToken1Fees {
			t.Errorf("Expected no fees but found token0: %s, token1: %s",
				position.tokensOwed0.ToString(), position.tokensOwed1.ToString())
		}
	case "low", "medium", "high":
		if !hasToken0Fees && !hasToken1Fees {
			t.Errorf("Expected %s fees but found none", expectedLevel)
		}
	}
}

// assertPositionInvariants validates that position maintains expected invariants
func assertPositionInvariants(t *testing.T, position PositionInfo) {
	t.Helper()

	// Liquidity should never be negative (represented as uint)
	if position.liquidity.Lt(u256.Zero()) {
		t.Error("Position liquidity is negative")
	}

	// Fee growth inside should be monotonically increasing
	if position.feeGrowthInside0LastX128.Lt(u256.Zero()) ||
		position.feeGrowthInside1LastX128.Lt(u256.Zero()) {
		t.Error("Fee growth inside values are negative")
	}

	// Tokens owed should never be negative
	if position.tokensOwed0.Lt(u256.Zero()) || position.tokensOwed1.Lt(u256.Zero()) {
		t.Error("Tokens owed values are negative")
	}
}

func TestPositionGetKey(t *testing.T) {
	invalidAddr := std.Address("invalidAddr")
	validAddr := testutils.TestAddress("validAddr")

	tests := []struct {
		owner       std.Address
		tickLower   int32
		tickUpper   int32
		shouldError bool
		errorMsg    string
		expectedKey string
	}{
		{invalidAddr, 100, 200, true, `[GNOSWAP-POOL-023] invalid address || owner(invalidAddr) is invalid`, ""},                                    // invalid address
		{validAddr, 200, 100, true, `[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(200), tickUpper(100)`, ""},     // tickLower > tickUpper
		{validAddr, -100, -200, true, `[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(-100), tickUpper(-200)`, ""}, // tickLower > tickUpper
		{validAddr, 100, 100, true, "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(100), tickUpper(100)", ""},     // tickLower == tickUpper
		{validAddr, 100, 200, false, "", "ZzF3ZXNrYzZ0eWc5anhndWpsdGEwNDdoNmx0YTA0N2g2bGRqbHVkdV9fMTAwX18yMDA="},                                    // tickLower < tickUpper
	}

	for _, tc := range tests {
		key, err := getPositionKey(tc.owner, tc.tickLower, tc.tickUpper)
		if err != nil {
			uassert.Equal(t, tc.errorMsg, err.Error())
		} else {
			uassert.Equal(t, tc.expectedKey, key)
		}
	}
}

func TestPositionUpdateWithKey(t *testing.T) {
	var dummyPool *Pool
	var positionKey string

	t.Run("set up initial data for this test function", func(t *testing.T) {
		poolParams := newPoolParams(
			"token0",
			"token1",
			100,
			common.TickMathGetSqrtRatioAtTick(0).ToString(),
			GetFeeAmountTickSpacing(100),
		)
		dummyPool = newPool(poolParams)

		positionKey, _ = getPositionKey(
			testutils.TestAddress("dummyAddr"),
			100,
			200,
		)
	})

	tests := []struct {
		liquidity         *i256.Int
		amount0           *u256.Uint
		amount1           *u256.Uint
		shouldError       bool
		errorMsg          string
		expectedLiquidity string
	}{
		{i256.MustFromDecimal("0"), u256.Zero(), u256.Zero(), true, `[GNOSWAP-POOL-010] zero liquidity || both liquidityDelta and current position's liquidity are zero`, ""},
		{i256.MustFromDecimal("100000"), u256.Zero(), u256.Zero(), false, "", "100000"},
	}

	for _, tc := range tests {
		newPos, err := dummyPool.positionUpdateWithKey(positionKey, tc.liquidity, tc.amount0, tc.amount1)
		if err != nil {
			uassert.Equal(t, tc.errorMsg, err.Error())
		} else {
			uassert.Equal(t, newPos.liquidity.ToString(), tc.expectedLiquidity)
		}
	}
}

func TestPositionUpdate(t *testing.T) {
	tests := []struct {
		initialLiquidity             *u256.Uint
		liquidityDelta               *i256.Int
		feeGrowthInside0X128         *u256.Uint
		feeGrowthInside1X128         *u256.Uint
		shouldError                  bool
		errorMsg                     string
		expectedLiquidity            string
		expectedFeeGrowthInside0X128 string
		expectedFeeGrowthInside1X128 string
		expectedToken0Owed           string
		expectedToken1Owed           string
	}{
		{
			initialLiquidity:     u256.Zero(),
			liquidityDelta:       i256.MustFromDecimal("0"),
			feeGrowthInside0X128: u256.Zero(),
			feeGrowthInside1X128: u256.Zero(),
			shouldError:          true,
			errorMsg:             `[GNOSWAP-POOL-010] zero liquidity || both liquidityDelta and current position's liquidity are zero`,
		},
		{
			initialLiquidity:             u256.Zero(),
			liquidityDelta:               i256.MustFromDecimal("100000"),
			feeGrowthInside0X128:         u256.Zero(),
			feeGrowthInside1X128:         u256.Zero(),
			expectedLiquidity:            "100000",
			expectedFeeGrowthInside0X128: "0",
			expectedFeeGrowthInside1X128: "0",
			expectedToken0Owed:           "0",
			expectedToken1Owed:           "0",
		},
		{
			initialLiquidity:             u256.Zero(),
			liquidityDelta:               i256.MustFromDecimal("100000"),
			feeGrowthInside0X128:         u256.MustFromDecimal("100000000"),
			feeGrowthInside1X128:         u256.MustFromDecimal("100000000"),
			expectedLiquidity:            "100000",
			expectedFeeGrowthInside0X128: "100000000",
			expectedFeeGrowthInside1X128: "100000000",
			expectedToken0Owed:           "0",
			expectedToken1Owed:           "0",
		},
		{
			initialLiquidity:             u256.NewUint(100000),
			liquidityDelta:               i256.MustFromDecimal("100000"),
			feeGrowthInside0X128:         u256.MustFromDecimal("100000000"),
			feeGrowthInside1X128:         u256.MustFromDecimal("100000000"),
			expectedLiquidity:            "200000",
			expectedFeeGrowthInside0X128: "100000000",
			expectedFeeGrowthInside1X128: "100000000",
			expectedToken0Owed:           "0",
			expectedToken1Owed:           "0",
		},
		{
			initialLiquidity:             u256.MustFromDecimal("340282366920938463463374607431768211456"), // Q128 value
			liquidityDelta:               i256.Zero(),
			feeGrowthInside0X128:         u256.MustFromDecimal("100000000"),
			feeGrowthInside1X128:         u256.MustFromDecimal("200000000"),
			expectedLiquidity:            "340282366920938463463374607431768211456",
			expectedFeeGrowthInside0X128: "100000000",
			expectedFeeGrowthInside1X128: "200000000",
			expectedToken0Owed:           "100000000",
			expectedToken1Owed:           "200000000",
		},
	}

	for _, tc := range tests {
		position := PositionInfo{
			liquidity: tc.initialLiquidity,
		}

		newPos, err := positionUpdate(position, tc.liquidityDelta, tc.feeGrowthInside0X128, tc.feeGrowthInside1X128)
		if err != nil {
			uassert.Equal(t, tc.errorMsg, err.Error())
		} else {
			uassert.Equal(t, newPos.liquidity.ToString(), tc.expectedLiquidity)
			uassert.Equal(t, newPos.feeGrowthInside0LastX128.ToString(), tc.expectedFeeGrowthInside0X128)
			uassert.Equal(t, newPos.feeGrowthInside1LastX128.ToString(), tc.expectedFeeGrowthInside1X128)
			uassert.Equal(t, newPos.tokensOwed0.ToString(), tc.expectedToken0Owed)
			uassert.Equal(t, newPos.tokensOwed1.ToString(), tc.expectedToken1Owed)
		}
	}
}

func TestPositionUpdateNegativeValues(t *testing.T) {
	tests := []struct {
		name                  string
		initialLiquidity      *u256.Uint
		liquidityDelta        *i256.Int
		feeGrowthInside0X128  *u256.Uint
		feeGrowthInside1X128  *u256.Uint
		initialFeeGrowth0Last *u256.Uint
		initialFeeGrowth1Last *u256.Uint
		shouldError           bool
		errorMsg              string
	}{
		{
			name:                  "FeeGrowthInside less than Last",
			initialLiquidity:      u256.MustFromDecimal("1000"),
			liquidityDelta:        i256.Zero(),
			feeGrowthInside0X128:  u256.MustFromDecimal("50"),
			feeGrowthInside1X128:  u256.MustFromDecimal("50"),
			initialFeeGrowth0Last: u256.MustFromDecimal("100"),
			initialFeeGrowth1Last: u256.MustFromDecimal("100"),
			shouldError:           false,
		},
		{
			name:                  "Negative Liquidity Delta",
			initialLiquidity:      u256.MustFromDecimal("1000"),
			liquidityDelta:        i256.MustFromDecimal("-2000"),
			feeGrowthInside0X128:  u256.MustFromDecimal("100"),
			feeGrowthInside1X128:  u256.MustFromDecimal("100"),
			initialFeeGrowth0Last: u256.MustFromDecimal("50"),
			initialFeeGrowth1Last: u256.MustFromDecimal("50"),
			shouldError:           true,
			errorMsg:              "[GNOSWAP-POOL-010] zero liquidity || liquidity delta(-2000) is greater than current liquidity(1000)",
		},
		{
			name:                  "Zero Values",
			initialLiquidity:      u256.Zero(),
			liquidityDelta:        i256.Zero(),
			feeGrowthInside0X128:  u256.Zero(),
			feeGrowthInside1X128:  u256.Zero(),
			initialFeeGrowth0Last: u256.Zero(),
			initialFeeGrowth1Last: u256.Zero(),
			shouldError:           true,
			errorMsg:              "[GNOSWAP-POOL-010] zero liquidity || both liquidityDelta and current position's liquidity are zero",
		},
		{
			name:                  "Large Fee Growth Values",
			initialLiquidity:      u256.MustFromDecimal("1000"),
			liquidityDelta:        i256.Zero(),
			feeGrowthInside0X128:  u256.MustFromDecimal("340282366920938463463374607431768211456"), // Q128
			feeGrowthInside1X128:  u256.MustFromDecimal("340282366920938463463374607431768211456"), // Q128
			initialFeeGrowth0Last: u256.MustFromDecimal("100"),
			initialFeeGrowth1Last: u256.MustFromDecimal("100"),
			shouldError:           false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			position := PositionInfo{
				liquidity:                tt.initialLiquidity,
				feeGrowthInside0LastX128: tt.initialFeeGrowth0Last,
				feeGrowthInside1LastX128: tt.initialFeeGrowth1Last,
				tokensOwed0:              u256.Zero(),
				tokensOwed1:              u256.Zero(),
			}

			result, err := positionUpdate(position, tt.liquidityDelta, tt.feeGrowthInside0X128, tt.feeGrowthInside1X128)
			if err != nil {
				uassert.Equal(t, tt.errorMsg, err.Error())
			} else {
				if result.tokensOwed0.Lt(u256.Zero()) || result.tokensOwed1.Lt(u256.Zero()) {
					t.Errorf("result contains negative values: tokensOwed0=%v, tokensOwed1=%v",
						result.tokensOwed0, result.tokensOwed1)
				}
				if result.liquidity.Lt(u256.Zero()) {
					t.Errorf("liquidity is negative: %v", result.liquidity)
				}
			}
		})
	}
}

func TestModifyPosition(t *testing.T) {
	const (
		fee500              = uint32(500)
		test_liquidityDelta = int64(100000000)
	)

	tests := []struct {
		name         string
		sqrtPrice    string
		tickLower    int32
		tickUpper    int32
		expectedAmt0 string
		expectedAmt1 string
	}{
		{
			name:         "current price is lower than range",
			sqrtPrice:    common.TickMathGetSqrtRatioAtTick(-12000).ToString(),
			tickLower:    -11000,
			tickUpper:    -9000,
			expectedAmt0: "16492846",
			expectedAmt1: "0",
		},
		{
			name:         "current price is in range",
			sqrtPrice:    common.TickMathGetSqrtRatioAtTick(-10000).ToString(),
			tickLower:    -11000,
			tickUpper:    -9000,
			expectedAmt0: "8040316",
			expectedAmt1: "2958015",
		},
		{
			name:         "current price is higher than range",
			sqrtPrice:    common.TickMathGetSqrtRatioAtTick(-8000).ToString(),
			tickLower:    -11000,
			tickUpper:    -9000,
			expectedAmt0: "0",
			expectedAmt1: "6067683",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sqrtPrice := u256.MustFromDecimal(tt.sqrtPrice)
			poolParams := newPoolParams(
				barPath,
				fooPath,
				FeeTier500,
				sqrtPrice.ToString(),
				GetFeeAmountTickSpacing(fee500),
			)
			pool := newPool(poolParams)

			params := ModifyPositionParams{
				owner:          positionAddr,
				tickLower:      tt.tickLower,
				tickUpper:      tt.tickUpper,
				liquidityDelta: new(i256.Int).SetInt64(test_liquidityDelta),
			}

			_, amount0, amount1, _ := pool.modifyPosition(params)

			uassert.Equal(t, amount0.ToString(), tt.expectedAmt0)
			uassert.Equal(t, amount1.ToString(), tt.expectedAmt1)
		})
	}
}

func TestModifyPositionEdgeCases(t *testing.T) {
	const fee500 = uint32(500)
	sqrtPrice := common.TickMathGetSqrtRatioAtTick(-10000).ToString()

	t.Run("liquidityDelta is zero", func(t *testing.T) {
		poolParams := newPoolParams(
			barPath,
			fooPath,
			FeeTier500,
			sqrtPrice,
			GetFeeAmountTickSpacing(fee500),
		)
		pool := newPool(poolParams)
		params := ModifyPositionParams{
			owner:          positionAddr,
			tickLower:      -11000,
			tickUpper:      -9000,
			liquidityDelta: i256.Zero(),
		}

		_, _, _, err := pool.modifyPosition(params)
		uassert.Equal(t, err.Error(), "[GNOSWAP-POOL-010] zero liquidity || both liquidityDelta and current position's liquidity are zero")
	})

	t.Run("liquidityDelta is negative", func(t *testing.T) {
		poolParams := newPoolParams(
			barPath,
			fooPath,
			FeeTier500,
			sqrtPrice,
			GetFeeAmountTickSpacing(fee500),
		)
		pool := newPool(poolParams)
		params := ModifyPositionParams{
			owner:          positionAddr,
			tickLower:      -11000,
			tickUpper:      -9000,
			liquidityDelta: i256.MustFromDecimal("100000000"),
		}
		pool.modifyPosition(params)

		// remove liquidity
		params.liquidityDelta = i256.MustFromDecimal("-100000000")
		_, amount0, amount1, _ := pool.modifyPosition(params)

		// remove amount should be same as added amount
		uassert.Equal(t, amount0.ToString(), "8040315")
		uassert.Equal(t, amount1.ToString(), "2958014")
	})
}

func TestAssertTickLowerLessThanUpper(t *testing.T) {
	tests := []struct {
		name        string
		tickLower   int32
		tickUpper   int32
		shouldPanic bool
		expected    string
	}{
		{
			name:        "tickLower is less than tickUpper",
			tickLower:   -100,
			tickUpper:   100,
			shouldPanic: false,
			expected:    "",
		},
		{
			name:        "tickLower equals tickUpper",
			tickLower:   50,
			tickUpper:   50,
			shouldPanic: true,
			expected:    "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(50), tickUpper(50)",
		},
		{
			name:        "tickLower greater than tickUpper",
			tickLower:   200,
			tickUpper:   100,
			shouldPanic: true,
			expected:    "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(200), tickUpper(100)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expected, func() {
					assertIsValidTicks(tt.tickLower, tt.tickUpper)
				})
			} else {
				assertIsValidTicks(tt.tickLower, tt.tickUpper)
			}
		})
	}
}
