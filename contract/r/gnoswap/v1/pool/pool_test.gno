package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
)

const (
	// Price ratios - Common price ratios in real DeFi
	EQUAL_PRICE_RATIO    = "79228162514264337593543950336"  // 1:1 ratio (stablecoin pairs)
	DOUBLE_PRICE_RATIO   = "112045541949572279837463876454" // 1:2 ratio (common token pairs)
	VOLATILE_PRICE_RATIO = "25054144837504793118641380156"  // 1:10 ratio (volatile pairs)

	// Time periods for cumulative testing
	ONE_MINUTE = int64(60)
	ONE_HOUR   = int64(3600)
	ONE_DAY    = int64(86400)

	// Liquidity amounts with business context
	MINIMAL_LIQUIDITY = "1000"       // Minimum liquidity (dust level)
	SMALL_LIQUIDITY   = "100000"     // Small LP
	MEDIUM_LIQUIDITY  = "10000000"   // Medium-sized LP
	LARGE_LIQUIDITY   = "1000000000" // Large LP

	// Tick ranges for different strategies
	NARROW_RANGE_LOWER = int32(-60) // Narrow range (concentrated liquidity)
	NARROW_RANGE_UPPER = int32(60)

	WIDE_RANGE_LOWER = int32(-240) // Wide range (stable liquidity)
	WIDE_RANGE_UPPER = int32(240)

	FULL_RANGE_LOWER = int32(-887220) // Full range
	FULL_RANGE_UPPER = int32(887220)
)

var (
	fooTokenPath = "gno.land/r/onbloc/foo"
	barTokenPath = "gno.land/r/onbloc/bar"
	bazTokenPath = "gno.land/r/onbloc/baz"
)

type PoolTestScenario struct {
	name         string
	description  string
	token0       string
	token1       string
	fee          uint32
	initialPrice string
	expectation  string
}

type LiquidityScenario struct {
	name             string
	description      string
	tickLower        int32
	tickUpper        int32
	amount           string
	timeElapsed      int64
	expectedBehavior string
}

func setupStablecoinPool(t *testing.T) *Pool {
	t.Helper()
	testing.SetRealm(adminRealm)
	SetPoolCreationFee(cross, 0)

	// BAR-BAZ: Stablecoin pair simulation (low fee)
	CreatePool(cross, barTokenPath, bazTokenPath, FeeTier100, EQUAL_PRICE_RATIO)

	pool := mustGetPool(GetPoolPath(barTokenPath, bazTokenPath, FeeTier100))
	return pool
}

func setupVolatilePool(t *testing.T) *Pool {
	t.Helper()
	testing.SetRealm(adminRealm)
	SetPoolCreationFee(cross, 0)

	// FOO-BAR: Volatile token pair (high fee)
	CreatePool(cross, fooTokenPath, barTokenPath, FeeTier3000, VOLATILE_PRICE_RATIO)

	pool := mustGetPool(GetPoolPath(fooTokenPath, barTokenPath, FeeTier3000))
	return pool
}

func addLiquidityWithValidation(t *testing.T, pool *Pool, scenario LiquidityScenario) (string, string) {
	t.Helper()

	// Save state before adding liquidity
	beforeLiquidity := new(u256.Uint).Set(pool.liquidity)
	beforeBalance0 := getTokenBalance(t, pool.token0Path, poolAddr)
	beforeBalance1 := getTokenBalance(t, pool.token1Path, poolAddr)

	// Approve tokens for pool
	approveTokensForPool(t, pool)

	// Add liquidity
	testing.SetRealm(posRealm)
	amount0, amount1 := Mint(
		cross,
		pool.token0Path,
		pool.token1Path,
		pool.fee,
		positionAddr,
		scenario.tickLower,
		scenario.tickUpper,
		scenario.amount,
		adminAddr,
	)

	// Verify state changes
	afterLiquidity := pool.liquidity
	afterBalance0 := getTokenBalance(t, pool.token0Path, poolAddr)
	afterBalance1 := getTokenBalance(t, pool.token1Path, poolAddr)

	// Verify immutability
	uassert.True(t, afterLiquidity.Cmp(beforeLiquidity) >= 0,
		"Total liquidity should not decrease after adding liquidity")
	uassert.True(t, afterBalance0 >= beforeBalance0,
		"Token0 balance should not decrease")
	uassert.True(t, afterBalance1 >= beforeBalance1,
		"Token1 balance should not decrease")

	return amount0, amount1
}

