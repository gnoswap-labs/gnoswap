package v1

import (
	"chain"
	"chain/banker"
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
)

const (
	// Swap amounts with business context
	DUST_SWAP_AMOUNT    = "100"       // Dust level swap
	SMALL_SWAP_AMOUNT   = "1000"      // Small swap
	MEDIUM_SWAP_AMOUNT  = "10000"     // Medium scale swap
	LARGE_SWAP_AMOUNT   = "1000000"   // Large scale swap
	EXTREME_SWAP_AMOUNT = "100000000" // Extreme large scale swap

	// Price limits for different scenarios
	MAX_PRICE_IMPACT = "79228162514264337593543950337" // Maximum price impact
	MIN_PRICE_IMPACT = "79228162514264337593543950335" // Minimum price impact

	// Fee scenarios
	ULTRA_LOW_FEE_TIER = FeeTier100   // 0.01% (Stablecoin)
	LOW_FEE_TIER       = FeeTier500   // 0.05% (Highly correlated token)
	STANDARD_FEE_TIER  = FeeTier3000  // 0.3% (General token)
	HIGH_FEE_TIER      = FeeTier10000 // 1% (High volatility token)
)

// Swap scenario structs
type SwapScenario struct {
	name             string
	description      string
	zeroForOne       bool
	amountSpecified  string
	priceLimit       string
	expectedBehavior string
	marketContext    string
}

type SwapValidationTest struct {
	name           string
	description    string
	setupCondition func(t *testing.T) *pl.Pool
	swapParams     SwapScenario
	expectSuccess  bool
	expectedError  string
	riskFactor     string
}

func TestProtocolFees_ManagementAndCollection(t *testing.T) {
	feeManagementTests := []struct {
		name              string
		description       string
		initialFees       map[string]string // token0, token1
		deductionAmount   map[string]string
		expectedRemaining map[string]string
		expectedDeducted  map[string]string
		businessImpact    string
	}{
		{
			name:              "normal_fee_deduction_scenario",
			description:       "Normal protocol fee deduction",
			initialFees:       map[string]string{"token0": "1000", "token1": "2000"},
			deductionAmount:   map[string]string{"token0": "500", "token1": "1000"},
			expectedRemaining: map[string]string{"token0": "500", "token1": "1000"},
			expectedDeducted:  map[string]string{"token0": "500", "token1": "1000"},
			businessImpact:    "Realize part of protocol revenue",
		},
		{
			name:              "near_complete_fee_extraction",
			description:       "Almost all fees extracted (1 left)",
			initialFees:       map[string]string{"token0": "1000", "token1": "2000"},
			deductionAmount:   map[string]string{"token0": "999", "token1": "1999"},
			expectedRemaining: map[string]string{"token0": "1", "token1": "1"},
			expectedDeducted:  map[string]string{"token0": "999", "token1": "1999"},
			businessImpact:    "Maximize protocol revenue while maintaining system stability",
		},
		{
			name:              "zero_deduction_preservation",
			description:       "Preserve fees without deduction",
			initialFees:       map[string]string{"token0": "1000", "token1": "2000"},
			deductionAmount:   map[string]string{"token0": "0", "token1": "0"},
			expectedRemaining: map[string]string{"token0": "1000", "token1": "2000"},
			expectedDeducted:  map[string]string{"token0": "0", "token1": "0"},
			businessImpact:    "Preserve fees for future protocol development",
		},
	}

	for _, test := range feeManagementTests {
		t.Run(test.name, func(t *testing.T) {
			// Given: Specific protocol fee state
			pool := &pl.Pool{}
			protocolFees := pl.ProtocolFees{}
			protocolFees.SetToken0(u256.MustFromDecimal(test.initialFees["token0"]))
			protocolFees.SetToken1(u256.MustFromDecimal(test.initialFees["token1"]))
			pool.SetProtocolFees(protocolFees)

			deductAmount0 := u256.MustFromDecimal(test.deductionAmount["token0"])
			deductAmount1 := u256.MustFromDecimal(test.deductionAmount["token1"])

			// When: Execute protocol fee deduction
			actualDeducted0, actualDeducted1 := mockInstance.saveProtocolFees(pool, deductAmount0, deductAmount1)

			// Then: Verify expected deduction and remaining balance
			expectedDeducted0 := u256.MustFromDecimal(test.expectedDeducted["token0"])
			expectedDeducted1 := u256.MustFromDecimal(test.expectedDeducted["token1"])
			expectedRemaining0 := u256.MustFromDecimal(test.expectedRemaining["token0"])
			expectedRemaining1 := u256.MustFromDecimal(test.expectedRemaining["token1"])

			uassert.Equal(t, expectedDeducted0.ToString(), actualDeducted0.ToString(),
				"Token0 deduction amount is different from expected")
			uassert.Equal(t, expectedDeducted1.ToString(), actualDeducted1.ToString(),
				"Token1 deduction amount is different from expected")
			uassert.Equal(t, expectedRemaining0.ToString(), pool.ProtocolFeesToken0().ToString(),
				"Token0 remaining fee is different from expected")
			uassert.Equal(t, expectedRemaining1.ToString(), pool.ProtocolFeesToken1().ToString(),
				"Token1 remaining fee is different from expected")

			t.Logf("✓ %s: %s", test.description, test.businessImpact)
		})
	}
}

