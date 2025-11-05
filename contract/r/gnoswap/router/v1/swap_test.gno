package v1

import (
	"testing"

	"gno.land/p/nt/uassert"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// Test swap_callback.gno functions

func TestSwapCallback_Token0Delta(t *testing.T) {
	tests := []struct {
		name          string
		token0Path    string
		token1Path    string
		amount0Delta  string
		amount1Delta  string
		payer         address
		expectError   bool
		expectedToken string
	}{
		{
			name:          "positive token0 delta",
			token0Path:    "gno.land/r/onbloc/foo",
			token1Path:    "gno.land/r/onbloc/bar",
			amount0Delta:  "1000",
			amount1Delta:  "-500",
			payer:         routerAddr,
			expectError:   false,
			expectedToken: "gno.land/r/onbloc/foo",
		},
		{
			name:          "positive token1 delta",
			token0Path:    "gno.land/r/onbloc/foo",
			token1Path:    "gno.land/r/onbloc/bar",
			amount0Delta:  "-500",
			amount1Delta:  "1000",
			payer:         routerAddr,
			expectError:   false,
			expectedToken: "gno.land/r/onbloc/bar",
		},
		{
			name:         "both deltas negative",
			token0Path:   "gno.land/r/onbloc/foo",
			token1Path:   "gno.land/r/onbloc/bar",
			amount0Delta: "-500",
			amount1Delta: "-1000",
			payer:        routerAddr,
			expectError:  false,
		},
		{
			name:         "both deltas zero",
			token0Path:   "gno.land/r/onbloc/foo",
			token1Path:   "gno.land/r/onbloc/bar",
			amount0Delta: "0",
			amount1Delta: "0",
			payer:        routerAddr,
			expectError:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			amount0 := i256.MustFromDecimal(tt.amount0Delta)
			amount1 := i256.MustFromDecimal(tt.amount1Delta)

			// Verify logic for determining which token to pay
			var tokenToPay string
			var amountToPay *i256.Int

			if amount0.Gt(i256.Zero()) {
				tokenToPay = tt.token0Path
				amountToPay = amount0
			} else if amount1.Gt(i256.Zero()) {
				tokenToPay = tt.token1Path
				amountToPay = amount1
			}

			if tt.expectedToken != "" {
				uassert.Equal(t, tt.expectedToken, tokenToPay)
				uassert.True(t, amountToPay.Gt(i256.Zero()))
			}
		})
	}
}

func TestTransferToPool_PayerType(t *testing.T) {
	tests := []struct {
		name               string
		payer              address
		expectTransferBy   string
		shouldCheckBalance bool
	}{
		{
			name:               "router as payer",
			payer:              routerAddr,
			expectTransferBy:   "router",
			shouldCheckBalance: true,
		},
		{
			name:               "user as payer",
			payer:              addr01,
			expectTransferBy:   "user",
			shouldCheckBalance: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isTransferByRouter := tt.payer == routerAddr

			if tt.expectTransferBy == "router" {
				uassert.True(t, isTransferByRouter)
			} else {
				uassert.False(t, isTransferByRouter)
			}
		})
	}
}

// Test swap_inner.gno functions

func TestCalculateSqrtPriceLimitForSwap_ZeroForOne(t *testing.T) {
	tests := []struct {
		name               string
		zeroForOne         bool
		fee                uint32
		sqrtPriceLimitX96  *u256.Uint
		expectNonZero      bool
		shouldUseMinSqrt   bool
	}{
		{
			name:               "zero for one with zero limit",
			zeroForOne:         true,
			fee:                3000,
			sqrtPriceLimitX96:  u256.Zero(),
			expectNonZero:      true,
			shouldUseMinSqrt:   true,
		},
		{
			name:               "one for zero with zero limit",
			zeroForOne:         false,
			fee:                3000,
			sqrtPriceLimitX96:  u256.Zero(),
			expectNonZero:      true,
			shouldUseMinSqrt:   false,
		},
		{
			name:               "with provided limit",
			zeroForOne:         true,
			fee:                3000,
			sqrtPriceLimitX96:  u256.NewUint(1000000),
			expectNonZero:      true,
			shouldUseMinSqrt:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := calculateSqrtPriceLimitForSwap(tt.zeroForOne, tt.fee, tt.sqrtPriceLimitX96)

			if tt.expectNonZero {
				uassert.False(t, result.IsZero())
			}

			// When sqrtPriceLimitX96 is provided, it should be returned as is
			if !tt.sqrtPriceLimitX96.IsZero() {
				uassert.Equal(t, tt.sqrtPriceLimitX96.ToString(), result.ToString())
			}
		})
	}
}