func verifyPriceCumulativeAccuracy(t *testing.T, pool *Pool, timeElapsed int64, expectedTick int32) {
	t.Helper()

	beforeCumulative := pool.observation.tickCumulative
	beforeTime := pool.observation.lastCumulativeUpdateTime

	// Update price cumulative
	pool.updatePriceCumulatives(beforeTime + timeElapsed)

	afterCumulative := pool.observation.tickCumulative
	actualIncrease := afterCumulative - beforeCumulative
	expectedIncrease := int64(expectedTick) * timeElapsed

	uassert.Equal(t, expectedIncrease, actualIncrease,
		ufmt.Sprintf("Price cumulative calculation is inaccurate: current tick(%d) * time(%d) != actual increase(%d)",
			expectedTick, timeElapsed, actualIncrease))
}

func TestPriceCumulative_BusinessScenarios(t *testing.T) {
	scenarios := []struct {
		name        string
		description string
		setupEnv    func() *PoolTestEnv
		timeElapsed int64
		context     string
	}{
		{
			name:        "stablecoin_pair_hourly_accumulation",
			description: "Stablecoin pair's 1-hour price accumulation",
			setupEnv: func() *PoolTestEnv {
				return NewPoolTestEnv(t).
					AsAdmin().
					GivenPoolCreated(barPath, bazPath, FeeTier100, EQUAL_PRICE_RATIO)
			},
			timeElapsed: ONE_HOUR,
			context:     "Precise accumulation is important for high-volume stablecoin pairs",
		},
		{
			name:        "volatile_pair_minute_precision",
			description: "Volatile token's minute-level precise accumulation",
			setupEnv: func() *PoolTestEnv {
				return NewPoolTestEnv(t).
					AsAdmin().
					GivenPoolCreated(fooPath, barPath, FeeTier3000, VOLATILE_PRICE_RATIO)
			},
			timeElapsed: ONE_MINUTE,
			context:     "Precise accumulation is important even for fast price volatility",
		},
		{
			name:        "daily_accumulation_stability",
			description: "Daily accumulation stability verification",
			setupEnv: func() *PoolTestEnv {
				return NewPoolTestEnv(t).
					AsAdmin().
					GivenPoolCreated(barPath, bazPath, FeeTier100, EQUAL_PRICE_RATIO)
			},
			timeElapsed: ONE_DAY,
			context:     "Avoid overflows and precision loss in long-term accumulation",
		},
	}

	for _, scenario := range scenarios {
		t.Run(scenario.name, func(t *testing.T) {
			// Given: Pool with specific business context using DSL
			env := scenario.setupEnv()
			pool := env.pools[GetPoolPath(barPath, bazPath, FeeTier100)]
			if pool == nil {
				pool = env.pools[GetPoolPath(fooPath, barPath, FeeTier3000)]
			}
			initialTick := pool.slot0.tick

			// When: Time passes and price cumulative is updated
			verifyPriceCumulativeAccuracy(t, pool, scenario.timeElapsed, initialTick)

			// Then: Business logic should work exactly as expected
			t.Logf("✓ %s: %s", scenario.description, scenario.context)
			cleanupPool(t, pool.token0Path, pool.token1Path, pool.fee)
		})
	}
}

func TestLiquidityManagement_ProviderStrategies(t *testing.T) {
	strategies := []LiquidityScenario{
		{
			name:             "concentrated_liquidity_strategy",
			description:      "Concentrated liquidity strategy (narrow price range)",
			tickLower:        NARROW_RANGE_LOWER,
			tickUpper:        NARROW_RANGE_UPPER,
			amount:           MEDIUM_LIQUIDITY,
			expectedBehavior: "High fee revenue, high impact loss risk",
		},
		{
			name:             "conservative_wide_range",
			description:      "Conservative strategy (wide price range)",
			tickLower:        WIDE_RANGE_LOWER,
			tickUpper:        WIDE_RANGE_UPPER,
			amount:           LARGE_LIQUIDITY,
			expectedBehavior: "Stable fee revenue, low impact loss risk",
		},
		{
			name:             "full_range_passive",
			description:      "Passive strategy (full range)",
			tickLower:        FULL_RANGE_LOWER,
			tickUpper:        FULL_RANGE_UPPER,
			amount:           SMALL_LIQUIDITY,
			expectedBehavior: "Minimum management, market average yield",
		},
	}

	for _, strategy := range strategies {
		t.Run(strategy.name, func(t *testing.T) {
			// Given: Volatile token pool
			pool := setupVolatilePool(t)

			// When: Provide liquidity with specific strategy
			amount0, amount1 := addLiquidityWithValidation(t, pool, strategy)

			// Then: Verify result matches strategy
			validateLiquidityStrategy(t, pool, strategy, amount0, amount1)

			t.Logf("✓ %s: %s", strategy.description, strategy.expectedBehavior)
			cleanupPool(t, pool.token0Path, pool.token1Path, pool.fee)
		})
	}
}