func TestSwapContinuation_DecisionLogic(t *testing.T) {
	continuationTests := []struct {
		name            string
		description     string
		remainingAmount string
		currentPrice    string
		priceLimit      string
		shouldContinue  bool
		tradingContext  string
	}{
		{
			name:            "active_trading_continuation",
			description:     "Swap continues in active trading",
			remainingAmount: "1000",
			currentPrice:    "1000000",
			priceLimit:      "900000",
			shouldContinue:  true,
			tradingContext:  "Market liquidity is sufficient and price impact is within acceptable range",
		},
		{
			name:            "amount_exhausted_termination",
			description:     "Termination due to swap amount exhaustion",
			remainingAmount: "0",
			currentPrice:    "1000000",
			priceLimit:      "900000",
			shouldContinue:  false,
			tradingContext:  "Requested swap is fully executed and no further progress is needed",
		},
		{
			name:            "price_limit_reached_protection",
			description:     "Protection termination due to price limit reached",
			remainingAmount: "1000",
			currentPrice:    "900000",
			priceLimit:      "900000",
			shouldContinue:  false,
			tradingContext:  "Slippage protection device prevents additional price deterioration",
		},
	}

	for _, test := range continuationTests {
		t.Run(test.name, func(t *testing.T) {
			// Given: Specific swap state
			state := SwapState{
				amountSpecifiedRemaining: i256.MustFromDecimal(test.remainingAmount),
				sqrtPriceX96:             u256.MustFromDecimal(test.currentPrice),
				liquidity:                u256.MustFromDecimal("1000000"),
			}
			priceLimit := u256.MustFromDecimal(test.priceLimit)

			// When: Determine swap continuation
			shouldContinue := shouldContinueSwap(state, priceLimit)

			// Then: Verify expected decision
			uassert.Equal(t, test.shouldContinue, shouldContinue,
				ufmt.Sprintf("Swap continuation decision error: %s", test.description))

			t.Logf("✓ %s: %s (Decision: %v)", test.description, test.tradingContext, shouldContinue)
		})
	}
}

func TestSwapAmounts_UpdateMechanics(t *testing.T) {
	updateTests := []struct {
		name               string
		description        string
		isExactInput       bool
		stepAmountIn       string
		stepAmountOut      string
		stepFeeAmount      string
		initialRemaining   string
		initialCalculated  string
		expectedRemaining  string
		expectedCalculated string
		tradingPattern     string
	}{
		{
			name:               "exact_input_normal_trade",
			description:        "Normal trade with exact input",
			isExactInput:       true,
			stepAmountIn:       "100",
			stepAmountOut:      "97",
			stepFeeAmount:      "3",
			initialRemaining:   "1000",
			initialCalculated:  "0",
			expectedRemaining:  "897", // 1000 - (100 + 3)
			expectedCalculated: "-97", // Output is recorded as negative
			tradingPattern:     "User specifies exact input amount to maximize output",
		},
		{
			name:               "exact_output_targeted_trade",
			description:        "Targeted trade with exact output",
			isExactInput:       false,
			stepAmountIn:       "100",
			stepAmountOut:      "97",
			stepFeeAmount:      "3",
			initialRemaining:   "-1000",
			initialCalculated:  "0",
			expectedRemaining:  "-903", // -1000 + 97
			expectedCalculated: "103",  // 100 + 3 (input + fee)
			tradingPattern:     "User specifies exact output amount and calculates required input",
		},
	}

	for _, test := range updateTests {
		t.Run(test.name, func(t *testing.T) {
			// Given: Specific swap step calculation result
			step := StepComputations{
				amountIn:  u256.MustFromDecimal(test.stepAmountIn),
				amountOut: u256.MustFromDecimal(test.stepAmountOut),
				feeAmount: u256.MustFromDecimal(test.stepFeeAmount),
			}

			state := SwapState{
				amountSpecifiedRemaining: i256.MustFromDecimal(test.initialRemaining),
				amountCalculated:         i256.MustFromDecimal(test.initialCalculated),
			}

			// When: Execute swap amount update
			updatedState, err := updateAmounts(step, state, test.isExactInput)
			if err != nil {
				t.Fatalf("Unexpected error during swap amount update: %v", err)
			}

			// Then: Verify updated state
			expectedRemaining := i256.MustFromDecimal(test.expectedRemaining)
			expectedCalculated := i256.MustFromDecimal(test.expectedCalculated)

			uassert.True(t, expectedRemaining.Eq(updatedState.amountSpecifiedRemaining),
				ufmt.Sprintf("Remaining amount calculation error: expected(%s) != actual(%s)",
					expectedRemaining.ToString(), updatedState.amountSpecifiedRemaining.ToString()))

			uassert.True(t, expectedCalculated.Eq(updatedState.amountCalculated),
				ufmt.Sprintf("Calculated amount error: expected(%s) != actual(%s)",
					expectedCalculated.ToString(), updatedState.amountCalculated.ToString()))

			t.Logf("✓ %s: %s", test.description, test.tradingPattern)
		})
	}
}

