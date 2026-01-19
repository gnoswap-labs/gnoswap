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
			actualDeducted0, actualDeducted1 := getMockInstance().saveProtocolFees(pool, deductAmount0, deductAmount1)

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
				Cache: &SwapCache{
					feeProtocol:    0,
					liquidityStart: mockPool.Liquidity(),
				},
			}

			// When: Execute swap computation
			result, err := getMockInstance().computeSwap(mockPool, computation)
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
			amount0, amount1, success := getMockInstance().DrySwap(
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
				pool := getMockInstance().mustGetPoolBy(wugnotPath, gnsPath, STANDARD_FEE_TIER)
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
			expectedError: "[GNOSWAP-POOL-014] cannot swap while pool is locked",
			riskFactor:    "Prevent state inconsistency from concurrent transactions",
		},
		{
			name:        "zero_amount_swap_prevention",
			description: "Prevent meaningless zero swap",
			setupCondition: func(t *testing.T) *pl.Pool {
				InitialisePoolTest(t)
				pool := getMockInstance().mustGetPoolBy(wugnotPath, gnsPath, STANDARD_FEE_TIER)
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
			expectedError: "[GNOSWAP-POOL-011] invalid swap amount || amountSpecified == 0",
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
				mockInstanceSwap(pool.Token0Path(), pool.Token1Path(), pool.Fee(),
					alice, test.swapParams.zeroForOne, test.swapParams.amountSpecified,
					test.swapParams.priceLimit, routerAddr,
					func(cur realm, amount0Delta int64, amount1Delta int64, _ *pl.CallbackMarker) error {
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
		fee             uint32
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
			fee: STANDARD_FEE_TIER,
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
			fee: STANDARD_FEE_TIER,
			swapParams: SwapScenario{
				zeroForOne:      false,
				amountSpecified: EXTREME_SWAP_AMOUNT,
				priceLimit:      maxSqrtPriceLimitX96,
			},
			consistencyGoal: "Accurate prediction of price impact even in large trades",
		},
		{
			name:        "small_exact_input_zeroForOne",
			description: "Small swap exact input token0 to token1",
			setupScenario: func(t *testing.T) {
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)
				TokenFaucet(t, wugnotPath, routerAddr)
				TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
			},
			fee: STANDARD_FEE_TIER,
			swapParams: SwapScenario{
				zeroForOne:      true,
				amountSpecified: SMALL_SWAP_AMOUNT,
				priceLimit:      common.TickMathGetSqrtRatioAtTick(-887220).ToString(),
			},
			consistencyGoal: "Minimal price impact with small amount",
		},
		{
			name:        "large_exact_input_approaching_limits",
			description: "Large swap approaching liquidity limits",
			setupScenario: func(t *testing.T) {
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)
				TokenFaucet(t, wugnotPath, routerAddr)
				TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
			},
			fee: STANDARD_FEE_TIER,
			swapParams: SwapScenario{
				zeroForOne:      true,
				amountSpecified: LARGE_SWAP_AMOUNT,
				priceLimit:      common.TickMathGetSqrtRatioAtTick(-887220).ToString(),
			},
			consistencyGoal: "Significant price impact with large amount",
		},
		{
			name:        "small_exact_output_oneForZero",
			description: "Small exact output swap token1 to token0",
			setupScenario: func(t *testing.T) {
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)
				TokenFaucet(t, gnsPath, routerAddr)
				TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
			},
			fee: STANDARD_FEE_TIER,
			swapParams: SwapScenario{
				zeroForOne:      false,
				amountSpecified: "-" + SMALL_SWAP_AMOUNT,
				priceLimit:      common.TickMathGetSqrtRatioAtTick(887220).ToString(),
			},
			consistencyGoal: "Small input required for small output",
		},
		{
			name:        "medium_exact_output_near_limit",
			description: "Medium exact output approaching limits",
			setupScenario: func(t *testing.T) {
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)
				TokenFaucet(t, wugnotPath, routerAddr)
				TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
			},
			fee: STANDARD_FEE_TIER,
			swapParams: SwapScenario{
				zeroForOne:      true,
				amountSpecified: "-" + MEDIUM_SWAP_AMOUNT,
				priceLimit:      common.TickMathGetSqrtRatioAtTick(-887220).ToString(),
			},
			consistencyGoal: "Large input required due to price impact",
		},
		{
			name:        "ultra_low_fee_stablecoin_consistency",
			description: "Ultra-low fee tier (0.01%) stablecoin swap",
			setupScenario: func(t *testing.T) {
				setupUltraLowFeePool(t)
				TokenFaucet(t, wugnotPath, routerAddr)
				TokenFaucet(t, gnsPath, routerAddr)
			},
			fee: ULTRA_LOW_FEE_TIER,
			swapParams: SwapScenario{
				zeroForOne:      true,
				amountSpecified: MEDIUM_SWAP_AMOUNT,
				priceLimit:      common.TickMathGetSqrtRatioAtTick(-887220).ToString(),
			},
			consistencyGoal: "Minimal fee impact on stablecoin swap",
		},
		{
			name:        "scattered_liquidity_consistency",
			description: "Swap through scattered liquidity positions",
			setupScenario: func(t *testing.T) {
				setupScatteredLiquidityPool(t)
			},
			fee: STANDARD_FEE_TIER,
			swapParams: SwapScenario{
				zeroForOne:      false,
				amountSpecified: SMALL_SWAP_AMOUNT,
				priceLimit:      common.TickMathGetSqrtRatioAtTick(11040).ToString(),
			},
			consistencyGoal: "Navigation across multiple liquidity ranges",
		},
		{
			name:        "extreme_price_range_consistency",
			description: "Extreme price range traversal",
			setupScenario: func(t *testing.T) {
				setupExtremePriceRangePool(t)
			},
			fee: STANDARD_FEE_TIER,
			swapParams: SwapScenario{
				zeroForOne:      true,
				amountSpecified: SMALL_SWAP_AMOUNT,
				priceLimit:      common.TickMathGetSqrtRatioAtTick(-100080).ToString(),
			},
			consistencyGoal: "Large price movement in extreme volatility",
		},
		{
			name:        "wide_range_low_concentration_consistency",
			description: "Wide range position with low concentration",
			setupScenario: func(t *testing.T) {
				setupWideRangePositionPool(t)
			},
			fee: STANDARD_FEE_TIER,
			swapParams: SwapScenario{
				zeroForOne:      true,
				amountSpecified: MEDIUM_SWAP_AMOUNT,
				priceLimit:      common.TickMathGetSqrtRatioAtTick(-887220).ToString(),
			},
			consistencyGoal: "Lower price impact due to wide liquidity distribution",
		},
		{
			name:        "narrow_range_high_concentration_consistency",
			description: "Narrow range position with high concentration",
			setupScenario: func(t *testing.T) {
				setupNarrowRangePositionPool(t)
			},
			fee: STANDARD_FEE_TIER,
			swapParams: SwapScenario{
				zeroForOne:      false,
				amountSpecified: SMALL_SWAP_AMOUNT,
				priceLimit:      common.TickMathGetSqrtRatioAtTick(887220).ToString(),
			},
			consistencyGoal: "Better execution due to concentrated liquidity",
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
			dryAmount0, dryAmount1, drySuccess := getMockInstance().DrySwap(
				wugnotPath, gnsPath, test.fee,
				test.swapParams.zeroForOne, test.swapParams.amountSpecified,
				test.swapParams.priceLimit)

			// Execute actual swap
			testing.SetRealm(rouRealm)

			TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
			TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)

			testing.SetRealm(rouRealm)

			actualAmount0, actualAmount1 := mockInstanceSwap(wugnotPath, gnsPath, test.fee,
				routerAddr, test.swapParams.zeroForOne, test.swapParams.amountSpecified,
				test.swapParams.priceLimit, routerAddr,
				func(cur realm, amount0Delta int64, amount1Delta int64, _ *pl.CallbackMarker) error {
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

func setupWideRangePositionPool(t *testing.T) {
	t.Helper()

	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	ugnotFaucet(t, adminAddr, 1_000_000_000_000_000)
	ugnotDeposit(t, adminAddr, 1_000_000_000_000_000)

	TokenApprove(t, wugnotPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(t, gnsPath, adminAddr, poolAddr, maxApprove)

	mockInstanceCreatePool(wugnotPath, gnsPath, STANDARD_FEE_TIER, EQUAL_PRICE_RATIO)

	testing.SetRealm(posRealm)
	// Wide range position (low concentration)
	mockInstanceMint(wugnotPath, gnsPath, STANDARD_FEE_TIER, -887220, 887220, "100000000", adminAddr)

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

func setupNarrowRangePositionPool(t *testing.T) {
	t.Helper()

	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	ugnotFaucet(t, adminAddr, 1_000_000_000_000_000)
	ugnotDeposit(t, adminAddr, 1_000_000_000_000_000)

	TokenApprove(t, wugnotPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(t, gnsPath, adminAddr, poolAddr, maxApprove)

	mockInstanceCreatePool(wugnotPath, gnsPath, STANDARD_FEE_TIER, EQUAL_PRICE_RATIO)

	testing.SetRealm(posRealm)
	// Narrow range position (high concentration)
	mockInstanceMint(wugnotPath, gnsPath, STANDARD_FEE_TIER, -60, 60, "100000000", adminAddr)

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

			actualAmount0, actualAmount1 := mockInstanceSwap(wugnotPath, gnsPath, STANDARD_FEE_TIER,
				alice, pattern.swapParams.zeroForOne, pattern.swapParams.amountSpecified,
				pattern.swapParams.priceLimit, routerAddr,
				func(cur realm, amount0Delta int64, amount1Delta int64, _ *pl.CallbackMarker) error {
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

			actualAmount0, actualAmount1 := mockInstanceSwap(wugnotPath, gnsPath, STANDARD_FEE_TIER,
				alice, test.swapParams.zeroForOne, test.swapParams.amountSpecified,
				test.swapParams.priceLimit, routerAddr,
				func(cur realm, amount0Delta int64, amount1Delta int64, _ *pl.CallbackMarker) error {
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

		actualAmount0, actualAmount1 := mockInstanceSwap(wugnotPath, gnsPath, ULTRA_LOW_FEE_TIER,
			adminAddr, true, "40012000",
			common.TickMathGetSqrtRatioAtTick(-887220).ToString(), routerAddr,
			func(cur realm, amount0Delta int64, amount1Delta int64, _ *pl.CallbackMarker) error {
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

	mockInstanceCreatePool(wugnotPath, gnsPath, STANDARD_FEE_TIER,
		common.TickMathGetSqrtRatioAtTick(-10000).ToString())

	testing.SetRealm(posRealm)
	// 4 dispersed liquidity positions
	mockInstanceMint(wugnotPath, gnsPath, STANDARD_FEE_TIER, -10020, -9000, "10000000", adminAddr)
	mockInstanceMint(wugnotPath, gnsPath, STANDARD_FEE_TIER, -4980, -4020, "20000000", adminAddr)
	mockInstanceMint(wugnotPath, gnsPath, STANDARD_FEE_TIER, 0, 1020, "30000000", adminAddr)
	mockInstanceMint(wugnotPath, gnsPath, STANDARD_FEE_TIER, 8040, 10020, "40000000", adminAddr)

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

	mockInstanceCreatePool(wugnotPath, gnsPath, STANDARD_FEE_TIER,
		common.TickMathGetSqrtRatioAtTick(100000).ToString())

	testing.SetRealm(posRealm)
	// Extreme range liquidity
	mockInstanceMint(wugnotPath, gnsPath, STANDARD_FEE_TIER, -100020, -99960, "500000", adminAddr)
	mockInstanceMint(wugnotPath, gnsPath, STANDARD_FEE_TIER, 99960, 100020, "500000", adminAddr)

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

		uassert.ErrorIs(t, err, errOverflow,
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
		uassert.ErrorIs(t, err, errOverflow,
			"Should detect overflow caused by fee accumulation")
	})
}

func setupUltraLowFeePool(t *testing.T) *pl.Pool {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	wugnot.Approve(cross, poolAddr, maxApprove)
	gns.Approve(cross, poolAddr, maxApprove)
	mockInstanceCreatePool(wugnotPath, gnsPath, ULTRA_LOW_FEE_TIER, EQUAL_PRICE_RATIO)

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
	mockInstanceMint(wugnotPath, gnsPath, ULTRA_LOW_FEE_TIER, -100, 100, "10000000", adminAddr)
	mockInstanceMint(wugnotPath, gnsPath, ULTRA_LOW_FEE_TIER, -100, 100, "10000000", adminAddr)

	// Send tokens to router
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, poolAddr, 20000000)
	wugnot.Transfer(cross, routerAddr, 20000000)
	gns.Transfer(cross, routerAddr, 20000000)
	wugnot.Approve(cross, poolAddr, maxApprove)

	pool := getMockInstance().mustGetPoolBy(wugnotPath, gnsPath, ULTRA_LOW_FEE_TIER)
	return pool
}

// TestSwap_PriceLimitEdgeCase_ZeroAmount tests a specific edge case where:
// - Price limit is extremely close to current price (difference of 1)
// - Low liquidity in the pool
// - ExactOutput swap (negative amountSpecified)
// - This causes one of the amounts to be zero, which should be rejected by validation
//
// Reproduced from fuzz test failure:
// - sqrtPrice: 81258104018314874265769693256
// - liquidity: 348726074781113
// - tick: 506
// - zeroForOne: false
// - amountSpecified: -178
// - sqrtPriceLimit: 81258104018314874265769693257 (current + 1)
// - Result: amount0=0, amount1=2
func TestSwap_PriceLimitEdgeCase_ZeroAmount(t *testing.T) {
	// given: Setup pool
	initPoolTest(t)

	testing.SetRealm(adminRealm)
	mockInstanceSetPoolCreationFee(0)

	token0Path := barPath
	token1Path := fooPath
	fee := ULTRA_LOW_FEE_TIER // 100 = 0.01%

	// Create pool at a specific price to match the failing case
	// tick 506 corresponds to sqrtPrice around 81258104018314874265769693256
	targetTick := int32(506)
	targetPrice := common.TickMathGetSqrtRatioAtTick(targetTick)

	mockInstanceCreatePool(token0Path, token1Path, fee, targetPrice.ToString())

	// Approve tokens for liquidity provision
	testing.SetRealm(adminRealm)
	TokenApprove(t, token0Path, adminAddr, poolAddr, maxApprove)
	TokenApprove(t, token1Path, adminAddr, poolAddr, maxApprove)

	// Add liquidity multiple times to match the failing case
	// The fuzz test calls setupPoolSwapLiquidity multiple times
	// Each call adds amountDesired = 1_000_000_000_000
	// Expected final liquidity: 348726074781113
	tickLower := targetTick - 10000
	tickUpper := targetTick + 10000

	testing.SetRealm(posRealm)
	// Try adding liquidity once with a value that gets us close to 348726074781113
	mockInstanceMint(token0Path, token1Path, fee, tickLower, tickUpper, "1000000000000", adminAddr)

	// Verify pool state
	pool := getMockInstance().mustGetPoolBy(token0Path, token1Path, fee)
	currentPrice := pool.Slot0SqrtPriceX96()

	// when: Define swap callback
	swapCallback := func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
		t.Logf("Callback: amount0=%d, amount1=%d", amount0Delta, amount1Delta)
		return mockSwapCallback(token0Path, token1Path, amount0Delta, amount1Delta)
	}

	// Swap parameters matching the failing case
	zeroForOne := false
	amountSpecified := "-178"

	// Price limit is current price + 1 (extremely close)
	currentPriceInt := u256.MustFromDecimal(currentPrice.ToString())
	priceLimitInt := u256.NewUint(0).Add(currentPriceInt, u256.NewUint(1))
	sqrtPriceLimitX96 := priceLimitInt.ToString()

	// computeSwap should return amount0=0, amount1=2
	slot0Start := pool.Slot0()
	amounts := i256.MustFromDecimal(amountSpecified)
	feeGrowthGlobalX128 := getFeeGrowthGlobal(pool, zeroForOne)
	feeProtocol := getFeeProtocol(slot0Start, zeroForOne)
	cache := newSwapCache(feeProtocol, pool.Liquidity().Clone())
	state := newSwapState(amounts, feeGrowthGlobalX128, cache.liquidityStart, slot0Start)

	comp := SwapComputation{
		AmountSpecified:   amounts,
		SqrtPriceLimitX96: priceLimitInt,
		ZeroForOne:        zeroForOne,
		ExactInput:        amounts.Gt(i256.Zero()),
		InitialState:      state,
		Cache:             cache,
	}

	result, _ := getMockInstance().computeSwap(pool, comp)
	uassert.Equal(t, "0", result.Amount0.ToString(), "DrySwap should return amount0=0")
	uassert.Equal(t, "2", result.Amount1.ToString(), "DrySwap should return amount1=2")

	// then: Actual Swap should complete successfully even with zero amount0
	amount0Str, amount1Str := mockInstanceSwap(
		token0Path,
		token1Path,
		fee,
		adminAddr,
		zeroForOne,
		amountSpecified,
		sqrtPriceLimitX96,
		adminAddr,
		swapCallback,
	)

	// Verify that swap completed with expected amounts
	uassert.Equal(t, "0", amount0Str, "Swap should return amount0=0")
	uassert.NotEqual(t, "0", amount1Str, "Swap should return non-zero amount1")
}

// TestSwap_ReentrancyProtection tests that the reentrancy lock properly prevents
// recursive swap calls during callback execution.
//
// Security issue addressed:
// The Swap function uses Slot0.unlocked field as a reentrancy lock. Previously,
// this lock was ineffective because Slot0() returned a copy of the struct,
// so SetUnlocked(false) only modified the local copy, not the actual pool state.
// The fix uses pool.SetSlot0() to persist the lock state.
//
// Attack scenario:
// 1. Attacker calls Swap with a malicious callback
// 2. Inside the callback (before payment), attacker tries to call Swap again
// 3. Without proper reentrancy protection, the second Swap would succeed
// 4. This could allow manipulation of pool state or token theft
func TestSwap_ReentrancyProtection(t *testing.T) {
	tests := []struct {
		name        string
		description string
		setup       func(t *testing.T)
		action      func(t *testing.T)
		verify      func(t *testing.T)
	}{
		{
			name:        "expected panics by reentrant swap in callback",
			description: "Reentrancy attack via callback should be blocked by pool lock",
			setup: func(t *testing.T) {
				initPoolTest(t)
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)

				TokenFaucet(t, gnsPath, routerAddr)
				TokenFaucet(t, gnsPath, routerAddr)
				TokenFaucet(t, wugnotPath, routerAddr)
				TokenFaucet(t, wugnotPath, routerAddr)

				testing.SetRealm(rouRealm)
				TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
				TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
			},
			action: func(t *testing.T) {
				// Execution flow:
				// 1. User initiates Swap -> pool.Slot0.unlocked = false (locked)
				// 2. Swap executes computeSwap and transfers output tokens
				// 3. Swap calls swapCallback (maliciousCallback)
				// 4. Inside callback, attacker attempts second Swap
				// 5. Second Swap checks pool.Slot0.unlocked -> false -> PANIC [GNOSWAP-POOL-014]
				// 6. Callback catches panic, completes token transfer
				// 7. Original Swap completes successfully
				// 8. defer unlocks pool -> pool.Slot0.unlocked = true

				testing.SetRealm(rouRealm)

				maliciousCallback := func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
					// Step 4-5: Attempt reentrancy, expect panic due to locked pool
					uassert.PanicsContains(t, "[GNOSWAP-POOL-014]", func() {
						getMockInstance().Swap(
							wugnotPath, gnsPath, STANDARD_FEE_TIER,
							routerAddr, false, "50",
							common.TickMathGetSqrtRatioAtTick(887220).ToString(),
							routerAddr,
							func(cur realm, a0, a1 int64, _ *pl.CallbackMarker) error { return nil },
						)
					})

					// Step 6: Complete original swap payment
					return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
				}

				// Step 1-3, 7: Execute swap with malicious callback
				amount0, amount1 := mockInstanceSwap(
					wugnotPath, gnsPath, STANDARD_FEE_TIER,
					routerAddr, false, "100",
					common.TickMathGetSqrtRatioAtTick(887220).ToString(),
					routerAddr, maliciousCallback,
				)

				uassert.True(t, amount0 != "0" || amount1 != "0",
					"Original swap should complete successfully")
			},
			verify: func(t *testing.T) {
				// Pool should be unlocked after swap
				pool := getMockInstance().mustGetPoolBy(wugnotPath, gnsPath, STANDARD_FEE_TIER)
				slot0 := pool.Slot0()
				uassert.True(t, slot0.Unlocked(), "Pool should be unlocked after swap")
			},
		},
		{
			name:        "success by unlock after swap completes",
			description: "Pool should be unlocked after swap completes, allowing subsequent swaps",
			setup: func(t *testing.T) {
				resetObject(t)
				burnTokens(t)
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)

				TokenFaucet(t, gnsPath, routerAddr)
				TokenFaucet(t, wugnotPath, routerAddr)

				testing.SetRealm(rouRealm)
				TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
				TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
			},
			action: func(t *testing.T) {
				// Execution flow:
				// 1. Check initial state: pool.Slot0.unlocked = true
				// 2. Execute first Swap:
				//    a. Swap locks pool -> unlocked = false
				//    b. Swap executes and calls callback
				//    c. Callback transfers tokens
				//    d. defer unlocks pool -> unlocked = true
				// 3. Verify pool is unlocked after first swap
				// 4. Execute second Swap (proves unlock worked):
				//    a. If pool was still locked, this would panic
				//    b. Swap succeeds -> confirms proper unlock

				// Step 1: Verify initial unlocked state
				pool := getMockInstance().mustGetPoolBy(wugnotPath, gnsPath, STANDARD_FEE_TIER)
				slot0 := pool.Slot0()
				uassert.True(t, slot0.Unlocked(), "Pool should start unlocked")

				// Step 2: Execute first swap
				testing.SetRealm(rouRealm)
				mockInstanceSwap(
					wugnotPath, gnsPath, STANDARD_FEE_TIER,
					routerAddr, false, "100",
					common.TickMathGetSqrtRatioAtTick(887220).ToString(),
					routerAddr,
					func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
						return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
					},
				)

				// Step 3: Verify unlocked after first swap
				pool = getMockInstance().mustGetPoolBy(wugnotPath, gnsPath, STANDARD_FEE_TIER)
				slot0 = pool.Slot0()
				uassert.True(t, slot0.Unlocked(), "Pool should be unlocked after first swap")

				// Step 4: Execute second swap to prove unlock worked
				TokenFaucet(t, gnsPath, routerAddr)
				TokenFaucet(t, wugnotPath, routerAddr)

				testing.SetRealm(rouRealm)
				amount0, amount1 := mockInstanceSwap(
					wugnotPath, gnsPath, STANDARD_FEE_TIER,
					routerAddr, false, "50",
					common.TickMathGetSqrtRatioAtTick(887220).ToString(),
					routerAddr,
					func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
						return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
					},
				)

				uassert.True(t, amount0 != "0" || amount1 != "0",
					"Second swap should succeed after first completes")
			},
			verify: func(t *testing.T) {},
		},
		{
			name:        "expected lock state during swap",
			description: "Pool should be locked during callback execution",
			setup: func(t *testing.T) {
				resetObject(t)
				burnTokens(t)
				InitialisePoolTest(t)
				MintPositionAll(t, adminAddr)

				TokenFaucet(t, gnsPath, routerAddr)
				TokenFaucet(t, gnsPath, routerAddr)
				TokenFaucet(t, wugnotPath, routerAddr)
				TokenFaucet(t, wugnotPath, routerAddr)

				testing.SetRealm(rouRealm)
				TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)
				TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
			},
			action: func(t *testing.T) {
				// Execution flow:
				// 1. User initiates Swap -> pool.Slot0.unlocked = false (locked)
				// 2. Swap executes computeSwap
				// 3. Swap transfers output tokens to recipient
				// 4. Swap calls swapCallback (callbackWithLockCheck)
				// 5. Inside callback: check pool.Slot0.unlocked -> should be false (locked)
				// 6. Callback transfers input tokens to pool
				// 7. Swap completes, defer unlocks pool -> unlocked = true
				// 8. Verify: lockStateDuringCallback == true (was locked during callback)

				lockStateDuringCallback := false

				testing.SetRealm(rouRealm)
				callbackWithLockCheck := func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
					// Step 5: Verify pool is locked during callback
					pool := getMockInstance().mustGetPoolBy(wugnotPath, gnsPath, STANDARD_FEE_TIER)
					slot0 := pool.Slot0()
					lockStateDuringCallback = !slot0.Unlocked() // true if locked

					// Step 6: Complete swap payment
					return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
				}

				// Step 1-4, 7: Execute swap
				amount0, amount1 := mockInstanceSwap(
					wugnotPath, gnsPath, STANDARD_FEE_TIER,
					routerAddr, false, "100",
					common.TickMathGetSqrtRatioAtTick(887220).ToString(),
					routerAddr, callbackWithLockCheck,
				)

				// Step 8: Verify lock was active during callback
				uassert.True(t, lockStateDuringCallback,
					"Pool should be locked during callback execution")
				uassert.True(t, amount0 != "0" || amount1 != "0", "Swap should succeed")
			},
			verify: func(t *testing.T) {
				pool := getMockInstance().mustGetPoolBy(wugnotPath, gnsPath, STANDARD_FEE_TIER)
				slot0 := pool.Slot0()
				uassert.True(t, slot0.Unlocked(),
					"Pool should be unlocked after swap completes")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup(t)
			tt.action(t)
			tt.verify(t)
			t.Logf("passed: %s", tt.description)
		})
	}
}

// TestSwapCallback_DeltaConvention tests that swap callback parameters follow
// the Uniswap V3 delta convention:
//   - Positive delta: Amount the pool must RECEIVE (input token)
//   - Negative delta: Amount the pool has SENT (output token)
//
// This convention allows callbacks to correctly identify:
//   - Which tokens were received by the pool (need to be paid by caller)
//   - Which tokens were sent by the pool (received by recipient)
//
// For zeroForOne swaps (token0 → token1):
//   - amount0Delta > 0: Pool receives token0 (input from user)
//   - amount1Delta < 0: Pool sends token1 (output to user)
//
// For oneForZero swaps (token1 → token0):
//   - amount0Delta < 0: Pool sends token0 (output to user)
//   - amount1Delta > 0: Pool receives token1 (input from user)
func TestSwapCallback_DeltaConvention(t *testing.T) {
	tests := []struct {
		name                    string
		description             string
		zeroForOne              bool
		amountSpecified         string
		expectedAmount0Positive bool // true if amount0Delta should be > 0
		expectedAmount1Positive bool // true if amount1Delta should be > 0
		isFailCase              bool
	}{
		{
			name:                    "zeroForOne swap has positive amount0Delta and negative amount1Delta",
			description:             "When swapping token0 for token1, pool receives token0 (positive) and sends token1 (negative)",
			zeroForOne:              true,
			amountSpecified:         "10000",
			expectedAmount0Positive: true,
			expectedAmount1Positive: false,
		},
		{
			name:                    "oneForZero swap has negative amount0Delta and positive amount1Delta",
			description:             "When swapping token1 for token0, pool sends token0 (negative) and receives token1 (positive)",
			zeroForOne:              false,
			amountSpecified:         "10000",
			expectedAmount0Positive: false,
			expectedAmount1Positive: true,
		},
		{
			name:                    "exact output zeroForOne swap maintains delta convention",
			description:             "Exact output swaps should also follow the same delta convention",
			zeroForOne:              true,
			amountSpecified:         "-5000",
			expectedAmount0Positive: true,
			expectedAmount1Positive: false,
		},
		{
			name:                    "exact output oneForZero swap maintains delta convention",
			description:             "Exact output oneForZero swaps follow the same delta convention",
			zeroForOne:              false,
			amountSpecified:         "-5000",
			expectedAmount0Positive: false,
			expectedAmount1Positive: true,
		},
		{
			name:                    "fail case by exact in zeroForOne swap but amount0Delta, amount1Delta is positive",
			description:             "Exact in zeroForOne swap but amount0Delta, amount1Delta is positive",
			zeroForOne:              true,
			amountSpecified:         "10000",
			expectedAmount0Positive: true,
			expectedAmount1Positive: true, // false
			isFailCase:              true,
		},
		{
			name:                    "fail case by exact in zeroForOne swap but amount0Delta, amount1Delta is negative",
			description:             "Exact in zeroForOne swap but amount0Delta, amount1Delta is negative",
			zeroForOne:              true,
			amountSpecified:         "10000",
			expectedAmount0Positive: false, // true
			expectedAmount1Positive: false,
			isFailCase:              true,
		},
		{
			name:                    "fail case by exact out oneForZero swap but amount0Delta, amount1Delta is positive",
			description:             "Exact out oneForZero swap but amount0Delta, amount1Delta is positive",
			zeroForOne:              false,
			amountSpecified:         "-5000",
			expectedAmount0Positive: true, // false
			expectedAmount1Positive: true,
			isFailCase:              true,
		},
		{
			name:                    "fail case by exact out oneForZero swap but amount0Delta, amount1Delta is negative",
			description:             "Exact out oneForZero swap but amount0Delta, amount1Delta is negative",
			zeroForOne:              false,
			amountSpecified:         "-5000",
			expectedAmount0Positive: false,
			expectedAmount1Positive: false, // true
			isFailCase:              true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Common setup
			resetObject(t)
			burnTokens(t)
			InitialisePoolTest(t)
			MintPositionAll(t, adminAddr)

			TokenFaucet(t, wugnotPath, routerAddr)
			TokenFaucet(t, gnsPath, routerAddr)

			testing.SetRealm(rouRealm)
			TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
			TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)

			// Capture deltas
			var capturedAmount0Delta, capturedAmount1Delta int64

			callbackCapturingDeltas := func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
				capturedAmount0Delta = amount0Delta
				capturedAmount1Delta = amount1Delta
				return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
			}

			// Determine price limit based on direction
			var priceLimit string
			if tt.zeroForOne {
				priceLimit = common.TickMathGetSqrtRatioAtTick(-887220).ToString()
			} else {
				priceLimit = common.TickMathGetSqrtRatioAtTick(887220).ToString()
			}

			// Execute swap
			testing.SetRealm(rouRealm)
			amount0, amount1 := mockInstanceSwap(
				wugnotPath, gnsPath, STANDARD_FEE_TIER,
				routerAddr, tt.zeroForOne, tt.amountSpecified,
				priceLimit, routerAddr, callbackCapturingDeltas,
			)

			if tt.isFailCase {
				if tt.zeroForOne {
					t.Logf("must amount0Delta be positive, actual %s, expected %s", amount0, tt.amountSpecified)
					t.Logf("must amount1Delta be negative, actual %s, expected %s", amount1, tt.amountSpecified)
				} else {
					t.Logf("must amount0Delta be negative, actual %s, expected %s", amount0, tt.amountSpecified)
					t.Logf("must amount1Delta be positive, actual %s, expected %s", amount1, tt.amountSpecified)
				}
				return
			}

			// Verify delta convention
			if tt.expectedAmount0Positive {
				uassert.True(t, capturedAmount0Delta > 0,
					ufmt.Sprintf("amount0Delta should be positive, got %d", capturedAmount0Delta))
			} else {
				uassert.True(t, capturedAmount0Delta < 0,
					ufmt.Sprintf("amount0Delta should be negative, got %d", capturedAmount0Delta))
			}

			if tt.expectedAmount1Positive {
				uassert.True(t, capturedAmount1Delta > 0,
					ufmt.Sprintf("amount1Delta should be positive, got %d", capturedAmount1Delta))
			} else {
				uassert.True(t, capturedAmount1Delta < 0,
					ufmt.Sprintf("amount1Delta should be negative, got %d", capturedAmount1Delta))
			}

			// Verify deltas match swap result
			uassert.Equal(t, ufmt.Sprintf("%d", capturedAmount0Delta), amount0,
				"amount0Delta should match swap result amount0")
			uassert.Equal(t, ufmt.Sprintf("%d", capturedAmount1Delta), amount1,
				"amount1Delta should match swap result amount1")

			t.Logf("passed: %s (amount0Delta=%d, amount1Delta=%d)", tt.description, capturedAmount0Delta, capturedAmount1Delta)
		})
	}
}