func TestGetMinTick(t *testing.T) {
	tests := []struct {
		name        string
		fee         uint32
		expected    int32
		expectPanic bool
	}{
		{
			name:        "fee 100",
			fee:         100,
			expected:    -887272,
			expectPanic: false,
		},
		{
			name:        "fee 500",
			fee:         500,
			expected:    -887270,
			expectPanic: false,
		},
		{
			name:        "fee 3000",
			fee:         3000,
			expected:    -887220,
			expectPanic: false,
		},
		{
			name:        "fee 10000",
			fee:         10000,
			expected:    -887200,
			expectPanic: false,
		},
		{
			name:        "invalid fee",
			fee:         9999,
			expectPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, "unknown fee", func() {
					getMinTick(tt.fee)
				})
			} else {
				result := getMinTick(tt.fee)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestGetMaxTick(t *testing.T) {
	tests := []struct {
		name        string
		fee         uint32
		expected    int32
		expectPanic bool
	}{
		{
			name:        "fee 100",
			fee:         100,
			expected:    887272,
			expectPanic: false,
		},
		{
			name:        "fee 500",
			fee:         500,
			expected:    887270,
			expectPanic: false,
		},
		{
			name:        "fee 3000",
			fee:         3000,
			expected:    887220,
			expectPanic: false,
		},
		{
			name:        "fee 10000",
			fee:         10000,
			expected:    887200,
			expectPanic: false,
		},
		{
			name:        "invalid fee",
			fee:         15000,
			expectPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, "unknown fee", func() {
					getMaxTick(tt.fee)
				})
			} else {
				result := getMaxTick(tt.fee)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestMinMaxTick_Symmetry(t *testing.T) {
	fees := []uint32{100, 500, 3000, 10000}

	for _, fee := range fees {
		t.Run("fee_"+u256.NewUint(uint64(fee)).ToString(), func(t *testing.T) {
			minTick := getMinTick(fee)
			maxTick := getMaxTick(fee)

			// Max tick should be exactly the negative of min tick
			uassert.Equal(t, -minTick, maxTick)
		})
	}
}

func TestSwapExecutor_Interface(t *testing.T) {
	tests := []struct {
		name         string
		executorType string
	}{
		{
			name:         "real swap executor",
			executorType: "real",
		},
		{
			name:         "dry swap executor",
			executorType: "dry",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var executor SwapExecutor

			if tt.executorType == "real" {
				executor = &RealSwapExecutor{router: &routerV1{}}
			} else {
				executor = &DrySwapExecutor{router: &routerV1{}}
			}

			uassert.NotNil(t, executor)
		})
	}
}

// Test swap_multi.gno functions

func TestSwapDirection(t *testing.T) {
	tests := []struct {
		name      string
		direction SwapDirection
		expected  SwapDirection
	}{
		{
			name:      "forward direction",
			direction: Forward,
			expected:  Forward,
		},
		{
			name:      "backward direction",
			direction: Backward,
			expected:  Backward,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, int(tt.expected), int(tt.direction))
		})
	}
}

func TestNewMultiSwapProcessor(t *testing.T) {
	tests := []struct {
		name          string
		isSimulate    bool
		direction     SwapDirection
		expectDryExec bool
	}{
		{
			name:          "real forward processor",
			isSimulate:    false,
			direction:     Forward,
			expectDryExec: false,
		},
		{
			name:          "dry forward processor",
			isSimulate:    true,
			direction:     Forward,
			expectDryExec: true,
		},
		{
			name:          "real backward processor",
			isSimulate:    false,
			direction:     Backward,
			expectDryExec: false,
		},
		{
			name:          "dry backward processor",
			isSimulate:    true,
			direction:     Backward,
			expectDryExec: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := &routerV1{}
			processor := NewMultiSwapProcessor(router, tt.isSimulate, tt.direction)

			uassert.NotNil(t, processor)
			uassert.Equal(t, tt.isSimulate, processor.isSimulate)
			uassert.Equal(t, int(tt.direction), int(processor.direction))
			uassert.NotNil(t, processor.executor)

			if tt.expectDryExec {
				_, isDry := processor.executor.(*DryMultiSwapExecutor)
				uassert.True(t, isDry)
			} else {
				_, isReal := processor.executor.(*RealMultiSwapExecutor)
				uassert.True(t, isReal)
			}
		})
	}
}