func TestSwapComputation_CoreEngine(t *testing.T) {
	computationTests := []struct {
		name            string
		description     string
		setupPool       func() *pl.Pool
		swapAmount      string
		priceLimit      string
		zeroForOne      bool
		exactInput      bool
		expectedOutcome string
		engineContext   string
	}{
		{
			name:            "basic_swap_computation",
			description:     "Basic swap computation engine verification",
			setupPool:       createMockLiquidityPool,
			swapAmount:      "1000000",
			priceLimit:      "1100000000000000000",
			zeroForOne:      true,
			exactInput:      true,
			expectedOutcome: "Normal swap execution",
			engineContext:   "Standard swap processing in a sufficiently liquid environment",
		},
		{
			name:            "zero_liquidity_edge_case",
			description:     "Edge case with zero liquidity",
			setupPool:       createMockZeroLiquidityPool,
			swapAmount:      "1000000",
			priceLimit:      "1100000000000000000",
			zeroForOne:      true,
			exactInput:      true,
			expectedOutcome: "Swap not possible",
			engineContext:   "Swap failure due to insufficient liquidity (mathematical limit)",
		},
	}

	for _, test := range computationTests {
		t.Run(test.name, func(t *testing.T) {
			// Given: Specific pool state
			mockPool := test.setupPool()

			computation := SwapComputation{
				AmountSpecified:   i256.MustFromDecimal(test.swapAmount),
				SqrtPriceLimitX96: u256.MustFromDecimal(test.priceLimit),
				ZeroForOne:        test.zeroForOne,
				ExactInput:        test.exactInput,
				InitialState: SwapState{
					amountSpecifiedRemaining: i256.MustFromDecimal(test.swapAmount),
					amountCalculated:         i256.Zero(),
					sqrtPriceX96:             mockPool.Slot0SqrtPriceX96(),
					tick:                     mockPool.Slot0Tick(),
					feeGrowthGlobalX128:      mockPool.FeeGrowthGlobal0X128(),
					protocolFee:              u256.Zero(),
					liquidity:                mockPool.Liquidity(),
				},
				Cache: SwapCache{
					feeProtocol:    0,
					liquidityStart: mockPool.Liquidity(),
				},
			}

			// When: Execute swap computation
			result, err := mockInstance.computeSwap(mockPool, computation)
			// Then: Verify computation result
			if err != nil {
				t.Fatalf("Unexpected error during swap computation: %v", err)
			}

			if test.expectedOutcome == "Normal swap execution" {
				uassert.True(t, !result.Amount0.IsZero() || !result.Amount1.IsZero(),
					"In a normal swap, token movement should occur")
			} else if test.expectedOutcome == "Swap not possible" {
				// Verify mathematical result for zero liquidity case
				uassert.True(t, result.Amount0.IsZero(),
					"In zero liquidity case, actual swap is not possible")
			}

			t.Logf("✓ %s: %s", test.description, test.engineContext)
		})
	}
}

func TestDrySwap_ValidationAndFailures(t *testing.T) {
	// Given: Pool setup
	_ = NewPoolTestEnv(t).
		AsAdmin().
		GivenPoolCreated(barTokenPath, bazTokenPath, FeeTier100, EQUAL_PRICE_RATIO)

	defer initPoolTest(t)

	validationTests := []struct {
		name           string
		description    string
		swapBuilder    func() SwapParams
		expectSuccess  bool
		failureReason  string
		riskAssessment string
	}{
		{
			name:        "zero_amount_rejection",
			description: "Reject zero amount swap attempt",
			swapBuilder: func() SwapParams {
				return NewSwapBuilder().
					InPool(barTokenPath, bazTokenPath, FeeTier100).
					SwapToken0For1().
					ExactInput("0").
					WithPriceLimit(MAX_PRICE_IMPACT).
					Build()
			},
			expectSuccess:  false,
			failureReason:  "Prevent gas waste from meaningless trade",
			riskAssessment: "Protect system resources",
		},
		{
			name:        "insufficient_balance_protection",
			description: "Protect against insufficient balance",
			swapBuilder: func() SwapParams {
				return NewSwapBuilder().
					InPool(barTokenPath, bazTokenPath, FeeTier100).
					SwapToken1For0().
					ExactInput("2000000000").
					WithPriceLimit(MAX_PRICE_IMPACT).
					Build()
			},
			expectSuccess:  false,
			failureReason:  "Block transactions exceeding user balance",
			riskAssessment: "Protect user assets and prevent transaction failure",
		},
	}

	for _, test := range validationTests {
		t.Run(test.name, func(t *testing.T) {
			// When: DrySwap for pre-transaction validation using DSL parameters
			swapParams := test.swapBuilder()
			amount0, amount1, success := mockInstance.DrySwap(
				swapParams.token0,
				swapParams.token1,
				swapParams.fee,
				swapParams.zeroForOne,
				swapParams.amountSpecified.ToString(),
				swapParams.sqrtPriceLimitX96.ToString(),
			)

			// Then: Verify expected validation result
			uassert.Equal(t, test.expectSuccess, success,
				ufmt.Sprintf("DrySwap result differs from expected: %s", test.description))

			if !test.expectSuccess {
				uassert.Equal(t, "0", amount0, "In failed swap, token0 movement should be zero")
				uassert.Equal(t, "0", amount1, "In failed swap, token1 movement should be zero")
			}

			t.Logf("✓ %s: %s (Risk assessment: %s)", test.description, test.failureReason, test.riskAssessment)
		})
	}
}