func TestMint_SecurityAndValidation(t *testing.T) {
	securityTests := []struct {
		name           string
		description    string
		setupCondition func(t *testing.T) *Pool
		action         func(t *testing.T, pool *Pool)
		expectedResult string
		securityRisk   string
	}{
		{
			name:           "prevent_zero_liquidity_exploit",
			description:    "Prevent zero liquidity position creation attempt",
			setupCondition: setupStablecoinPool,
			action: func(t *testing.T, pool *Pool) {
				approveTokensForPool(t, pool)
				testing.SetRealm(posRealm)

				expectedAbortMsg := "[GNOSWAP-POOL-010] zero liquidity"
				uassert.AbortsWithMessage(t, expectedAbortMsg, func() {
					Mint(cross, pool.token0Path, pool.token1Path, pool.fee,
						positionAddr, NARROW_RANGE_LOWER, NARROW_RANGE_UPPER, "0", adminAddr)
				})
			},
			expectedResult: "Transaction aborted",
			securityRisk:   "Prevent accounting errors due to empty position",
		},
		{
			name:           "prevent_invalid_tick_range",
			description:    "Prevent error due to invalid tick range",
			setupCondition: setupVolatilePool,
			action: func(t *testing.T, pool *Pool) {
				approveTokensForPool(t, pool)
				testing.SetRealm(posRealm)

				tickLower := int32(100)
				tickUpper := int32(50)

				// tickLower > tickUpper
				expectedAbortMsg := ufmt.Sprintf(
					"[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(%d), tickUpper(%d)",
					tickLower, tickUpper)
				uassert.AbortsWithMessage(t,
					expectedAbortMsg,
					func() {
						Mint(cross, pool.token0Path, pool.token1Path, pool.fee,
							positionAddr, tickLower, tickUpper, SMALL_LIQUIDITY, adminAddr)
					})
			},
			expectedResult: "Transaction aborted",
			securityRisk:   "Prevent pool state contamination due to invalid price range",
		},
		{
			name:           "liquidity_overflow_protection",
			description:    "Prevent liquidity overflow attack",
			setupCondition: setupStablecoinPool,
			action: func(t *testing.T, pool *Pool) {
				approveTokensForPool(t, pool)
				testing.SetRealm(posRealm)

				// Maximum allowed liquidity overflow attempt
				maxLiquidity := pool.maxLiquidityPerTick
				overflowAmount := new(u256.Uint).Add(maxLiquidity, u256.One()).ToString()

				expectedAbortMsg := ufmt.Sprintf(
					"[GNOSWAP-POOL-009] invalid liquidity calculated || liquidityGrossAfter(%s) overflows maxLiquidity(%s)",
					overflowAmount, maxLiquidity.ToString())
				uassert.AbortsWithMessage(t, expectedAbortMsg,
					func() {
						Mint(cross, pool.token0Path, pool.token1Path, pool.fee,
							positionAddr, NARROW_RANGE_LOWER, NARROW_RANGE_UPPER,
							overflowAmount, adminAddr)
					})
			},
			expectedResult: "Transaction aborted",
			securityRisk:   "Prevent financial loss due to integer overflow",
		},
	}

	for _, test := range securityTests {
		t.Run(test.name, func(t *testing.T) {
			// Given: Set up security test conditions
			pool := test.setupCondition(t)

			// When: Execute security risk scenario
			test.action(t, pool)

			// Then: Verify appropriate security measures
			t.Logf("✓ %s: %s - %s", test.description, test.expectedResult, test.securityRisk)

			cleanupPool(t, pool.token0Path, pool.token1Path, pool.fee)
		})
	}
}