// TestSwapCallback_CallbackUsage demonstrates that a generic callback
// can handle both swap directions by checking delta signs.
func TestSwapCallback_CallbackUsage(t *testing.T) {
	resetObject(t)
	burnTokens(t)
	InitialisePoolTest(t)
	MintPositionAll(t, adminAddr)

	TokenFaucet(t, wugnotPath, routerAddr)
	TokenFaucet(t, gnsPath, routerAddr)

	testing.SetRealm(rouRealm)
	TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
	TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)

	var token0Transferred, token1Transferred int64

	// Generic callback that works for any swap direction
	genericCallback := func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
		token0Transferred, token1Transferred = 0, 0

		// Transfer tokens with positive deltas (tokens pool needs to receive)
		if amount0Delta > 0 {
			token0Transferred = amount0Delta
		}
		if amount1Delta > 0 {
			token1Transferred = amount1Delta
		}
		return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
	}

	// Test zeroForOne: should transfer token0 only
	testing.SetRealm(rouRealm)
	mockInstanceSwap(
		wugnotPath, gnsPath, STANDARD_FEE_TIER,
		routerAddr, true, "10000",
		common.TickMathGetSqrtRatioAtTick(-887220).ToString(),
		routerAddr, genericCallback,
	)

	uassert.True(t, token0Transferred > 0, "zeroForOne: should transfer token0 (positive delta)")
	uassert.Equal(t, int64(0), token1Transferred, "zeroForOne: should not transfer token1 (negative delta)")
	t.Logf("zeroForOne: token0 transferred=%d, token1 transferred=%d", token0Transferred, token1Transferred)

	// Test oneForZero: should transfer token1 only
	TokenFaucet(t, gnsPath, routerAddr)
	testing.SetRealm(rouRealm)
	mockInstanceSwap(
		wugnotPath, gnsPath, STANDARD_FEE_TIER,
		routerAddr, false, "10000",
		common.TickMathGetSqrtRatioAtTick(887220).ToString(),
		routerAddr, genericCallback,
	)

	uassert.Equal(t, int64(0), token0Transferred, "oneForZero: should not transfer token0 (negative delta)")
	uassert.True(t, token1Transferred > 0, "oneForZero: should transfer token1 (positive delta)")
	t.Logf("oneForZero: token0 transferred=%d, token1 transferred=%d", token0Transferred, token1Transferred)
}