func TestSwap_ExecutionAndSecurity(t *testing.T) {
	securityTests := []SwapValidationTest{
		{
			name:        "locked_pool_protection",
			description: "Block transactions in locked pool",
			setupCondition: func(t *testing.T) *pl.Pool {
				InitialisePoolTest(t)
				pool := mockInstance.mustGetPoolBy(wugnotPath, gnsPath, STANDARD_FEE_TIER)
				slot0 := pool.Slot0()
				slot0.SetUnlocked(false)
				pool.SetSlot0(slot0)
				return pool
			},
			swapParams: SwapScenario{
				zeroForOne:      true,
				amountSpecified: DUST_SWAP_AMOUNT,
				priceLimit:      EQUAL_PRICE_RATIO,
			},
			expectSuccess: false,
			expectedError: "[GNOSWAP-POOL-018] can't swap while pool is locked",
			riskFactor:    "Prevent state inconsistency from concurrent transactions",
		},
		{
			name:        "zero_amount_swap_prevention",
			description: "Prevent meaningless zero swap",
			setupCondition: func(t *testing.T) *pl.Pool {
				InitialisePoolTest(t)
				pool := mockInstance.mustGetPoolBy(wugnotPath, gnsPath, STANDARD_FEE_TIER)
				slot0 := pool.Slot0()
				slot0.SetUnlocked(true)
				pool.SetSlot0(slot0)
				return pool
			},
			swapParams: SwapScenario{
				zeroForOne:      true,
				amountSpecified: "0",
				priceLimit:      EQUAL_PRICE_RATIO,
			},
			expectSuccess: false,
			expectedError: "[GNOSWAP-POOL-015] invalid swap amount || amountSpecified == 0",
			riskFactor:    "Prevent gas waste and system load from meaningless trade",
		},
	}

	for _, test := range securityTests {
		t.Run(test.name, func(t *testing.T) {
			// Initialize test environment
			resetObject(t)
			burnTokens(t)

			// Given: Specific security test condition
			pool := test.setupCondition(t)

			// When & Then: Proper blocking in security risk situations
			testing.SetRealm(rouRealm)

			TokenApprove(t, pool.Token0Path(), routerAddr, poolAddr, maxApprove)
			TokenApprove(t, pool.Token1Path(), routerAddr, poolAddr, maxApprove)

			testing.SetRealm(rouRealm)

			uassert.AbortsWithMessage(t, test.expectedError, func() {
				mockInstance.Swap(pool.Token0Path(), pool.Token1Path(), pool.Fee(),
					alice, test.swapParams.zeroForOne, test.swapParams.amountSpecified,
					test.swapParams.priceLimit, routerAddr,
					func(cur realm, amount0Delta string, amount1Delta string) error {
						return mockSwapCallback(pool.Token0Path(), pool.Token1Path(), amount0Delta, amount1Delta)
					})
			})

			t.Logf("✓ %s: Properly blocked (Risk factor: %s)", test.description, test.riskFactor)
		})
	}
}

