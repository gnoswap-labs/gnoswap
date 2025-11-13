package fuzz

import (
	"strconv"

	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
)

const (
	INITIAL_POOL_PRICE = "79228162514264337593543950337" // sqrt(1) * 2^96

	// Price limits are set to be close to INITIAL_POOL_PRICE to ensure liquidity is available
	// For zeroForOne (price going down), use range from 50% to 99.9% of initial price
	MIN_PRICE_LIMIT_ZERO_FOR_ONE = "39614081257132168796771975168" // ~50% of INITIAL_POOL_PRICE
	MAX_PRICE_LIMIT_ZERO_FOR_ONE = "79228162514264337593543950336" // INITIAL_POOL_PRICE - 1

	// For !zeroForOne (price going up), use range from 100.1% to 200% of initial price
	MIN_PRICE_LIMIT_NOT_ZERO_FOR_ONE = "79228162514264337593543950338"  // INITIAL_POOL_PRICE + 1
	MAX_PRICE_LIMIT_NOT_ZERO_FOR_ONE = "158456325028528675187087900674" // ~200% of INITIAL_POOL_PRICE

	MIN_PRICE_LIMIT = "4295128740"
	MAX_PRICE_LIMIT = "1461446703485210103287273052203988822378723970341"
)

// poolSwapParams is the parameters for Swap/DrySwap fuzzing test
type poolSwapParams struct {
	token0Path        string
	token1Path        string
	fee               uint32
	zeroForOne        bool
	amountSpecified   string
	sqrtPriceLimitX96 string

	isPreDrySwap     bool
	preDrySwapResult bool
	expectedAmount0  string
	expectedAmount1  string
}

func (p *poolSwapParams) SwapAmount() int64 {
	amountInt, _ := strconv.ParseInt(p.amountSpecified, 10, 64)

	if amountInt > 0 {
		return amountInt
	} else {
		if p.zeroForOne {
			expectedAmount0Int, _ := strconv.ParseInt(p.expectedAmount0, 10, 64)
			return expectedAmount0Int
		}

		expectedAmount1Int, _ := strconv.ParseInt(p.expectedAmount1, 10, 64)
		return expectedAmount1Int
	}
}

func (p *poolSwapParams) ToString() string {
	return ufmt.Sprintf("token0: %s, token1: %s, fee: %d, zeroForOne: %t, amount: %s, priceLimit: %s",
		p.token0Path,
		p.token1Path,
		p.fee,
		p.zeroForOne,
		p.amountSpecified,
		p.sqrtPriceLimitX96,
	)
}

func (p *poolSwapParams) PreDrySwap() {
	p.isPreDrySwap = true
	amount0, amount1, success := p.drySwap()

	p.preDrySwapResult = success
	p.expectedAmount0 = amount0
	p.expectedAmount1 = amount1
}

func (p *poolSwapParams) IsValid() bool {
	if !p.isValidBasicParams() {
		return false
	}

	if !p.isValidPoolExists() {
		return false
	}

	if !p.isValidPriceLimitDirection() {
		return false
	}

	if !p.isValidDrySwap() {
		return false
	}

	return true
}

// isValidBasicParams checks basic parameter validity
func (p *poolSwapParams) isValidBasicParams() bool {
	// Amount cannot be "0"
	if p.amountSpecified == "0" || p.amountSpecified == "" {
		return false
	}

	// Fee must be one of the supported tiers
	validFee := false
	for _, tier := range VALID_FEE_TIERS {
		if p.fee == tier {
			validFee = true
			break
		}
	}
	if !validFee {
		return false
	}

	// Token paths must be different and not empty
	if p.token0Path == p.token1Path || p.token0Path == "" || p.token1Path == "" {
		return false
	}

	// Token paths must be in canonical order (token0 < token1)
	if p.token0Path > p.token1Path {
		return false
	}

	return true
}

// isValidPoolExists checks if the pool exists
func (p *poolSwapParams) isValidPoolExists() bool {
	poolPath := pool.GetPoolPath(p.token0Path, p.token1Path, p.fee)
	return pool.ExistsPoolPath(poolPath)
}