func TestBurn_LiquidityWithdrawalScenarios(t *testing.T) {
	withdrawalScenarios := []struct {
		name             string
		description      string
		initialLiquidity string
		burnAmount       string
		expectedOutcome  string
		businessContext  string
	}{
		{
			name:             "partial_withdrawal_strategy",
			description:      "Partial liquidity withdrawal",
			initialLiquidity: LARGE_LIQUIDITY,
			burnAmount:       MEDIUM_LIQUIDITY,
			expectedOutcome:  "Partial liquidity maintained",
			businessContext:  "Partial withdrawal for market volatility response",
		},
		{
			name:             "complete_position_closure",
			description:      "Complete position closure",
			initialLiquidity: MEDIUM_LIQUIDITY,
			burnAmount:       MEDIUM_LIQUIDITY,
			expectedOutcome:  "Complete position removal",
			businessContext:  "Complete withdrawal due to investment strategy change",
		},
		{
			name:             "dust_amount_handling",
			description:      "Dust amount handling",
			initialLiquidity: SMALL_LIQUIDITY,
			burnAmount:       MINIMAL_LIQUIDITY,
			expectedOutcome:  "Minor impact",
			businessContext:  "Consider gas efficiency when handling small amounts",
		},
	}

	for _, scenario := range withdrawalScenarios {
		t.Run(scenario.name, func(t *testing.T) {
			// Given: Set up pool with liquidity
			pool := setupStablecoinPool(t)
			approveTokensForPool(t, pool)

			// Add initial liquidity
			testing.SetRealm(posRealm)
			Mint(cross, pool.token0Path, pool.token1Path, pool.fee,
				positionAddr, WIDE_RANGE_LOWER, WIDE_RANGE_UPPER,
				scenario.initialLiquidity, adminAddr)

			beforeLiquidity := new(u256.Uint).Set(pool.liquidity)

			// When: Withdraw specified amount of liquidity
			amount0, amount1 := Burn(cross, pool.token0Path, pool.token1Path, pool.fee,
				WIDE_RANGE_LOWER, WIDE_RANGE_UPPER, scenario.burnAmount, adminAddr)

			// Then: Verify result matches business context
			afterLiquidity := pool.liquidity
			burnAmountUint := u256.MustFromDecimal(scenario.burnAmount)
			expectedLiquidity := new(u256.Uint).Sub(beforeLiquidity, burnAmountUint)

			uassert.Equal(t, expectedLiquidity.ToString(), afterLiquidity.ToString(),
				"Liquidity withdrawal calculation is inaccurate")

			// Verify that withdrawn tokens are greater than 0 (meaningful withdrawal)
			if scenario.burnAmount != "0" {
				uassert.True(t, amount0 != "0" || amount1 != "0",
					"Tokens should be returned when withdrawing liquidity")
			}

			t.Logf("✓ %s: %s (Token0: %s, Token1: %s)",
				scenario.description, scenario.businessContext, amount0, amount1)

			cleanupPool(t, pool.token0Path, pool.token1Path, pool.fee)
		})
	}
}

func TestCalculateTickCumulative_PrecisionAndEdgeCases(t *testing.T) {
	edgeCases := []struct {
		name             string
		description      string
		initialTick      int32
		liquidity        string
		timeElapsed      int64
		expectedBehavior string
		businessRisk     string
	}{
		{
			name:             "zero_time_elapsed",
			description:      "Accumulation calculation when time elapsed is 0",
			initialTick:      100,
			liquidity:        MEDIUM_LIQUIDITY,
			timeElapsed:      0,
			expectedBehavior: "Maintain existing accumulated value",
			businessRisk:     "Gas waste due to unnecessary calculation",
		},
		{
			name:             "zero_liquidity_pool",
			description:      "Accumulation calculation in a pool with 0 liquidity",
			initialTick:      100,
			liquidity:        "0",
			timeElapsed:      ONE_HOUR,
			expectedBehavior: "Liquidity accumulation does not increase",
			businessRisk:     "Invalid price signal from empty pool",
		},
		{
			name:             "maximum_time_span",
			description:      "Accumulation in a very long time span",
			initialTick:      100,
			liquidity:        LARGE_LIQUIDITY,
			timeElapsed:      ONE_DAY * 365, // 1 year
			expectedBehavior: "Overflow-free accurate calculation",
			businessRisk:     "Reliability of price data from unused pool",
		},
	}

	for _, tt := range edgeCases {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Set up pool with specific conditions
			pool := &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.MustFromDecimal(EQUAL_PRICE_RATIO),
					tick:         tt.initialTick,
				},
				observation: &Observation{
					lastCumulativeUpdateTime: 100,
					tickCumulative:           5000000000,
					liquidityCumulative:      u256.MustFromDecimal("3000000"),
				},
				liquidity: u256.MustFromDecimal(tt.liquidity),
			}

			beforeTickCumulative := pool.observation.tickCumulative
			beforeLiquidityCumulative := new(u256.Uint).Set(pool.observation.liquidityCumulative)
			currentTime := pool.observation.lastCumulativeUpdateTime + tt.timeElapsed

			// When: Execute accumulation calculation
			tickCumulative, liquidityCumulative, lastUpdateTime := pool.calculateTickCumulative(currentTime)

			// Then: Verify expected behavior
			expectedTickIncrease := int64(tt.initialTick) * tt.timeElapsed
			actualTickIncrease := tickCumulative - beforeTickCumulative

			uassert.Equal(t, expectedTickIncrease, actualTickIncrease,
				ufmt.Sprintf("Tick cumulative calculation error: expected(%d) != actual(%d)", expectedTickIncrease, actualTickIncrease))

			// Verify liquidity accumulation (only if liquidity is not 0)
			if tt.liquidity != "0" {
				expectedLiquidityIncrease := new(u256.Uint).Mul(
					u256.MustFromDecimal(tt.liquidity),
					u256.NewUint(uint64(tt.timeElapsed)),
				)
				expectedLiquidityCumulative := new(u256.Uint).Add(beforeLiquidityCumulative, expectedLiquidityIncrease)
				uassert.Equal(t, expectedLiquidityCumulative.ToString(), liquidityCumulative.ToString())
			} else {
				// If liquidity is 0, the accumulated value does not change
				uassert.Equal(t, beforeLiquidityCumulative.ToString(), liquidityCumulative.ToString())
			}

			uassert.Equal(t, currentTime, lastUpdateTime)
			t.Logf("✓ %s: %s (Business risk: %s)", tt.description, tt.expectedBehavior, tt.businessRisk)
		})
	}
}