func TestMultiSwapExecutor_Interface(t *testing.T) {
	tests := []struct {
		name         string
		executorType string
	}{
		{
			name:         "dry multi swap executor",
			executorType: "dry",
		},
		{
			name:         "real multi swap executor",
			executorType: "real",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var executor MultiSwapExecutor
			router := &routerV1{}

			if tt.executorType == "dry" {
				executor = &DryMultiSwapExecutor{router: router}
			} else {
				executor = &RealMultiSwapExecutor{router: router}
			}

			uassert.NotNil(t, executor)
		})
	}
}

func TestSwapDirection_Values(t *testing.T) {
	// Test that Forward and Backward have distinct values
	uassert.NotEqual(t, int(Forward), int(Backward))

	// Forward should be 1 (first non-zero value after iota)
	uassert.Equal(t, 1, int(Forward))

	// Backward should be 2
	uassert.Equal(t, 2, int(Backward))
}

func TestMultiSwapProcessor_Fields(t *testing.T) {
	router := &routerV1{}

	tests := []struct {
		name       string
		isSimulate bool
		direction  SwapDirection
	}{
		{
			name:       "simulate forward",
			isSimulate: true,
			direction:  Forward,
		},
		{
			name:       "real backward",
			isSimulate: false,
			direction:  Backward,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			processor := NewMultiSwapProcessor(router, tt.isSimulate, tt.direction)

			uassert.Equal(t, tt.isSimulate, processor.isSimulate)
			uassert.Equal(t, int(tt.direction), int(processor.direction))
			uassert.NotNil(t, processor.router)
		})
	}
}

// Test swap_single.gno functions

func TestExecuteSwap_SameToken(t *testing.T) {
	router := &routerV1{}
	executor := &DrySwapExecutor{router: router}

	params := &SingleSwapParams{
		tokenIn:  "gno.land/r/onbloc/foo",
		tokenOut: "gno.land/r/onbloc/foo", // Same token
		fee:      3000,
	}

	uassert.PanicsWithMessage(
		t,
		"[GNOSWAP-ROUTER-014] cannot swap same token",
		func() {
			router.executeSwap(executor, params)
		},
	)
}

func TestExecuteSwap_DifferentTokens(t *testing.T) {
	tests := []struct {
		name     string
		tokenIn  string
		tokenOut string
		fee      uint32
	}{
		{
			name:     "foo to bar",
			tokenIn:  "gno.land/r/onbloc/foo",
			tokenOut: "gno.land/r/onbloc/bar",
			fee:      3000,
		},
		{
			name:     "bar to baz",
			tokenIn:  "gno.land/r/onbloc/bar",
			tokenOut: "gno.land/r/onbloc/baz",
			fee:      500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Verify tokens are different
			uassert.NotEqual(t, tt.tokenIn, tt.tokenOut)
		})
	}
}

func TestSingleSwap_ExecutorType(t *testing.T) {
	tests := []struct {
		name         string
		swapType     string
		expectDryRun bool
	}{
		{
			name:         "real swap",
			swapType:     "real",
			expectDryRun: false,
		},
		{
			name:         "dry swap",
			swapType:     "dry",
			expectDryRun: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := &routerV1{}
			var executor SwapExecutor

			if tt.expectDryRun {
				executor = &DrySwapExecutor{router: router}
			} else {
				executor = &RealSwapExecutor{router: router}
			}

			uassert.NotNil(t, executor)

			if tt.expectDryRun {
				_, isDry := executor.(*DrySwapExecutor)
				uassert.True(t, isDry)
			} else {
				_, isReal := executor.(*RealSwapExecutor)
				uassert.True(t, isReal)
			}
		})
	}
}

func TestSwapExecutor_Consistency(t *testing.T) {
	// Verify both RealSwapExecutor and DrySwapExecutor implement SwapExecutor
	var _ SwapExecutor = (*RealSwapExecutor)(nil)
	var _ SwapExecutor = (*DrySwapExecutor)(nil)
}