// isValidPriceLimitDirection checks if price limit direction is correct
func (p *poolSwapParams) isValidPriceLimitDirection() bool {
	poolPath := pool.GetPoolPath(p.token0Path, p.token1Path, p.fee)
	currentPrice := pool.GetSlot0SqrtPriceX96(poolPath)

	priceLimit := u256.MustFromDecimal(p.sqrtPriceLimitX96)
	minSqrtRatio := u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)

	// For zeroForOne (selling token0 for token1), price goes down
	// Price limit must be less than current price
	if p.zeroForOne {
		if priceLimit.Cmp(minSqrtRatio) <= 0 {
			return false
		}
		// Price limit should be less than current price (going down)
		if priceLimit.Cmp(currentPrice) >= 0 {
			return false // Invalid: price limit must be lower than current when selling token0
		}
	} else {
		// For !zeroForOne (selling token1 for token0), price goes up
		// Price limit must be greater than current price
		if priceLimit.Cmp(maxSqrtRatio) > 0 {
			return false
		}
		// Price limit should be greater than current price (going up)
		if priceLimit.Cmp(currentPrice) <= 0 {
			return false // Invalid: price limit must be higher than current when selling token1
		}
	}

	return true
}

// isValidDrySwap checks if DrySwap succeeds with the given parameters and user has sufficient balance
func (p *poolSwapParams) isValidDrySwap() bool {
	if p.isPreDrySwap {
		return p.preDrySwapResult
	}

	amount0, amount1, success := p.drySwap()
	p.expectedAmount0 = amount0
	p.expectedAmount1 = amount1

	if !success {
		return false
	}

	// Determine which token is being paid (positive delta)
	requiredTokenPath, requiredAmountStr := p.getRequiredPayment(amount0, amount1)

	// No payment needed
	if requiredTokenPath == "" {
		return true
	}

	// Parse required amount
	requiredAmount, err := u256.FromDecimal(requiredAmountStr)
	if err != nil {
		return false
	}

	// Check admin's balance
	return p.hasEnoughBalance(requiredTokenPath, requiredAmount)
}

// getRequiredPayment determines which token and amount is required for the swap
func (p *poolSwapParams) getRequiredPayment(amount0, amount1 string) (tokenPath string, amount string) {
	if p.zeroForOne {
		// Selling token0 for token1: amount0 is positive (what we pay)
		if isPositiveAmount(amount0) {
			return p.token0Path, amount0
		}
	} else {
		// Selling token1 for token0: amount1 is positive (what we pay)
		if isPositiveAmount(amount1) {
			return p.token1Path, amount1
		}
	}
	return "", ""
}

// isPositiveAmount checks if the amount string represents a positive non-zero value
func isPositiveAmount(amount string) bool {
	return len(amount) > 0 && amount[0] != '-' && amount != "0"
}

// hasEnoughBalance checks if admin has enough balance for the required amount
func (p *poolSwapParams) hasEnoughBalance(tokenPath string, requiredAmount *u256.Uint) bool {
	adminBalance := common.BalanceOf(tokenPath, adminAddr)
	if adminBalance < 0 {
		return false
	}
	adminBalanceUint := u256.NewUint(uint64(adminBalance))
	return adminBalanceUint.Cmp(requiredAmount) >= 0
}

// drySwap calls pool.DrySwap with panic recovery
func (p *poolSwapParams) drySwap() (amountIn string, amountOut string, success bool) {
	revive(func() {
		func(cur realm) {
			amountIn, amountOut, success = pool.DrySwap(
				p.token0Path,
				p.token1Path,
				p.fee,
				p.zeroForOne,
				p.amountSpecified,
				p.sqrtPriceLimitX96,
			)
		}(cross)
	})

	if amountIn == "0" || amountOut == "0" {
		return "0", "0", false
	}

	return amountIn, amountOut, success
}

// generatePriceLimitFromCurrent generates a valid price limit based on the current price
func generatePriceLimitFromCurrent(t *fuzz.T, currentPriceStr string, zeroForOne bool) string {
	currentPrice := u256.MustFromDecimal(currentPriceStr)
	minSqrtRatio := u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)

	if zeroForOne {
		// Price going down: generate price limit between MIN_SQRT_RATIO and currentPrice
		// Use range from MAX(MIN_SQRT_RATIO+1, currentPrice*0.5) to currentPrice-1
		minLimit := u256.NewUint(0).Div(currentPrice, u256.NewUint(2)) // 50% of current
		if minLimit.Cmp(minSqrtRatio) <= 0 {
			minLimit = u256.NewUint(0).Add(minSqrtRatio, u256.NewUint(1))
		}
		maxLimit := u256.NewUint(0).Sub(currentPrice, u256.NewUint(1))

		if maxLimit.Cmp(minLimit) <= 0 {
			// If range is invalid, use minLimit
			return minLimit.ToString()
		}

		priceLimit := fuzz.Uint256Range(minLimit.ToString(), maxLimit.ToString()).Draw(t, "priceLimit").(*u256.Uint)
		return priceLimit.ToString()
	}

	// Price going up: generate price limit between currentPrice and MAX_SQRT_RATIO
	// Use range from currentPrice+1 to MIN(MAX_SQRT_RATIO-1, currentPrice*2)
	minLimit := u256.NewUint(0).Add(currentPrice, u256.NewUint(1))
	maxLimit := u256.NewUint(0).Mul(currentPrice, u256.NewUint(2)) // 200% of current
	if maxLimit.Cmp(maxSqrtRatio) >= 0 {
		maxLimit = u256.NewUint(0).Sub(maxSqrtRatio, u256.NewUint(1))
	}

	if minLimit.Cmp(maxLimit) >= 0 {
		// If range is invalid, use maxLimit
		return maxLimit.ToString()
	}

	priceLimit := fuzz.Uint256Range(minLimit.ToString(), maxLimit.ToString()).Draw(t, "priceLimit").(*u256.Uint)
	return priceLimit.ToString()
}