func TestAccessControl_AuthorizationValidation(t *testing.T) {
	unauthorizedAddr := testutils.TestAddress("unauthorized")

	authTests := []struct {
		name          string
		description   string
		action        func(t *testing.T)
		expectedError string
		securityRisk  string
	}{
		{
			name:        "unauthorized_mint_attempt",
			description: "Unauthorized mint attempt",
			action: func(t *testing.T) {
				pool := setupStablecoinPool(t)
				approveTokensForPool(t, pool)

				testing.SetRealm(std.NewUserRealm(unauthorizedAddr))
				expectedMsg := ufmt.Sprintf("unauthorized: caller %s is not position", unauthorizedAddr.String())
				uassert.AbortsWithMessage(t, expectedMsg, func() {
					Mint(cross, pool.token0Path, pool.token1Path, pool.fee,
						positionAddr, NARROW_RANGE_LOWER, NARROW_RANGE_UPPER, MEDIUM_LIQUIDITY, unauthorizedAddr)
				})

				cleanupPool(t, pool.token0Path, pool.token1Path, pool.fee)
			},
			expectedError: "unauthorized caller rejected",
			securityRisk:  "Unauthorized liquidity manipulation leading to pool state contamination",
		},
		{
			name:        "unauthorized_protocol_fee_collection",
			description: "Unauthorized protocol fee collection attempt",
			action: func(t *testing.T) {
				pool := setupStablecoinPool(t)

				testing.SetRealm(std.NewUserRealm(unauthorizedAddr))
				expectedMsg := ufmt.Sprintf("unauthorized: caller %s is not admin or governance", unauthorizedAddr.String())
				uassert.AbortsWithMessage(t, expectedMsg, func() {
					CollectProtocol(cross, pool.token0Path, pool.token1Path, pool.fee,
						unauthorizedAddr, "100", "100")
				})

				cleanupPool(t, pool.token0Path, pool.token1Path, pool.fee)
			},
			expectedError: "unauthorized caller rejected",
			securityRisk:  "Protocol fee theft attempt",
		},
	}

	for _, test := range authTests {
		t.Run(test.name, func(t *testing.T) {
			// When & Then: Execute authorization validation
			test.action(t)
			t.Logf("✓ %s: %s (Security risk: %s)", test.description, test.expectedError, test.securityRisk)
		})
	}
}