func TestSwapConsistency_DryVsActual(t *testing.T) {
	consistencyTests := []struct {
		name            string
		description     string
		setupScenario   func(t *testing.T)
		swapParams      SwapScenario
		consistencyGoal string
	}{
		{
			name:        "normal_trading_consistency",
			description: "Prediction accuracy in normal trading",
			setupScenario: func(t *testing.T) {
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)
				TokenFaucet(t, gnsPath, routerAddr)
				TokenApprove(t, gnsPath, routerAddr, poolAddr, 1000)
			},
			swapParams: SwapScenario{
				zeroForOne:      false,
				amountSpecified: DUST_SWAP_AMOUNT,
				priceLimit:      maxSqrtPriceLimitX96,
			},
			consistencyGoal: "Exact match between DrySwap prediction and actual trading result",
		},
		{
			name:        "large_trade_impact_consistency",
			description: "Prediction of price impact in large trades",
			setupScenario: func(t *testing.T) {
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)
				TokenFaucet(t, gnsPath, routerAddr)
				TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
			},
			swapParams: SwapScenario{
				zeroForOne:      false,
				amountSpecified: EXTREME_SWAP_AMOUNT,
				priceLimit:      maxSqrtPriceLimitX96,
			},
			consistencyGoal: "Accurate prediction of price impact even in large trades",
		},
	}

	for _, test := range consistencyTests {
		t.Run(test.name, func(t *testing.T) {
			// Initialize test environment
			resetObject(t)
			burnTokens(t)

			// Given: Specific trading scenario
			test.setupScenario(t)

			// When: DrySwap for pre-calculation
			dryAmount0, dryAmount1, drySuccess := mockInstance.DrySwap(
				wugnotPath, gnsPath, STANDARD_FEE_TIER,
				test.swapParams.zeroForOne, test.swapParams.amountSpecified,
				test.swapParams.priceLimit)

			// Execute actual swap
			testing.SetRealm(rouRealm)

			TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
			TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)

			testing.SetRealm(rouRealm)

			actualAmount0, actualAmount1 := mockInstance.Swap(wugnotPath, gnsPath, STANDARD_FEE_TIER,
				routerAddr, test.swapParams.zeroForOne, test.swapParams.amountSpecified,
				test.swapParams.priceLimit, routerAddr,
				func(cur realm, amount0Delta string, amount1Delta string) error {
					return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
				})

			// Then: Verify consistency between prediction and actual result
			if !drySuccess {
				t.Error("DrySwap failed but actual Swap succeeded - consistency issue")
			}

			uassert.Equal(t, dryAmount0, actualAmount0,
				"Token0 amount prediction differs from actual")
			uassert.Equal(t, dryAmount1, actualAmount1,
				"Token1 amount prediction differs from actual")

			// Check if it's a meaningful trade
			uassert.True(t, dryAmount0 != "0" || dryAmount1 != "0",
				"In meaningful trade, token movement should occur")

			t.Logf("✓ %s: Prediction(%s/%s) = Actual(%s/%s) - %s",
				test.description, dryAmount0, dryAmount1, actualAmount0, actualAmount1, test.consistencyGoal)
		})
	}
}

func TestSwap_TradingPatterns(t *testing.T) {
	tradingPatterns := []struct {
		name            string
		description     string
		setupLiquidity  func(t *testing.T)
		swapParams      SwapScenario
		expectedAmounts []string
		tradingContext  string
	}{
		{
			name:        "exact_input_token1_purchase",
			description: "Purchase token1 with exact input",
			setupLiquidity: func(t *testing.T) {
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)
				TokenFaucet(t, gnsPath, routerAddr)
				TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
			},
			swapParams: SwapScenario{
				zeroForOne:      false,
				amountSpecified: "200",
				priceLimit:      common.TickMathGetSqrtRatioAtTick(887220).ToString(),
			},
			expectedAmounts: []string{"-198", "200"},
			tradingContext:  "User wants to purchase exactly 200 token1",
		},
		{
			name:        "exact_output_token0_acquisition",
			description: "Acquire token0 with exact output",
			setupLiquidity: func(t *testing.T) {
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)
				TokenFaucet(t, gnsPath, routerAddr)
				TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
			},
			swapParams: SwapScenario{
				zeroForOne:      false,
				amountSpecified: "-200", // Negative for exact output
				priceLimit:      common.TickMathGetSqrtRatioAtTick(887220).ToString(),
			},
			expectedAmounts: []string{"-200", "202"},
			tradingContext:  "User wants to acquire exactly 200 token0",
		},
		{
			name:        "zero_liquidity_graceful_handling",
			description: "Graceful handling of zero liquidity",
			setupLiquidity: func(t *testing.T) {
				InitialisePoolTest(t)
				// MintPositionAll is not called (zero liquidity)
				TokenFaucet(t, wugnotPath, routerAddr)
				TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
			},
			swapParams: SwapScenario{
				zeroForOne:      false,
				amountSpecified: "1000",
				priceLimit:      common.TickMathGetSqrtRatioAtTick(887220).ToString(),
			},
			expectedAmounts: []string{"0", "0"},
			tradingContext:  "Swap attempt in zero liquidity situation",
		},
	}

	for _, pattern := range tradingPatterns {
		t.Run(pattern.name, func(t *testing.T) {
			// Initialize test environment
			resetObject(t)
			burnTokens(t)

			// Given: Specific liquidity and trading conditions
			pattern.setupLiquidity(t)

			// When: Execute swap with specified pattern
			TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
			TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)

			testing.SetRealm(rouRealm)

			actualAmount0, actualAmount1 := mockInstance.Swap(wugnotPath, gnsPath, STANDARD_FEE_TIER,
				alice, pattern.swapParams.zeroForOne, pattern.swapParams.amountSpecified,
				pattern.swapParams.priceLimit, routerAddr,
				func(cur realm, amount0Delta string, amount1Delta string) error {
					return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
				})

			// Then: Verify expected trading result
			uassert.Equal(t, pattern.expectedAmounts[0], actualAmount0,
				"Token0 amount differs from expected")
			uassert.Equal(t, pattern.expectedAmounts[1], actualAmount1,
				"Token1 amount differs from expected")

			t.Logf("✓ %s: Result(%s/%s) - %s",
				pattern.description, actualAmount0, actualAmount1, pattern.tradingContext)
		})
	}
}

