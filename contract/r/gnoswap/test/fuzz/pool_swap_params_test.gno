package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
)

const (
    MIN_PRICE_LIMIT_ZERO_FOR_ONE     = "4295128740"                                          // MIN_SQRT_RATIO + 1
	MAX_PRICE_LIMIT_ZERO_FOR_ONE     = "79228162514264337593543950336"                       // INITIAL_POOL_PRICE - 1
	MIN_PRICE_LIMIT_NOT_ZERO_FOR_ONE = "79228162514264337593543950338"                       // INITIAL_POOL_PRICE + 1
	MAX_PRICE_LIMIT_NOT_ZERO_FOR_ONE = "1461446703485210103287273052203988822378723970341"   // MAX_SQRT_RATIO - 1
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

func (p *poolSwapParams) IsValid() bool {
	if !p.validateBasicParams() {
		return false
	}

	if !p.validatePriceLimit() {
		return false
	}

	if !p.validatePoolExists() {
		return false
	}

	if !p.validateSwapAmount() {
		return false
	}

	if !p.validatePriceLimitDirection() {
		return false
	}

	return true
}

// validateBasicParams checks basic parameter validity
func (p *poolSwapParams) validateBasicParams() bool {
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

// validatePriceLimit checks if price limit is parseable and within valid range
func (p *poolSwapParams) validatePriceLimit() bool {
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

// validatePoolExists checks if the pool exists
func (p *poolSwapParams) validatePoolExists() bool {
	poolPath := pool.GetPoolPath(p.token0Path, p.token1Path, p.fee)
	return pool.ExistsPoolPath(poolPath)
}

// validateSwapAmount checks if swap amount is valid relative to pool balance
func (p *poolSwapParams) validateSwapAmount() bool {
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	// Get pool's token balances
	poolToken0Balance := common.BalanceOf(p.token0Path, poolAddr)
	poolToken1Balance := common.BalanceOf(p.token1Path, poolAddr)

	// Parse swap amount (handle negative for exact output)
	amountStr := p.amountSpecified
	if len(amountStr) > 0 && amountStr[0] == '-' {
		amountStr = amountStr[1:]
	}

	swapAmount, err := u256.FromDecimal(amountStr)
	if err != nil {
		return false
	}

	// For exact output swap (negative amount), check if output exceeds pool balance
	// Pool needs to have enough tokens to pay out
	if len(p.amountSpecified) > 0 && p.amountSpecified[0] == '-' {
		// This is exact output swap
		var poolBalance int64
		if p.zeroForOne {
			// Selling token0 to get token1, so pool pays token1
			poolBalance = poolToken1Balance
		} else {
			// Selling token1 to get token0, so pool pays token0
			poolBalance = poolToken0Balance
		}

		swapAmountInt64 := int64(0)
		if swapAmount.Lt(u256.NewUint(uint64(1<<63 - 1))) {
			swapAmountInt64 = int64(swapAmount.Uint64())
		} else {
			return false // Amount too large
		}

		// Output amount must not exceed pool balance
		if swapAmountInt64 >= poolBalance {
			return false // Pool doesn't have enough tokens
		}
	}

	return true
}

// validatePriceLimitDirection checks if price limit direction is correct
func (p *poolSwapParams) validatePriceLimitDirection() bool {
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

func NewValidPoolSwapParams(t *fuzz.T) *poolSwapParams {
	// Generate valid fee tier
	feeIndex := fuzz.IntRange(0, len(VALID_FEE_TIERS)-1).Draw(t, "feeIndex").(int)
	fee := VALID_FEE_TIERS[feeIndex]

	// Generate swap direction
	zeroForOne := fuzz.Bool().Draw(t, "zeroForOne").(bool)

	// Generate valid amount (reasonable range for swap)
	// Positive for exact input, negative for exact output
	amountInt := fuzz.Int64Range(1, 100000000).Draw(t, "amount").(int64)
	isExactOutput := fuzz.Bool().Draw(t, "isExactOutput").(bool)

	var amountStr string
	if isExactOutput {
		amountStr = ufmt.Sprintf("-%d", amountInt)
	} else {
		amountStr = ufmt.Sprintf("%d", amountInt)
	}

	// Generate valid price limit based on direction
	var priceLimitStr string
	if zeroForOne {
		// Price going down, use lower range (below current price)
		priceLimit := fuzz.Uint256Range(MIN_PRICE_LIMIT_ZERO_FOR_ONE, MAX_PRICE_LIMIT_ZERO_FOR_ONE).Draw(t, "priceLimit").(*u256.Uint)
		priceLimitStr = priceLimit.ToString()
	} else {
		// Price going up, use higher range (above current price)
		priceLimit := fuzz.Uint256Range(MIN_PRICE_LIMIT_NOT_ZERO_FOR_ONE, MAX_PRICE_LIMIT_NOT_ZERO_FOR_ONE).Draw(t, "priceLimit").(*u256.Uint)
		priceLimitStr = priceLimit.ToString()
	}

	return &poolSwapParams{
		token0Path:        BAR_PATH,
		token1Path:        FOO_PATH,
		fee:               fee,
		zeroForOne:        zeroForOne,
		amountSpecified:   amountStr,
		sqrtPriceLimitX96: priceLimitStr,
	}
}

func NewRandomizedPoolSwapParams(t *fuzz.T) *poolSwapParams {
	// Use valid fee tier
	feeIndex := fuzz.IntRange(0, len(VALID_FEE_TIERS)-1).Draw(t, "feeIndex").(int)
	fee := VALID_FEE_TIERS[feeIndex]

	// Random direction
	zeroForOne := fuzz.Bool().Draw(t, "zeroForOne").(bool)

	// Randomize amount - use wider range for testing edge cases
	amountInt := fuzz.Int64Range(1, 10000000000).Draw(t, "amount").(int64)
	isExactOutput := fuzz.Bool().Draw(t, "isExactOutput").(bool)

	var amountStr string
	if isExactOutput {
		amountStr = ufmt.Sprintf("-%d", amountInt)
	} else {
		amountStr = ufmt.Sprintf("%d", amountInt)
	}

	// Generate valid price limit based on direction
	var priceLimitStr string
	if zeroForOne {
		// Price going down, use lower range (below current price)
		priceLimit := fuzz.Uint256Range(MIN_PRICE_LIMIT_ZERO_FOR_ONE, MAX_PRICE_LIMIT_ZERO_FOR_ONE).Draw(t, "priceLimit").(*u256.Uint)
		priceLimitStr = priceLimit.ToString()
	} else {
		// Price going up, use higher range (above current price)
		priceLimit := fuzz.Uint256Range(MIN_PRICE_LIMIT_NOT_ZERO_FOR_ONE, MAX_PRICE_LIMIT_NOT_ZERO_FOR_ONE).Draw(t, "priceLimit").(*u256.Uint)
		priceLimitStr = priceLimit.ToString()
	}

	return &poolSwapParams{
		token0Path:        BAR_PATH,
		token1Path:        FOO_PATH,
		fee:               fee,
		zeroForOne:        zeroForOne,
		amountSpecified:   amountStr,
		sqrtPriceLimitX96: priceLimitStr,
	}
}