func TestPoolCreation_ValidationAndInitialization(t *testing.T) {
	creationTests := []struct {
		name            string
		description     string
		token0Path      string
		token1Path      string
		fee             uint32
		sqrtPriceX96    string
		expectSuccess   bool
		expectedError   string
		businessContext string
	}{
		{
			name:            "valid_stablecoin_pool",
			description:     "Valid stablecoin pool creation",
			token0Path:      barTokenPath,
			token1Path:      bazTokenPath,
			fee:             FeeTier100,
			sqrtPriceX96:    EQUAL_PRICE_RATIO,
			expectSuccess:   true,
			businessContext: "Stablecoin pair starts at 1:1 ratio",
		},
		{
			name:            "invalid_price_too_low",
			description:     "Invalid price too low pool creation attempt",
			token0Path:      fooTokenPath,
			token1Path:      barTokenPath,
			fee:             FeeTier3000,
			sqrtPriceX96:    "1",
			expectSuccess:   false,
			expectedError:   "[GNOSWAP-POOL-005] out of range for numeric value || sqrtPriceX96(1) is out of range",
			businessContext: "Extreme low price causes system instability",
		},
		{
			name:            "invalid_price_too_high",
			description:     "Invalid price too high pool creation attempt",
			token0Path:      fooTokenPath,
			token1Path:      barTokenPath,
			fee:             FeeTier3000,
			sqrtPriceX96:    "1461446703485210103287273052203988822378723970342",
			expectSuccess:   false,
			expectedError:   "[GNOSWAP-POOL-005] out of range for numeric value || sqrtPriceX96(4295128738) is out of range",
			businessContext: "Extreme high price causes calculation overflow risk",
		},
		{
			name:            "minimum_valid_price",
			description:     "Minimum valid price pool creation",
			token0Path:      barTokenPath,
			token1Path:      bazTokenPath,
			fee:             FeeTier3000,
			sqrtPriceX96:    "4295128739", // MIN_SQRT_RATIO
			expectSuccess:   true,
			businessContext: "Extreme low token should also be tradeable",
		},
		{
			name:            "maximum_valid_price",
			description:     "Maximum valid price pool creation",
			token0Path:      barTokenPath,
			token1Path:      bazTokenPath,
			fee:             FeeTier3000,
			sqrtPriceX96:    "1461446703485210103287273052203988822378723970341", // MAX_SQRT_RATIO-1
			expectSuccess:   true,
			businessContext: "Extreme high token should also be tradeable",
		},
	}

	for _, test := range creationTests {
		t.Run(test.name, func(t *testing.T) {
			// Setup
			testing.SetRealm(adminRealm)
			SetPoolCreationFee(cross, 0)

			defer cleanupPool(t, test.token0Path, test.token1Path, test.fee)

			if test.expectSuccess {
				// When: Expected pool creation success
				CreatePool(cross, test.token0Path, test.token1Path, test.fee, test.sqrtPriceX96)

				// Then: Verify pool is correctly initialized
				poolPath := GetPoolPath(test.token0Path, test.token1Path, test.fee)
				uassert.True(t, ExistsPoolPath(poolPath), "Pool not created")

				pool := mustGetPool(poolPath)
				uassert.Equal(t, test.sqrtPriceX96, pool.slot0.sqrtPriceX96.ToString(), "Initial price setting error")

				t.Logf("✓ %s: Pool creation success (%s)", test.description, test.businessContext)
			} else {
				// When & Then: Expected pool creation failure
				uassert.AbortsWithMessage(t, test.expectedError, func() {
					CreatePool(cross, test.token0Path, test.token1Path, test.fee, test.sqrtPriceX96)
				})

				t.Logf("✓ %s: Appropriately rejected (%s)", test.description, test.businessContext)
			}
		})
	}
}

func TestFeeCollection_RevenueDistribution(t *testing.T) {
	feeTests := []struct {
		name             string
		description      string
		setupScenario    func(t *testing.T) (*Pool, std.Address)
		collectionAmount map[string]string // token0, token1
		expectedBehavior string
		revenueImpact    string
	}{
		{
			name:        "collect_full_available_fees",
			description: "Collect full available fees",
			setupScenario: func(t *testing.T) (*Pool, std.Address) {
				return setupPoolWithTradingActivity(t)
			},
			collectionAmount: map[string]string{"token0": "100", "token1": "100"},
			expectedBehavior: "Collect only actual fees",
			revenueImpact:    "Realize LP fee revenue",
		},
		{
			name:        "collect_zero_amount",
			description: "Request to collect 0 fees",
			setupScenario: func(t *testing.T) (*Pool, std.Address) {
				return setupPoolWithTradingActivity(t)
			},
			collectionAmount: map[string]string{"token0": "0", "token1": "0"},
			expectedBehavior: "Nothing collected",
			revenueImpact:    "Gas cost only, no revenue",
		},
		{
			name:        "collect_nonexistent_position",
			description: "Collect fees from nonexistent position",
			setupScenario: func(t *testing.T) (*Pool, std.Address) {
				pool := setupStablecoinPool(t)
				recipient := testutils.TestAddress("nonexistent")
				return pool, recipient
			},
			collectionAmount: map[string]string{"token0": "100", "token1": "100"},
			expectedBehavior: "Transaction failed",
			revenueImpact:    "Gas loss due to invalid request",
		},
	}

	for _, test := range feeTests {
		t.Run(test.name, func(t *testing.T) {
			// Given: Set up fee collection scenario
			pool, recipient := test.setupScenario(t)

			// Collect must be called by position realm
			testing.SetRealm(posRealm)

			if test.name == "collect_nonexistent_position" {
				tickLower := int32(-400)
				tickUpper := int32(400)
				positionKey, _ := getPositionKey(tickLower, tickUpper)
				expectedError := ufmt.Sprintf(
					"[GNOSWAP-POOL-008] requested data not found || positionKey(%s) does not exist",
					positionKey)
				uassert.AbortsWithMessage(t, expectedError, func() {
					Collect(cross, pool.token0Path, pool.token1Path, pool.fee,
						recipient, tickLower, tickUpper, // Non-existent range
						test.collectionAmount["token0"], test.collectionAmount["token1"])
				})
			} else {
				// When: Execute
				amount0, amount1 := Collect(cross, pool.token0Path, pool.token1Path, pool.fee,
					recipient, WIDE_RANGE_LOWER, WIDE_RANGE_UPPER,
					test.collectionAmount["token0"], test.collectionAmount["token1"])

				// Then: Verify expected collection result
				if test.collectionAmount["token0"] == "0" && test.collectionAmount["token1"] == "0" {
					zeroRequestMsg := "0 request should result in 0 collected"
					uassert.Equal(t, "0", amount0, zeroRequestMsg)
					uassert.Equal(t, "0", amount1, zeroRequestMsg)
				}

				t.Logf("✓ %s: Collected amount(Token0: %s, Token1: %s) - %s",
					test.description, amount0, amount1, test.revenueImpact)
			}

			cleanupPool(t, pool.token0Path, pool.token1Path, pool.fee)
		})
	}
}

