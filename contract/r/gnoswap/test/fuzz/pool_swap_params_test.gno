package fuzz

import (
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
	MIN_PRICE_LIMIT_ZERO_FOR_ONE = "39614081257132168796771975168"                        // ~50% of INITIAL_POOL_PRICE
	MAX_PRICE_LIMIT_ZERO_FOR_ONE = "79228162514264337593543950336"                        // INITIAL_POOL_PRICE - 1

	// For !zeroForOne (price going up), use range from 100.1% to 200% of initial price
	MIN_PRICE_LIMIT_NOT_ZERO_FOR_ONE = "79228162514264337593543950338"                       // INITIAL_POOL_PRICE + 1
	MAX_PRICE_LIMIT_NOT_ZERO_FOR_ONE = "158456325028528675187087900674"                      // ~200% of INITIAL_POOL_PRICE
)

// poolSwapParams is the parameters for Swap/DrySwap fuzzing test
type poolSwapParams struct {
	token0Path        string
	token1Path        string
	fee               uint32
	zeroForOne        bool
	amountSpecified   string
	sqrtPriceLimitX96 string
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

func (p *poolSwapParams) IsValid() bool {
	if !p.isValidBasicParams() {
		return false
	}

	if !p.isValidPriceLimit() {
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

	return true
}

// isValidPriceLimit checks if price limit is parseable and within valid range
func (p *poolSwapParams) isValidPriceLimit() bool {
	priceLimit, err := u256.FromDecimal(p.sqrtPriceLimitX96)
	if err != nil {
		return false
	}

	minSqrtRatio := u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)

	// Price limit must be within bounds
	if priceLimit.Cmp(minSqrtRatio) < 0 || priceLimit.Cmp(maxSqrtRatio) > 0 {
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
	amount0, amount1, success := p.drySwap()

	if !success {
		return false
	}

	var requiredTokenPath string
	var requiredAmount *u256.Uint

	if p.zeroForOne {
		// Selling token0 for token1
		// amount0 is positive (what we pay), amount1 is negative (what we receive)
		if len(amount0) > 0 && amount0[0] != '-' && amount0 != "0" {
			requiredTokenPath = p.token0Path
			var err error
			requiredAmount, err = u256.FromDecimal(amount0)
			if err != nil {
				return false
			}
		} else {
			// No token0 payment needed, valid
			return true
		}
	} else {
		// Selling token1 for token0
		// amount1 is positive (what we pay), amount0 is negative (what we receive)
		if len(amount1) > 0 && amount1[0] != '-' && amount1 != "0" {
			requiredTokenPath = p.token1Path
			var err error
			requiredAmount, err = u256.FromDecimal(amount1)
			if err != nil {
				return false
			}
		} else {
			// No token1 payment needed, valid
			return true
		}
	}

	// Check admin's balance
	adminBalance := common.BalanceOf(requiredTokenPath, adminAddr)
	if adminBalance < 0 {
		return false
	}
	adminBalanceUint := u256.NewUint(uint64(adminBalance))

	// Need sufficient balance
	return adminBalanceUint.Cmp(requiredAmount) >= 0
}

// drySwap calls pool.DrySwap with panic recovery
func (p *poolSwapParams) drySwap() (string, string, bool) {
	return func() (amount0 string, amount1 string, success bool) {
		defer func() {
			if r := recover(); r != nil {
				amount0 = "0"
				amount1 = "0"
				success = false
			}
		}()

		amount0, amount1, success = pool.DrySwap(
			p.token0Path,
			p.token1Path,
			p.fee,
			p.zeroForOne,
			p.amountSpecified,
			p.sqrtPriceLimitX96,
		)

		return amount0, amount1, success
	}()
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
	} else {
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
}

func NewValidPoolSwapParams(t *fuzz.T) *poolSwapParams {
	// Generate valid fee tier
	feeIndex := fuzz.IntRange(0, len(VALID_FEE_TIERS)-1).Draw(t, "feeIndex").(int)
	fee := VALID_FEE_TIERS[feeIndex]

	// Generate swap direction
	zeroForOne := fuzz.Bool().Draw(t, "zeroForOne").(bool)

	// Generate valid amount (reasonable range for swap)
	amountInt := fuzz.Int64Range(1, 1000000).Draw(t, "amount").(int64)
	isExactOutput := fuzz.Bool().Draw(t, "isExactOutput").(bool)

	var amountStr string
	if isExactOutput {
		amountStr = ufmt.Sprintf("-%d", amountInt)
	} else {
		amountStr = ufmt.Sprintf("%d", amountInt)
	}

	return &poolSwapParams{
		token0Path:        BAR_PATH,
		token1Path:        FOO_PATH,
		fee:               fee,
		zeroForOne:        zeroForOne,
		amountSpecified:   amountStr,
		sqrtPriceLimitX96: INITIAL_POOL_PRICE,
	}
}

func NewRandomizedPoolSwapParams(t *fuzz.T) *poolSwapParams {
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

	return &poolSwapParams{
		token0Path:        BAR_PATH,
		token1Path:        FOO_PATH,
		fee:               fee,
		zeroForOne:        zeroForOne,
		amountSpecified:   amountStr,
		sqrtPriceLimitX96: INITIAL_POOL_PRICE,
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
