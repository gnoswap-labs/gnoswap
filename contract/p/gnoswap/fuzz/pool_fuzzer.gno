package fuzz

import (
	"errors"
	"strings"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// Constants for pool creation
const (
	MIN_SQRT_RATIO = "4295128739"
	MAX_SQRT_RATIO = "1461446703485210103287273052203988822378723970342"
)

// Supported fee tiers
var SUPPORTED_FEE_TIERS = []uint32{100, 500, 3000, 10000}

// CreatePoolParams represents parameters for CreatePool function
type CreatePoolParams struct {
	Token0Path   string
	Token1Path   string
	Fee          uint32
	SqrtPriceX96 string
}

// CreatePoolResult represents the result of CreatePool operation
type CreatePoolResult struct {
	Success   bool
	Error     error
	ErrorCode string
	PoolPath  string
}

// CreatePoolFuzzer handles fuzz testing for CreatePool function
type CreatePoolFuzzer struct {
	// State management
	pools map[string]*PoolState // poolPath -> PoolState

	// Test configuration
	mode FuzzMode

	// Generators
	tokenGen Generator
	feeGen   Generator
	priceGen Generator

	// Result tracking
	results       []CreatePoolResult
	successCount  int
	failureCount  int
	errorPatterns map[string]int // error code -> count
}

type FuzzMode int

const (
	STATELESS FuzzMode = iota
	STATEFUL
)

// NewCreatePoolFuzzer creates a new CreatePool fuzzer
func NewCreatePoolFuzzer(mode FuzzMode) *CreatePoolFuzzer {
	return &CreatePoolFuzzer{
		pools:         make(map[string]*PoolState),
		mode:          mode,
		tokenGen:      NewTokenPairGenerator(),
		feeGen:        NewFeeTierGenerator(),
		priceGen:      NewSqrtPriceGenerator(),
		results:       make([]CreatePoolResult, 0),
		errorPatterns: make(map[string]int),
	}
}

// Reset clears the fuzzer state (for STATELESS mode)
func (f *CreatePoolFuzzer) Reset() {
	f.pools = make(map[string]*PoolState)
}

// ValidateCreatePoolParams validates CreatePool parameters
func (f *CreatePoolFuzzer) ValidateCreatePoolParams(params CreatePoolParams) CreatePoolResult {
	// Check if tokens are the same
	if params.Token0Path == params.Token1Path {
		return CreatePoolResult{
			Success:   false,
			Error:     errors.New("same token used in single pool"),
			ErrorCode: "POOL-011",
		}
	}

	// Check token order (token0 must be less than token1)
	token0, token1 := params.Token0Path, params.Token1Path
	if token0 > token1 {
		// Swap to maintain order
		token0, token1 = token1, token0
	}

	// Check if fee tier is supported
	feeSupported := false
	for _, supportedFee := range SUPPORTED_FEE_TIERS {
		if params.Fee == supportedFee {
			feeSupported = true
			break
		}
	}
	if !feeSupported {
		return CreatePoolResult{
			Success:   false,
			Error:     errors.New("unsupported fee tier"),
			ErrorCode: "POOL-002",
		}
	}

	// Check if pool already exists
	poolPath := f.makePoolPath(token0, token1, params.Fee)
	if _, exists := f.pools[poolPath]; exists {
		return CreatePoolResult{
			Success:   false,
			Error:     errors.New("pool already exists"),
			ErrorCode: "POOL-009",
		}
	}

	// Validate sqrt price
	sqrtPrice, err := u256.FromDecimal(params.SqrtPriceX96)
	if err != nil {
		return CreatePoolResult{
			Success:   false,
			Error:     errors.New("invalid sqrt price"),
			ErrorCode: "POOL-INVALID-PRICE",
		}
	}

	minPrice, _ := u256.FromDecimal(MIN_SQRT_RATIO)
	maxPrice, _ := u256.FromDecimal(MAX_SQRT_RATIO)

	if sqrtPrice.Cmp(minPrice) < 0 || sqrtPrice.Cmp(maxPrice) > 0 {
		return CreatePoolResult{
			Success:   false,
			Error:     errors.New("sqrt price out of bounds"),
			ErrorCode: "POOL-PRICE-BOUNDS",
		}
	}

	// Create pool
	poolState := &PoolState{
		Token0Path:           token0,
		Token1Path:           token1,
		Fee:                  params.Fee,
		TickSpacing:          f.getTickSpacing(params.Fee),
		CurrentPrice:         sqrtPrice,
		CurrentTick:          f.calculateTickFromSqrtPrice(sqrtPrice),
		CurrentLiquidity:     u256.Zero(),
		Unlocked:             true,
		Balance0:             u256.Zero(),
		Balance1:             u256.Zero(),
		ProtocolFee0:         u256.Zero(),
		ProtocolFee1:         u256.Zero(),
		FeeProtocol:          0,
		FeeGrowthGlobal0X128: u256.Zero(),
		FeeGrowthGlobal1X128: u256.Zero(),
		Positions:            make(map[string]*PositionState),
		ActiveTicks:          make(map[int32]bool),
	}

	f.pools[poolPath] = poolState

	return CreatePoolResult{
		Success:  true,
		Error:    nil,
		PoolPath: poolPath,
	}
}

// FuzzCreatePool runs fuzz testing on CreatePool
func (f *CreatePoolFuzzer) FuzzCreatePool(iterations int) FuzzReport {
	// Generate and test CreatePool parameters
	for i := 0; i < iterations; i++ {
		if f.mode == STATELESS {
			f.Reset()
		}

		// Generate random parameters
		params := f.generateCreatePoolParams()

		// Execute and validate
		result := f.ValidateCreatePoolParams(params)

		// Track results
		f.trackResult(result)
	}

	return f.generateReport()
}

// FuzzCreatePoolWithDebug runs fuzz testing with debug logging
func (f *CreatePoolFuzzer) FuzzCreatePoolWithDebug(iterations int, t *testing.T) FuzzReport {
	// Generate and test CreatePool parameters
	for i := 0; i < iterations; i++ {
		if f.mode == STATELESS {
			f.Reset()
		}

		// Generate random parameters
		params := f.generateCreatePoolParams()

		// Log generated parameters
		t.Logf("Iteration %d: Token0=%s, Token1=%s, Fee=%d, Price=%s",
			i, params.Token0Path, params.Token1Path, params.Fee, params.SqrtPriceX96)

		// Execute and validate
		result := f.ValidateCreatePoolParams(params)

		// Log result
		if result.Success {
			t.Logf("  Result: SUCCESS, PoolPath=%s", result.PoolPath)
		} else {
			t.Logf("  Result: FAILURE, Error=%s, Code=%s", result.Error, result.ErrorCode)
		}

		// Track results
		f.trackResult(result)
	}

	return f.generateReport()
}

// Helper methods
func (f *CreatePoolFuzzer) makePoolPath(token0, token1 string, fee uint32) string {
	return strings.Join([]string{token0, token1, ufmt.Sprintf("%d", fee)}, ":")
}

func (f *CreatePoolFuzzer) getTickSpacing(fee uint32) int32 {
	switch fee {
	case 100:
		return 1
	case 500:
		return 10
	case 3000:
		return 60
	case 10000:
		return 200
	default:
		return 0
	}
}

func (f *CreatePoolFuzzer) calculateTickFromSqrtPrice(sqrtPriceX96 *u256.Uint) int32 {
	// Simplified tick calculation
	// In real implementation, this would use logarithm
	return 0
}

func (f *CreatePoolFuzzer) generateCreatePoolParams() CreatePoolParams {
	// Use the fuzzer's generators
	tokenPair := f.tokenGen.Generate().(TokenPair)
	fee := f.feeGen.Generate().(uint32)
	price := f.priceGen.Generate().(string)

	return CreatePoolParams{
		Token0Path:   tokenPair.Token0,
		Token1Path:   tokenPair.Token1,
		Fee:          fee,
		SqrtPriceX96: price,
	}
}

// GenerateCreatePoolParams returns randomized parameters using the fuzzer's generators.
// Exposed for external tests that need direct access to parameter generation.
func (f *CreatePoolFuzzer) GenerateCreatePoolParams() CreatePoolParams {
	return f.generateCreatePoolParams()
}

func (f *CreatePoolFuzzer) trackResult(result CreatePoolResult) {
	f.results = append(f.results, result)

	if result.Success {
		f.successCount++
	} else {
		f.failureCount++
		if result.ErrorCode != "" {
			f.errorPatterns[result.ErrorCode]++
		}
	}
}

func (f *CreatePoolFuzzer) generateReport() FuzzReport {
	totalTests := f.successCount + f.failureCount
	successRate := float64(f.successCount) / float64(totalTests) * 100

	return FuzzReport{
		TotalTests:    totalTests,
		SuccessCount:  f.successCount,
		FailureCount:  f.failureCount,
		SuccessRate:   successRate,
		ErrorPatterns: f.errorPatterns,
	}
}

// FuzzReport represents the fuzzing test report
type FuzzReport struct {
	TotalTests    int
	SuccessCount  int
	FailureCount  int
	SuccessRate   float64
	ErrorPatterns map[string]int
}