func TestProtocolFeeManagement_GovernanceControls(t *testing.T) {
	protocolTests := []struct {
		name             string
		description      string
		setupCondition   func(t *testing.T) *Pool
		feeSettings      map[string]uint32 // protocol fee settings
		collectionAmount map[string]string
		expectedOutcome  string
		governanceImpact string
	}{
		{
			name:             "collect_with_zero_protocol_fees",
			description:      "Collect when protocol fees are 0",
			setupCondition:   setupStablecoinPool,
			feeSettings:      map[string]uint32{"fee0": 0, "fee1": 0},
			collectionAmount: map[string]string{"amount0": "100", "amount1": "100"},
			expectedOutcome:  "Collected amount is 0",
			governanceImpact: "No protocol revenue",
		},
		{
			name:        "collect_with_active_protocol_fees",
			description: "Collect active protocol fees",
			setupCondition: func(t *testing.T) *Pool {
				return setupPoolWithProtocolFees(t)
			},
			feeSettings:      map[string]uint32{"fee0": 10, "fee1": 10},
			collectionAmount: map[string]string{"amount0": "1000000", "amount1": "1000000"},
			expectedOutcome:  "Collect only actual accumulated fees",
			governanceImpact: "Realize protocol revenue",
		},
		{
			name:        "collect_more_than_available",
			description: "Attempt to collect more than available fees",
			setupCondition: func(t *testing.T) *Pool {
				return setupPoolWithProtocolFees(t)
			},
			feeSettings:      map[string]uint32{"fee0": 10, "fee1": 10},
			collectionAmount: map[string]string{"amount0": "999999999999999999", "amount1": "999999999999999999"},
			expectedOutcome:  "Collect only maximum available amount",
			governanceImpact: "Safely handle excessive requests",
		},
	}

	for _, test := range protocolTests {
		t.Run(test.name, func(t *testing.T) {
			// Given: Set up protocol fee test conditions
			pool := test.setupCondition(t)

			// Set protocol fees
			testing.SetRealm(adminRealm)
			if test.feeSettings["fee0"] > 0 || test.feeSettings["fee1"] > 0 {
				SetFeeProtocol(cross, uint8(test.feeSettings["fee0"]), uint8(test.feeSettings["fee1"]))
			}

			// Check state before collection
			beforeFees0 := pool.ProtocolFeesToken0()
			beforeFees1 := pool.ProtocolFeesToken1()

			// When: Collect
			amount0, amount1 := CollectProtocol(cross, pool.token0Path, pool.token1Path, pool.fee,
				adminAddr, test.collectionAmount["amount0"], test.collectionAmount["amount1"])

			// Then: Verify collection result
			afterFees0 := pool.ProtocolFeesToken0()
			afterFees1 := pool.ProtocolFeesToken1()

			// Verify collected amount does not exceed previous balance
			collected0 := u256.MustFromDecimal(amount0)
			collected1 := u256.MustFromDecimal(amount1)

			uassert.True(t, collected0.Cmp(beforeFees0) <= 0,
				"Collected amount exceeds available fees")
			uassert.True(t, collected1.Cmp(beforeFees1) <= 0,
				"Collected amount exceeds available fees")

			// Verify protocol fees are appropriately decreased
			expectedAfter0 := new(u256.Uint).Sub(beforeFees0, collected0)
			expectedAfter1 := new(u256.Uint).Sub(beforeFees1, collected1)

			uassert.Equal(t, expectedAfter0.ToString(), afterFees0.ToString())
			uassert.Equal(t, expectedAfter1.ToString(), afterFees1.ToString())

			t.Logf("✓ %s: %s (Collected: %s/%s) - %s",
				test.description, test.expectedOutcome, amount0, amount1, test.governanceImpact)

			cleanupPool(t, pool.token0Path, pool.token1Path, pool.fee)
		})
	}
}

func setupPoolWithTradingActivity(t *testing.T) (*Pool, std.Address) {
	t.Helper()

	// Create stablecoin pool
	pool := setupStablecoinPool(t)

	// Add liquidity
	approveTokensForPool(t, pool)
	testing.SetRealm(posRealm)
	recipient := adminAddr // Position owner must be adminAddr

	Mint(cross, pool.token0Path, pool.token1Path, pool.fee,
		recipient, WIDE_RANGE_LOWER, WIDE_RANGE_UPPER, LARGE_LIQUIDITY, adminAddr)

	// Execute swap for trading activity simulation
	simulateSwapActivity(t, pool)

	return pool, recipient
}