func TestSwap_ExtremeMarketConditions(t *testing.T) {
	extremeTests := []struct {
		name           string
		description    string
		setupCondition func(t *testing.T)
		swapParams     SwapScenario
		expectedResult []string
		marketScenario string
	}{
		{
			name:        "scattered_liquidity_navigation",
			description: "Swap handling in scattered liquidity environment",
			setupCondition: func(t *testing.T) {
				setupScatteredLiquidityPool(t)
			},
			swapParams: SwapScenario{
				zeroForOne:      false,
				amountSpecified: "1000",
				priceLimit:      common.TickMathGetSqrtRatioAtTick(11040).ToString(),
			},
			expectedResult: []string{"-2709", "1000"},
			marketScenario: "Inefficient market with liquidity spread across multiple price ranges",
		},
		{
			name:        "extreme_price_range_traversal",
			description: "Traversal of extreme price range",
			setupCondition: func(t *testing.T) {
				setupExtremePriceRangePool(t)
			},
			swapParams: SwapScenario{
				zeroForOne:      true,
				amountSpecified: "1000",
				priceLimit:      common.TickMathGetSqrtRatioAtTick(-100080).ToString(),
			},
			expectedResult: []string{"1000", "-148220"},
			marketScenario: "Large swap in extreme volatility situation",
		},
	}

	for _, test := range extremeTests {
		t.Run(test.name, func(t *testing.T) {
			// Initialize test environment
			resetObject(t)
			burnTokens(t)

			// Given: Extreme market conditions
			test.setupCondition(t)

			// When: Execute swap in extreme conditions
			testing.SetRealm(rouRealm)

			TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
			TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)

			testing.SetRealm(rouRealm)

			actualAmount0, actualAmount1 := mockInstance.Swap(wugnotPath, gnsPath, STANDARD_FEE_TIER,
				alice, test.swapParams.zeroForOne, test.swapParams.amountSpecified,
				test.swapParams.priceLimit, routerAddr,
				func(cur realm, amount0Delta string, amount1Delta string) error {
					return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
				})

			// Then: Verify stable handling in extreme conditions
			uassert.Equal(t, test.expectedResult[0], actualAmount0,
				"Error in token0 calculation in extreme conditions")
			uassert.Equal(t, test.expectedResult[1], actualAmount1,
				"Error in token1 calculation in extreme conditions")

			t.Logf("✓ %s: Safe handling in extreme conditions (%s/%s) - %s",
				test.description, actualAmount0, actualAmount1, test.marketScenario)
		})
	}
}

func TestSwap_FeeTierOptimization(t *testing.T) {
	// Test ultra-low fee tier (stablecoin)
	t.Run("ultra_low_fee_stablecoin_swap", func(t *testing.T) {
		// Given: Ultra-low fee tier stablecoin pool
		resetObject(t)
		setupUltraLowFeePool(t)

		// When: Large stablecoin swap
		testing.SetOriginCaller(routerAddr)

		TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
		TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)

		testing.SetRealm(rouRealm)

		actualAmount0, actualAmount1 := mockInstance.Swap(wugnotPath, gnsPath, ULTRA_LOW_FEE_TIER,
			adminAddr, true, "40012000",
			common.TickMathGetSqrtRatioAtTick(-887220).ToString(), routerAddr,
			func(cur realm, amount0Delta string, amount1Delta string) error {
				return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
			})

		// Then: Verify fee efficiency
		uassert.Equal(t, "100257", actualAmount0, "Token0 calculation in ultra-low fee environment")
		uassert.Equal(t, "-99745", actualAmount1, "Token1 calculation in ultra-low fee environment")

		t.Logf("✓ Ultra-low fee (0.01%) stablecoin swap: Very efficient output ratio compared to input")
	})
}

func createMockLiquidityPool() *pl.Pool {
	pool := makeMockPool(createMockPoolParams{
		token0Path:  "token0",
		token1Path:  "token1",
		fee:         STANDARD_FEE_TIER,
		tickSpacing: 60,
		slot0: struct {
			sqrtPriceX96 *u256.Uint
			tick         int32
			feeProtocol  uint8
			unlocked     bool
		}{
			sqrtPriceX96: common.TickMathGetSqrtRatioAtTick(0),
			tick:         0,
			feeProtocol:  0,
			unlocked:     true,
		},
		liquidity: u256.MustFromDecimal("1000000000000000000"),
		protocolFees: struct {
			token0 *u256.Uint
			token1 *u256.Uint
		}{
			token0: u256.Zero(),
			token1: u256.Zero(),
		},
		feeGrowthGlobal0X128: u256.Zero(),
		feeGrowthGlobal1X128: u256.Zero(),
		tickBitmaps:          avl.NewTree(),
		ticks:                avl.NewTree(),
		positions:            avl.NewTree(),
	})

	wordPos, _ := tickBitmapPosition(0)
	setTickBitmap(pool, wordPos, u256.NewUint(1))
	return pool
}

