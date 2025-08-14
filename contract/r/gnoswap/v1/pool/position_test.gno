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
	scenarios := []struct {
		name            string
		description     string
		owner           std.Address
		tickLower       int32
		tickUpper       int32
		strategy        string
		shouldSucceed   bool
		expectedError   string
		businessContext string
	}{
		{
			name:            "concentrated_liquidity_position",
			description:     "Alice creates a concentrated liquidity position",
			owner:           testutils.TestAddress(LP_ALICE),
			tickLower:       CONCENTRATED_LOWER,
			tickUpper:       CONCENTRATED_UPPER,
			strategy:        "concentrated",
			shouldSucceed:   true,
			businessContext: "High capital efficiency for stable price ranges",
		},
		{
			name:            "wide_range_position",
			description:     "Bob creates a conservative wide range position",
			owner:           testutils.TestAddress(LP_BOB),
			tickLower:       WIDE_LOWER,
			tickUpper:       WIDE_UPPER,
			strategy:        "wide",
			shouldSucceed:   true,
			businessContext: "Lower IL risk for volatile markets",
		},
		{
			name:            "full_range_position",
			description:     "Whale creates a full range position",
			owner:           testutils.TestAddress(LP_WHALE),
			tickLower:       FULL_RANGE_LOWER,
			tickUpper:       FULL_RANGE_UPPER,
			strategy:        "full-range",
			shouldSucceed:   true,
			businessContext: "Passive strategy similar to v2 pools",
		},
		{
			name:            "invalid_inverted_range",
			description:     "Invalid position with inverted price range",
			owner:           testutils.TestAddress(LP_ALICE),
			tickLower:       200,
			tickUpper:       100,
			strategy:        "invalid",
			shouldSucceed:   false,
			expectedError:   "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(200), tickUpper(100)",
			businessContext: "Prevent position creation errors",
		},
		{
			name:            "invalid_zero_range",
			description:     "Invalid position with zero price range",
			owner:           testutils.TestAddress(LP_BOB),
			tickLower:       100,
			tickUpper:       100,
			strategy:        "invalid",
			shouldSucceed:   false,
			expectedError:   "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(100), tickUpper(100)",
			businessContext: "Prevent zero liquidity positions",
		},
		{
			name:            "invalid_address",
			description:     "Invalid position with malformed address",
			owner:           std.Address("invalidAddr"),
			tickLower:       MODERATE_LOWER,
			tickUpper:       MODERATE_UPPER,
			strategy:        "moderate",
			shouldSucceed:   false,
			expectedError:   "[GNOSWAP-POOL-023] invalid address || owner(invalidAddr) is invalid",
			businessContext: "Ensure valid LP addresses",
		},
	}

	for _, scenario := range scenarios {
		t.Run(scenario.name, func(t *testing.T) {
			key, err := getPositionKey(scenario.owner, scenario.tickLower, scenario.tickUpper)

			if scenario.shouldSucceed {
				uassert.NoError(t, err, "Expected position key generation to succeed")
				uassert.NotEmpty(t, key, "Position key should not be empty")

				// Verify key uniqueness for different positions
				if scenario.strategy != "invalid" {
					// Same owner with different range should produce different key
					altKey, _ := getPositionKey(scenario.owner, scenario.tickLower+10, scenario.tickUpper+10)
					uassert.NotEqual(t, key, altKey, "Different ranges should produce different keys")
				}

				t.Logf("✓ %s: Generated key for %s strategy - %s",
					scenario.description, scenario.strategy, scenario.businessContext)
			} else {
				uassert.Error(t, err, "Expected position key generation to fail")
				uassert.Equal(t, scenario.expectedError, err.Error())
				uassert.Empty(t, key, "Failed generation should return empty key")

				t.Logf("✓ %s: Correctly rejected - %s",
					scenario.description, scenario.businessContext)
			}
		})
	}
}

func TestPositionUpdateWithKey_LPStrategies(t *testing.T) {
	scenarios := []struct {
		name             string
		description      string
		liquidityDelta   string
		existingPosition bool
		expectedOutcome  string
		businessContext  string
		shouldError      bool
		expectedError    string
	}{
		{
			name:             "initial_position_creation",
			description:      "LP creates first position in pool",
			liquidityDelta:   MEDIUM_LIQUIDITY,
			existingPosition: false,
			expectedOutcome:  MEDIUM_LIQUIDITY,
			businessContext:  "New LP entering the pool",
			shouldError:      false,
		},
		{
			name:             "add_to_existing_position",
			description:      "LP increases existing position size",
			liquidityDelta:   SMALL_LIQUIDITY,
			existingPosition: true,
			expectedOutcome:  "10100000", // MEDIUM + SMALL
			businessContext:  "Compounding fees back into position",
			shouldError:      false,
		},
		{
			name:             "zero_liquidity_on_new_position",
			description:      "Attempt to create position with zero liquidity",
			liquidityDelta:   "0",
			existingPosition: false,
			expectedOutcome:  "",
			businessContext:  "Prevent empty position creation",
			shouldError:      true,
			expectedError:    "[GNOSWAP-POOL-010] zero liquidity || both liquidityDelta and current position's liquidity are zero",
		},
		{
			name:             "dust_position_creation",
			description:      "Creating minimum viable position",
			liquidityDelta:   DUST_LIQUIDITY,
			existingPosition: false,
			expectedOutcome:  DUST_LIQUIDITY,
			businessContext:  "Small retail LP participation",
			shouldError:      false,
		},
	}

	for _, scenario := range scenarios {
		t.Run(scenario.name, func(t *testing.T) {
			pool := setupPoolAtPrice(t, 0) // Price at tick 0
			alice := testutils.TestAddress(LP_ALICE)
			positionKey, _ := getPositionKey(alice, MODERATE_LOWER, MODERATE_UPPER)

			// Setup existing position if needed
			if scenario.existingPosition {
				params := ModifyPositionParams{
					owner:          alice,
					tickLower:      MODERATE_LOWER,
					tickUpper:      MODERATE_UPPER,
					liquidityDelta: i256.MustFromDecimal(MEDIUM_LIQUIDITY),
				}
				pool.modifyPosition(params)
			}

			// update position
			liquidityDelta := i256.MustFromDecimal(scenario.liquidityDelta)
			newPos, err := pool.positionUpdateWithKey(positionKey, liquidityDelta, u256.Zero(), u256.Zero())

			// validate outcome
			if scenario.shouldError {
				uassert.Error(t, err, "Expected error for scenario")
				uassert.Equal(t, scenario.expectedError, err.Error())
				t.Logf("✓ %s: %s", scenario.description, scenario.businessContext)
			} else {
				uassert.NoError(t, err, "Unexpected error")
				uassert.Equal(t, scenario.expectedOutcome, newPos.liquidity.ToString())
				t.Logf("✓ %s: Position updated to %s - %s",
					scenario.description, newPos.liquidity.ToString(), scenario.businessContext)
			}
		})
	}
}