func setupPoolWithProtocolFees(t *testing.T) *Pool {
	t.Helper()

	// Create pool
	pool := setupStablecoinPool(t)

	// Set protocol fees
	testing.SetRealm(adminRealm)
	SetFeeProtocol(cross, 10, 10) // 10% protocol fee

	// Add liquidity and create protocol fees through trading activity
	approveTokensForPool(t, pool)
	testing.SetRealm(posRealm)

	Mint(cross, pool.token0Path, pool.token1Path, pool.fee,
		positionAddr, WIDE_RANGE_LOWER, WIDE_RANGE_UPPER, LARGE_LIQUIDITY, adminAddr)

	// Create protocol fees through trading activity
	simulateSwapActivity(t, pool)

	return pool
}

func simulateSwapActivity(t *testing.T, pool *Pool) {
	t.Helper()

	// Set tokens and execute swap
	testing.SetOriginCaller(adminAddr)

	// Send tokens to router
	switch pool.token0Path {
	case barTokenPath:
		bar.Transfer(cross, routerAddr, 20000000)
	case bazTokenPath:
		baz.Transfer(cross, routerAddr, 20000000)
	case fooTokenPath:
		foo.Transfer(cross, routerAddr, 20000000)
	}

	switch pool.token1Path {
	case barTokenPath:
		bar.Transfer(cross, routerAddr, 20000000)
	case bazTokenPath:
		baz.Transfer(cross, routerAddr, 20000000)
	case fooTokenPath:
		foo.Transfer(cross, routerAddr, 20000000)
	}

	// Create fees through swap execution
	testing.SetRealm(rouRealm)
	approveTokenForRouter(t, pool.token0Path)

	Swap(cross, pool.token0Path, pool.token1Path, pool.fee,
		adminAddr, true, "1000000", "3945129629379410362911094631", adminAddr)

	testing.SkipHeights(1)
}

func approveTokenForRouter(t *testing.T, tokenPath string) {
	t.Helper()

	switch tokenPath {
	case barTokenPath:
		bar.Approve(cross, poolAddr, maxApprove)
	case bazTokenPath:
		baz.Approve(cross, poolAddr, maxApprove)
	case fooTokenPath:
		foo.Approve(cross, poolAddr, maxApprove)
	}
}

func validateLiquidityStrategy(t *testing.T, pool *Pool, strategy LiquidityScenario, amount0, amount1 string) {
	t.Helper()

	// In case of concentrated liquidity strategy, expect higher token usage
	if strategy.tickLower == NARROW_RANGE_LOWER && strategy.tickUpper == NARROW_RANGE_UPPER {
		// In a narrow range, more tokens are actually used
		uassert.True(t, amount0 != "0" || amount1 != "0",
			"Concentrated liquidity strategy should not result in 0 token usage")
	}

	// In case of full range strategy, expect balanced token usage
	if strategy.tickLower == FULL_RANGE_LOWER && strategy.tickUpper == FULL_RANGE_UPPER {
		// In full range, expect balanced token usage around current price
		uassert.True(t, amount0 != "0" && amount1 != "0",
			"Full range strategy should result in both tokens being used")
	}
}

func approveTokensForPool(t *testing.T, pool *Pool) {
	t.Helper()
	testing.SetRealm(adminRealm)

	// Approve tokens for pool
	switch pool.token0Path {
	case fooTokenPath:
		foo.Approve(cross, poolAddr, maxApprove)
	case barTokenPath:
		bar.Approve(cross, poolAddr, maxApprove)
	case bazTokenPath:
		baz.Approve(cross, poolAddr, maxApprove)
	}

	switch pool.token1Path {
	case fooTokenPath:
		foo.Approve(cross, poolAddr, maxApprove)
	case barTokenPath:
		bar.Approve(cross, poolAddr, maxApprove)
	case bazTokenPath:
		baz.Approve(cross, poolAddr, maxApprove)
	}
}

func getTokenBalance(t *testing.T, tokenPath string, addr std.Address) int64 {
	t.Helper()

	switch tokenPath {
	case fooTokenPath:
		return foo.BalanceOf(addr)
	case barTokenPath:
		return bar.BalanceOf(addr)
	case bazTokenPath:
		return baz.BalanceOf(addr)
	default:
		t.Fatalf("Unknown token path: %s", tokenPath)
		return 0
	}
}

func cleanupPool(t *testing.T, token0Path, token1Path string, fee uint32) {
	t.Helper()
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	if ExistsPoolPath(poolPath) {
		pools.Remove(poolPath)
	}
}