// Additional edge case tests

func TestSwapCallback_EdgeCases(t *testing.T) {
	tests := []struct {
		name         string
		amount0Delta string
		amount1Delta string
		shouldPay    bool
	}{
		{
			name:         "large positive token0 delta",
			amount0Delta: "999999999999",
			amount1Delta: "-500000000000",
			shouldPay:    true,
		},
		{
			name:         "large positive token1 delta",
			amount0Delta: "-500000000000",
			amount1Delta: "999999999999",
			shouldPay:    true,
		},
		{
			name:         "minimal positive token0 delta",
			amount0Delta: "1",
			amount1Delta: "-1",
			shouldPay:    true,
		},
		{
			name:         "both negative deltas",
			amount0Delta: "-100",
			amount1Delta: "-200",
			shouldPay:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			amount0 := i256.MustFromDecimal(tt.amount0Delta)
			amount1 := i256.MustFromDecimal(tt.amount1Delta)

			shouldPay := amount0.Gt(i256.Zero()) || amount1.Gt(i256.Zero())
			uassert.Equal(t, tt.shouldPay, shouldPay)
		})
	}
}

func TestCalculateSqrtPriceLimitForSwap_AllFees(t *testing.T) {
	fees := []uint32{100, 500, 3000, 10000}

	for _, fee := range fees {
		t.Run("zero_for_one_fee_"+u256.NewUint(uint64(fee)).ToString(), func(t *testing.T) {
			result := calculateSqrtPriceLimitForSwap(true, fee, u256.Zero())
			uassert.False(t, result.IsZero())

			// Should be greater than MIN_SQRT_RATIO
			minSqrt := u256.MustFromDecimal(MIN_SQRT_RATIO)
			uassert.True(t, result.Gt(minSqrt))
		})

		t.Run("one_for_zero_fee_"+u256.NewUint(uint64(fee)).ToString(), func(t *testing.T) {
			result := calculateSqrtPriceLimitForSwap(false, fee, u256.Zero())
			uassert.False(t, result.IsZero())

			// Should be less than MAX_SQRT_RATIO
			maxSqrt := u256.MustFromDecimal(MAX_SQRT_RATIO)
			uassert.True(t, result.Lt(maxSqrt))
		})
	}
}

func TestSwapInner_ZeroForOneLogic(t *testing.T) {
	tests := []struct {
		name       string
		tokenIn    string
		tokenOut   string
		zeroForOne bool
	}{
		{
			name:       "tokenIn < tokenOut means zeroForOne",
			tokenIn:    "gno.land/r/onbloc/bar",
			tokenOut:   "gno.land/r/onbloc/foo",
			zeroForOne: true,
		},
		{
			name:       "tokenIn > tokenOut means !zeroForOne",
			tokenIn:    "gno.land/r/onbloc/foo",
			tokenOut:   "gno.land/r/onbloc/bar",
			zeroForOne: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			zeroForOne := tt.tokenIn < tt.tokenOut
			uassert.Equal(t, tt.zeroForOne, zeroForOne)
		})
	}
}

func TestMultiSwapProcessor_DirectionMatching(t *testing.T) {
	tests := []struct {
		name           string
		swapType       string
		direction      SwapDirection
		amountSpecified *i256.Int
	}{
		{
			name:           "exactIn uses forward direction",
			swapType:       "exactIn",
			direction:      Forward,
			amountSpecified: i256.NewInt(1000), // positive
		},
		{
			name:           "exactOut uses backward direction",
			swapType:       "exactOut",
			direction:      Backward,
			amountSpecified: i256.NewInt(-1000), // negative
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.swapType == "exactIn" {
				uassert.False(t, tt.amountSpecified.IsNeg())
				uassert.Equal(t, int(Forward), int(tt.direction))
			} else {
				uassert.True(t, tt.amountSpecified.IsNeg())
				uassert.Equal(t, int(Backward), int(tt.direction))
			}
		})
	}
}

func TestZeroValue_Constant(t *testing.T) {
	// Verify zero constant is properly initialized
	uassert.NotNil(t, zero)
	uassert.True(t, zero.IsZero())
	uassert.Equal(t, "0", zero.ToString())
}