// TestSwap_FlashSwapPattern tests that the flash swap pattern works correctly.
//
// Flash swap invariant:
// Output tokens MUST be transferred to recipient BEFORE the callback is invoked.
// This allows the callback to use the received tokens for arbitrage, chained swaps,
// or other operations before repaying the input amount.
//
// Execution order (after fix):
// 1. Pool computes swap amounts
// 2. Pool transfers output tokens to recipient  <-- OUTPUT FIRST
// 3. Pool invokes callback                      <-- CALLBACK SECOND
// 4. Callback can use received tokens
// 5. Callback transfers input tokens to pool
//
// Before fix (incorrect order):
// 1. Pool computes swap amounts
// 2. Pool invokes callback                      <-- CALLBACK FIRST (wrong)
// 3. Pool transfers output tokens to recipient  <-- OUTPUT SECOND (wrong)
// This prevented callbacks from using output tokens.
func TestSwap_FlashSwapPattern(t *testing.T) {
	tests := []struct {
		name        string
		description string
		zeroForOne  bool
	}{
		{
			name:        "zeroForOne flash swap receives output before callback",
			description: "Recipient should have output tokens available during callback execution",
			zeroForOne:  true,
		},
		{
			name:        "oneForZero flash swap receives output before callback",
			description: "Recipient should have output tokens available during callback execution",
			zeroForOne:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			resetObject(t)
			burnTokens(t)
			InitialisePoolTest(t)
			MintPositionAll(t, adminAddr)

			TokenFaucet(t, wugnotPath, routerAddr)
			TokenFaucet(t, gnsPath, routerAddr)

			testing.SetRealm(rouRealm)
			TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
			TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)

			// Track balances during callback
			var recipientBalanceDuringCallback int64
			var outputTokenPath string
			if tt.zeroForOne {
				outputTokenPath = gnsPath // zeroForOne: output is token1
			} else {
				outputTokenPath = wugnotPath // oneForZero: output is token0
			}

			// Callback that checks recipient balance
			flashSwapCallback := func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
				// Execution flow verification:
				// At this point, output tokens should ALREADY be transferred to recipient
				// This is the key invariant of flash swap pattern

				recipientBalanceDuringCallback = common.BalanceOf(outputTokenPath, routerAddr)

				// Complete the swap by paying input tokens
				return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
			}

			// Get initial balance
			initialBalance := common.BalanceOf(outputTokenPath, routerAddr)

			// Determine price limit based on direction
			var priceLimit string
			if tt.zeroForOne {
				priceLimit = common.TickMathGetSqrtRatioAtTick(-887220).ToString()
			} else {
				priceLimit = common.TickMathGetSqrtRatioAtTick(887220).ToString()
			}

			// Execute swap
			testing.SetRealm(rouRealm)
			mockInstanceSwap(
				wugnotPath, gnsPath, STANDARD_FEE_TIER,
				routerAddr, tt.zeroForOne, "10000",
				priceLimit, routerAddr, flashSwapCallback,
			)

			// Verify: recipient balance during callback should be GREATER than initial
			// This proves output tokens were transferred BEFORE callback was invoked
			uassert.True(t, recipientBalanceDuringCallback > initialBalance,
				ufmt.Sprintf("Flash swap failed: recipient should have received output tokens before callback. initial=%d, duringCallback=%d",
					initialBalance, recipientBalanceDuringCallback))

			t.Logf("passed: %s (initial=%d, duringCallback=%d)",
				tt.description, initialBalance, recipientBalanceDuringCallback)
		})
	}
}