func createMockZeroLiquidityPool() *pl.Pool {
	pool := createMockLiquidityPool()
	pool.SetLiquidity(u256.Zero()) // Remove liquidity
	return pool
}

func setupScatteredLiquidityPool(t *testing.T) {
	t.Helper()

	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	ugnotFaucet(t, adminAddr, 1_000_000_000_000_000)
	ugnotDeposit(t, adminAddr, 1_000_000_000_000_000)

	TokenApprove(t, wugnotPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(t, gnsPath, adminAddr, poolAddr, maxApprove)

	mockInstance.CreatePool(wugnotPath, gnsPath, STANDARD_FEE_TIER,
		common.TickMathGetSqrtRatioAtTick(-10000).ToString())

	testing.SetRealm(posRealm)
	// 4 dispersed liquidity positions
	mockInstance.Mint(wugnotPath, gnsPath, STANDARD_FEE_TIER, -10020, -9000, "10000000", adminAddr)
	mockInstance.Mint(wugnotPath, gnsPath, STANDARD_FEE_TIER, -4980, -4020, "20000000", adminAddr)
	mockInstance.Mint(wugnotPath, gnsPath, STANDARD_FEE_TIER, 0, 1020, "30000000", adminAddr)
	mockInstance.Mint(wugnotPath, gnsPath, STANDARD_FEE_TIER, 8040, 10020, "40000000", adminAddr)

	// Prepare tokens
	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	TokenFaucet(t, wugnotPath, routerAddr)
	TokenFaucet(t, gnsPath, routerAddr)

	testing.SetOriginCaller(routerAddr)
	testing.SetRealm(testing.NewUserRealm(routerAddr))
	TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
	TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
}

func setupExtremePriceRangePool(t *testing.T) {
	t.Helper()

	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	ugnotFaucet(t, adminAddr, 1_000_000_000_000_000)
	ugnotDeposit(t, adminAddr, 1_000_000_000_000_000)

	TokenApprove(t, wugnotPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(t, gnsPath, adminAddr, poolAddr, maxApprove)

	mockInstance.CreatePool(wugnotPath, gnsPath, STANDARD_FEE_TIER,
		common.TickMathGetSqrtRatioAtTick(100000).ToString())

	testing.SetRealm(posRealm)
	// Extreme range liquidity
	mockInstance.Mint(wugnotPath, gnsPath, STANDARD_FEE_TIER, -100020, -99960, "500000", adminAddr)
	mockInstance.Mint(wugnotPath, gnsPath, STANDARD_FEE_TIER, 99960, 100020, "500000", adminAddr)

	// Prepare tokens
	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	TokenFaucet(t, wugnotPath, routerAddr)
	TokenFaucet(t, gnsPath, routerAddr)

	testing.SetOriginCaller(routerAddr)
	testing.SetRealm(testing.NewUserRealm(routerAddr))
	TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
	TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
}

func TestUpdateAmounts_OverflowProtection(t *testing.T) {
	t.Run("should_prevent_overflow_when_exact_out_calculation_exceeds_max_int64", func(t *testing.T) {
		// An exact out swap where the accumulated amount is near MAX_INT64
		// and the next step would cause overflow
		step := StepComputations{
			amountIn:  u256.MustFromDecimal("1000"),
			amountOut: u256.MustFromDecimal("990"),
			feeAmount: u256.MustFromDecimal("10"),
		}

		state := SwapState{
			amountSpecifiedRemaining: i256.MustFromDecimal("-1000"),
			amountCalculated:         i256.MustFromDecimal("9223372036854775800"), // Near MAX_INT64
		}

		_, err := updateAmounts(step, state, false)

		uassert.ErrorIs(t, err, errOverFlow,
			"Should prevent overflow when amountCalculated would exceed MAX_INT64")
	})

	t.Run("should_allow_exact_out_calculation_within_safe_bounds", func(t *testing.T) {
		stepWithSafeValues := StepComputations{
			amountIn:  u256.MustFromDecimal("1000"),
			amountOut: u256.MustFromDecimal("990"),
			feeAmount: u256.MustFromDecimal("10"),
		}

		state := SwapState{
			amountSpecifiedRemaining: i256.MustFromDecimal("-10000"),
			amountCalculated:         i256.MustFromDecimal("1000000"), // Safe value
		}

		updatedState, err := updateAmounts(stepWithSafeValues, state, false)
		uassert.NoError(t, err, "Should allow calculation within safe bounds")

		expectedRemaining := i256.MustFromDecimal("-9010")    // -10000 + 990
		expectedCalculated := i256.MustFromDecimal("1001010") // 1000000 + 1000 + 10

		uassert.True(t, expectedRemaining.Eq(updatedState.amountSpecifiedRemaining),
			"Should correctly update remaining amount")
		uassert.True(t, expectedCalculated.Eq(updatedState.amountCalculated),
			"Should correctly accumulate calculated amount with fees")
	})

	t.Run("should_prevent_overflow_when_exact_in_calculation_exceeds_bounds", func(t *testing.T) {
		// An exact in swap where output calculation could overflow
		step := StepComputations{
			amountIn:  u256.MustFromDecimal("1000"),
			amountOut: u256.MustFromDecimal("9223372036854775808"), // > MAX_INT64
			feeAmount: u256.MustFromDecimal("10"),
		}

		state := SwapState{
			amountSpecifiedRemaining: i256.MustFromDecimal("10000"),
			amountCalculated:         i256.MustFromDecimal("-1000"),
		}

		_, err := updateAmounts(step, state, true)
		uassert.ErrorIs(t, err, errUnderflow,
			"Should prevent underflow when amountOut exceeds MAX_INT256")
	})

	t.Run("should_correctly_update_amounts_for_exact_in_swap", func(t *testing.T) {
		step := StepComputations{
			amountIn:  u256.MustFromDecimal("1000"),
			amountOut: u256.MustFromDecimal("990"),
			feeAmount: u256.MustFromDecimal("10"),
		}

		state := SwapState{
			amountSpecifiedRemaining: i256.MustFromDecimal("10000"),
			amountCalculated:         i256.MustFromDecimal("0"),
		}

		updatedState, err := updateAmounts(step, state, true)
		uassert.NoError(t, err, "Should allow exact in calculation")

		expectedRemaining := i256.MustFromDecimal("8990")  // 10000 - (1000 + 10)
		expectedCalculated := i256.MustFromDecimal("-990") // 0 - 990

		uassert.True(t, expectedRemaining.Eq(updatedState.amountSpecifiedRemaining),
			"Should correctly reduce remaining amount by input + fee")
		uassert.True(t, expectedCalculated.Eq(updatedState.amountCalculated),
			"Should correctly subtract output from calculated amount")
	})

	t.Run("should_handle_edge_case_at_exactly_max_int64", func(t *testing.T) {
		step := StepComputations{
			amountIn:  u256.MustFromDecimal("0"),
			amountOut: u256.MustFromDecimal("100"),
			feeAmount: u256.MustFromDecimal("0"),
		}

		state := SwapState{
			amountSpecifiedRemaining: i256.MustFromDecimal("-1000"),
			amountCalculated:         maxInt64,
		}

		// no change to amountCalculated
		updatedState, err := updateAmounts(step, state, false)

		uassert.NoError(t, err, "Should allow calculation at exactly MAX_INT64")
		uassert.True(t, updatedState.amountCalculated.Eq(maxInt64),
			"Should maintain MAX_INT64 value")
	})

	t.Run("should_prevent_overflow_from_fee_accumulation", func(t *testing.T) {
		step := StepComputations{
			amountIn:  u256.MustFromDecimal("1"),
			amountOut: u256.MustFromDecimal("1"),
			feeAmount: u256.MustFromDecimal("10"), // Large fee relative to amount
		}

		state := SwapState{
			amountSpecifiedRemaining: i256.MustFromDecimal("-100"),
			amountCalculated:         i256.MustFromDecimal("9223372036854775800"),
		}

		_, err := updateAmounts(step, state, false)
		uassert.ErrorIs(t, err, errOverFlow,
			"Should detect overflow caused by fee accumulation")
	})
}

func setupUltraLowFeePool(t *testing.T) *pl.Pool {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	wugnot.Approve(cross, poolAddr, maxApprove)
	gns.Approve(cross, poolAddr, maxApprove)
	mockInstance.CreatePool(wugnotPath, gnsPath, ULTRA_LOW_FEE_TIER, EQUAL_PRICE_RATIO)

	// Prepare tokens
	testing.SetOriginCaller(adminAddr)
	newCoins := chain.Coins{{"ugnot", int64(10000000000)}}
	testing.IssueCoins(adminAddr, newCoins)
	testing.SetOriginSend(newCoins)
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(adminAddr, wugnotAddr, newCoins)
	wugnot.Deposit(cross)

	// Add liquidity
	testing.SetRealm(posRealm)
	mockInstance.Mint(wugnotPath, gnsPath, ULTRA_LOW_FEE_TIER, -100, 100, "10000000", adminAddr)
	mockInstance.Mint(wugnotPath, gnsPath, ULTRA_LOW_FEE_TIER, -100, 100, "10000000", adminAddr)

	// Send tokens to router
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, poolAddr, 20000000)
	wugnot.Transfer(cross, routerAddr, 20000000)
	gns.Transfer(cross, routerAddr, 20000000)
	wugnot.Approve(cross, poolAddr, maxApprove)

	pool := mockInstance.mustGetPoolBy(wugnotPath, gnsPath, ULTRA_LOW_FEE_TIER)
	return pool
}