func NewValidPoolSwapParams(t *fuzz.T) *poolSwapParams {
	// Generate random token pair
	token0Path, token1Path := generateTokenPair(t)

	// Generate valid fee tier
	feeIndex := fuzz.IntRange(0, len(VALID_FEE_TIERS)-1).Draw(t, "feeIndex").(int)
	fee := VALID_FEE_TIERS[feeIndex]

	// Generate swap direction
	zeroForOne := fuzz.Bool().Draw(t, "zeroForOne").(bool)

	// Generate valid amount (reasonable range for swap)
	amountInt := fuzz.Int64Range(100000000, 1000000000000).Draw(t, "amount").(int64)
	isExactOutput := fuzz.Bool().Draw(t, "isExactOutput").(bool)

	var amountStr string
	if isExactOutput {
		amountStr = ufmt.Sprintf("-%d", amountInt)
	} else {
		amountStr = ufmt.Sprintf("%d", amountInt)
	}

	sqrtPriceLimitX96 := INITIAL_POOL_PRICE

	if zeroForOne {
		sqrtPriceLimitX96 = MIN_PRICE_LIMIT
	} else {
		sqrtPriceLimitX96 = MAX_PRICE_LIMIT
	}

	return &poolSwapParams{
		token0Path:        token0Path,
		token1Path:        token1Path,
		fee:               fee,
		zeroForOne:        zeroForOne,
		amountSpecified:   amountStr,
		sqrtPriceLimitX96: sqrtPriceLimitX96,
	}
}

func NewRandomizedPoolSwapParams(t *fuzz.T) *poolSwapParams {
	// Generate random token pair
	token0Path, token1Path := generateTokenPair(t)

	// Use valid fee tier
	feeIndex := fuzz.IntRange(0, len(VALID_FEE_TIERS)-1).Draw(t, "feeIndex").(int)
	fee := VALID_FEE_TIERS[feeIndex]

	// Random direction
	zeroForOne := fuzz.Bool().Draw(t, "zeroForOne").(bool)

	// Randomize amount - use wider range for testing edge cases
	amountInt := fuzz.Int64Range(1, 100000000).Draw(t, "amount").(int64)
	isExactOutput := fuzz.Bool().Draw(t, "isExactOutput").(bool)

	var amountStr string
	if isExactOutput {
		amountStr = ufmt.Sprintf("-%d", amountInt)
	} else {
		amountStr = ufmt.Sprintf("%d", amountInt)
	}

	sqrtPriceLimitX96 := fuzz.Uint256Range(MIN_PRICE_LIMIT, MAX_PRICE_LIMIT).Draw(t, "priceLimit").(*u256.Uint)

	return &poolSwapParams{
		token0Path:        token0Path,
		token1Path:        token1Path,
		fee:               fee,
		zeroForOne:        zeroForOne,
		amountSpecified:   amountStr,
		sqrtPriceLimitX96: sqrtPriceLimitX96.ToString(),
	}
}

// setPriceLimit sets the price limit based on pool's current price and swap direction
func (p *poolSwapParams) setPriceLimit(t *fuzz.T) {
	poolPath := pool.GetPoolPath(p.token0Path, p.token1Path, p.fee)
	if !pool.ExistsPoolPath(poolPath) {
		return
	}

	currentPriceUint := pool.GetSlot0SqrtPriceX96(poolPath)
	p.sqrtPriceLimitX96 = generatePriceLimitFromCurrent(t, currentPriceUint.ToString(), p.zeroForOne)
}