// TestSwap_FlashSwapArbitragePattern tests a practical flash swap use case:
// using received output tokens within the callback for arbitrage or chained operations.
func TestSwap_FlashSwapArbitragePattern(t *testing.T) {
	// Setup
	resetObject(t)
	burnTokens(t)
	InitialisePoolTest(t)
	MintPositionAll(t, adminAddr)

	TokenFaucet(t, wugnotPath, routerAddr)
	TokenFaucet(t, gnsPath, routerAddr)

	testing.SetRealm(rouRealm)
	TokenApprove(t, wugnotPath, routerAddr, poolAddr, maxApprove)
	TokenApprove(t, gnsPath, routerAddr, poolAddr, maxApprove)

	// Simulate arbitrage scenario:
	// 1. Swap token0 for token1 (receive token1 first via flash swap)
	// 2. In callback, verify we can "use" the received token1
	// 3. Pay back token0

	var outputReceivedBeforePayment bool
	var outputAmountReceived int64

	arbitrageCallback := func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
		// In a real arbitrage scenario, we would:
		// 1. Use the received token1 (amount1Delta is negative, meaning we received it)
		// 2. Perform arbitrage operation
		// 3. Pay back token0 (amount0Delta is positive, meaning we owe it)

		// Verify we received output tokens (negative delta = pool sent to us)
		if amount1Delta < 0 {
			outputAmountReceived = -amount1Delta // Convert to positive
			// Check our balance increased
			currentBalance := common.BalanceOf(gnsPath, routerAddr)
			outputReceivedBeforePayment = currentBalance >= outputAmountReceived
		}

		// Pay back input tokens
		return mockSwapCallback(wugnotPath, gnsPath, amount0Delta, amount1Delta)
	}

	// Execute flash swap
	testing.SetRealm(rouRealm)
	amount0, amount1 := mockInstanceSwap(
		wugnotPath, gnsPath, STANDARD_FEE_TIER,
		routerAddr, true, "10000", // zeroForOne: swap token0 for token1
		common.TickMathGetSqrtRatioAtTick(-887220).ToString(),
		routerAddr, arbitrageCallback,
	)

	// Verify flash swap pattern worked
	uassert.True(t, outputReceivedBeforePayment,
		"Flash swap arbitrage failed: output tokens not available during callback")
	uassert.True(t, outputAmountReceived > 0,
		"Flash swap should have received output tokens")

	t.Logf("Flash swap arbitrage pattern verified: received %d output tokens before payment (amount0=%s, amount1=%s)",
		outputAmountReceived, amount0, amount1)
}