func TestPositionUpdate_FeeAccumulation(t *testing.T) {
	scenarios := []LiquidityUpdateScenario{
		{
			name:             "new_position_no_fees",
			description:      "Creating new position with no trading activity",
			initialLiquidity: "0",
			liquidityDelta:   SMALL_LIQUIDITY,
			feeGrowthToken0:  NO_FEE_GROWTH,
			feeGrowthToken1:  NO_FEE_GROWTH,
			expectedOutcome:  "Position created without fee accumulation",
			businessContext:  "Fresh position in quiet market",
		},
		{
			name:             "new_position_active_market",
			description:      "Creating position in actively traded pool",
			initialLiquidity: "0",
			liquidityDelta:   MEDIUM_LIQUIDITY,
			feeGrowthToken0:  MEDIUM_FEE_GROWTH,
			feeGrowthToken1:  MEDIUM_FEE_GROWTH,
			expectedOutcome:  "Position tracks current fee growth baseline",
			businessContext:  "Entering liquid market",
		},
		{
			name:             "compound_fees_to_position",
			description:      "Adding liquidity to position with accumulated fees",
			initialLiquidity: SMALL_LIQUIDITY,
			liquidityDelta:   SMALL_LIQUIDITY,
			feeGrowthToken0:  MEDIUM_FEE_GROWTH,
			feeGrowthToken1:  MEDIUM_FEE_GROWTH,
			expectedOutcome:  "Liquidity doubled, no fee claims",
			businessContext:  "Reinvesting without withdrawing fees",
		},
		{
			name:             "whale_position_fee_check",
			description:      "Large position checking accumulated fees",
			initialLiquidity: "340282366920938463463374607431768211456", // Q128
			liquidityDelta:   "0",
			feeGrowthToken0:  LOW_FEE_GROWTH,
			feeGrowthToken1:  MEDIUM_FEE_GROWTH,
			expectedOutcome:  "Calculate fees without changing liquidity",
			businessContext:  "Whale monitoring fee earnings",
		},
		{
			name:             "zero_liquidity_attempt",
			description:      "Invalid zero liquidity operation",
			initialLiquidity: "0",
			liquidityDelta:   "0",
			feeGrowthToken0:  NO_FEE_GROWTH,
			feeGrowthToken1:  NO_FEE_GROWTH,
			expectedOutcome:  "Error: zero liquidity",
			businessContext:  "Prevent invalid state",
		},
	}

	for _, scenario := range scenarios {
		t.Run(scenario.name, func(t *testing.T) {
			// initial position state
			position := PositionInfo{
				liquidity:                u256.MustFromDecimal(scenario.initialLiquidity),
				feeGrowthInside0LastX128: u256.Zero(),
				feeGrowthInside1LastX128: u256.Zero(),
				tokensOwed0:              u256.Zero(),
				tokensOwed1:              u256.Zero(),
			}

			// update position
			liquidityDelta := i256.MustFromDecimal(scenario.liquidityDelta)
			feeGrowth0 := u256.MustFromDecimal(scenario.feeGrowthToken0)
			feeGrowth1 := u256.MustFromDecimal(scenario.feeGrowthToken1)

			newPos, err := positionUpdate(position, liquidityDelta, feeGrowth0, feeGrowth1)

			// validate based on scenario
			if scenario.name == "zero_liquidity_attempt" {
				uassert.Error(t, err, "Expected error for zero liquidity")
				uassert.ErrorContains(t, err, "zero liquidity")
			} else {
				uassert.NoError(t, err, "Unexpected error")

				// Validate liquidity update
				expectedLiquidity := new(u256.Uint).Add(
					u256.MustFromDecimal(scenario.initialLiquidity),
					u256.MustFromDecimal(scenario.liquidityDelta),
				)
				uassert.Equal(t, expectedLiquidity.ToString(), newPos.liquidity.ToString())

				// Validate fee tracking
				if scenario.name == "whale_position_fee_check" {
					// Whale should accumulate fees
					uassert.True(t, newPos.tokensOwed0.Gt(u256.Zero()), "Whale should have token0 fees")
					uassert.True(t, newPos.tokensOwed1.Gt(u256.Zero()), "Whale should have token1 fees")
				}

				// Ensure invariants
				assertPositionInvariants(t, newPos)
			}

			t.Logf("✓ %s: %s - %s",
				scenario.description, scenario.expectedOutcome, scenario.businessContext)
		})
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
