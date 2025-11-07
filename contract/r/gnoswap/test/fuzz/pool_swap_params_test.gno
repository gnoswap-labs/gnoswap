package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
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
	// Amount cannot be "0"
	if p.amountSpecified == "0" || p.amountSpecified == "" {
		return false
	}

	// Fee must be one of the supported tiers
	if p.fee != 100 && p.fee != 500 && p.fee != 3000 && p.fee != 10000 {
		return false
	}

	// Token paths must be different and not empty
	if p.token0Path == p.token1Path || p.token0Path == "" || p.token1Path == "" {
		return false
	}

	// sqrtPriceLimitX96 must be parseable and within valid range
	priceLimit, err := u256.FromDecimal(p.sqrtPriceLimitX96)
	if err != nil {
		return false
	}

	minSqrtRatio := u256.MustFromDecimal("4295128739")
	maxSqrtRatio := u256.MustFromDecimal("1461446703485210103287273052203988822378723970342")

	// Price limit must be within bounds
	if priceLimit.Cmp(minSqrtRatio) < 0 || priceLimit.Cmp(maxSqrtRatio) > 0 {
		return false
	}

	// For zeroForOne, price limit should be < current price (going down)
	// For !zeroForOne, price limit should be > current price (going up)
	// Without knowing current price, we check reasonable bounds:
	// - zeroForOne: price limit should be > minSqrtRatio and < maxSqrtRatio
	// - !zeroForOne: price limit should be > minSqrtRatio and < maxSqrtRatio
	// Additionally, the price limit should not be exactly at the boundary for the direction
	if p.zeroForOne {
		// Price limit should be strictly greater than MIN and strictly less than MAX
		if priceLimit.Cmp(minSqrtRatio) <= 0 || priceLimit.Cmp(maxSqrtRatio) >= 0 {
			return false
		}
	} else {
		// Price limit should be strictly greater than MIN and less than or equal to MAX
		if priceLimit.Cmp(minSqrtRatio) <= 0 || priceLimit.Cmp(maxSqrtRatio) > 0 {
			return false
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
	feeTiers := []uint32{100, 500, 3000, 10000}
	feeIndex := fuzz.IntRange(0, len(feeTiers)-1).Draw(t, "feeIndex").(int)
	fee := feeTiers[feeIndex]

	// Generate swap direction
	zeroForOne := fuzz.Bool().Draw(t, "zeroForOne").(bool)

	// Generate valid amount (use int64 range for safety)
	// Positive for exact input, negative for exact output
	amountInt := fuzz.Int64Range(1, 1000000000).Draw(t, "amount").(int64)
	isExactOutput := fuzz.Bool().Draw(t, "isExactOutput").(bool)

	var amountStr string
	if isExactOutput {
		amountStr = ufmt.Sprintf("-%d", amountInt)
	} else {
		amountStr = ufmt.Sprintf("%d", amountInt)
	}

	// Generate valid price limit based on direction
	// Initial pool price is sqrt(1.0) = 79228162514264337593543950337
	var priceLimitStr string
	if zeroForOne {
		// Price going down, use lower range (below current price)
		priceLimit := fuzz.Uint256Range("4295128740", "79228162514264337593543950336").Draw(t, "priceLimit").(*u256.Uint)
		priceLimitStr = priceLimit.ToString()
	} else {
		// Price going up, use higher range (above current price)
		priceLimit := fuzz.Uint256Range("79228162514264337593543950338", "1461446703485210103287273052203988822378723970341").Draw(t, "priceLimit").(*u256.Uint)
		priceLimitStr = priceLimit.ToString()
	}

	return &poolSwapParams{
		token0Path:        "gno.land/r/onbloc/bar",
		token1Path:        "gno.land/r/onbloc/foo",
		fee:               fee,
		zeroForOne:        zeroForOne,
		amountSpecified:   amountStr,
		sqrtPriceLimitX96: priceLimitStr,
	}
}

func NewRandomizedPoolSwapParams(t *fuzz.T) *poolSwapParams {
	// Use valid fee tier
	feeTiers := []uint32{100, 500, 3000, 10000}
	feeIndex := fuzz.IntRange(0, len(feeTiers)-1).Draw(t, "feeIndex").(int)
	fee := feeTiers[feeIndex]

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
	// Initial pool price is sqrt(1.0) = 79228162514264337593543950337
	var priceLimitStr string
	if zeroForOne {
		// Price going down, use lower range (below current price)
		priceLimit := fuzz.Uint256Range("4295128740", "79228162514264337593543950336").Draw(t, "priceLimit").(*u256.Uint)
		priceLimitStr = priceLimit.ToString()
	} else {
		// Price going up, use higher range (above current price)
		priceLimit := fuzz.Uint256Range("79228162514264337593543950338", "1461446703485210103287273052203988822378723970341").Draw(t, "priceLimit").(*u256.Uint)
		priceLimitStr = priceLimit.ToString()
	}

	return &poolSwapParams{
		token0Path:        "gno.land/r/onbloc/bar",
		token1Path:        "gno.land/r/onbloc/foo",
		fee:               fee,
		zeroForOne:        zeroForOne,
		amountSpecified:   amountStr,
		sqrtPriceLimitX96: priceLimitStr,
	}
}
