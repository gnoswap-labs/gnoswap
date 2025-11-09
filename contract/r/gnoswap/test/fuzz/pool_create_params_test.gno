package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/pool"
)

// poolCreateParams is the parameters for the CreatePool fuzzing test.
type poolCreateParams struct {
	token0Path   string
	token1Path   string
	fee          uint32
	sqrtPriceX96 string
}

func (p *poolCreateParams) IsValid() bool {
	// Token paths must be different
	if p.token0Path == p.token1Path {
		return false
	}

	// Token paths must not be empty
	if p.token0Path == "" || p.token1Path == "" {
		return false
	}

	// Token paths must be in canonical order (token0 < token1)
	if p.token0Path > p.token1Path {
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

	// sqrtPriceX96 must be parseable and within valid range
	sqrtPrice, err := u256.FromDecimal(p.sqrtPriceX96)
	if err != nil {
		return false
	}

	minSqrtRatio := u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)

	if sqrtPrice.Cmp(minSqrtRatio) < 0 || sqrtPrice.Cmp(maxSqrtRatio) > 0 {
		return false
	}

	poolPath := pool.GetPoolPath(p.token0Path, p.token1Path, p.fee)
	if pool.ExistsPoolPath(poolPath) {
		return false
	}

	return true
}

func (p *poolCreateParams) ToString() string {
	return ufmt.Sprintf("token0Path: %s, token1Path: %s, fee: %d, sqrtPriceX96: %s",
		p.token0Path,
		p.token1Path,
		p.fee,
		p.sqrtPriceX96,
	)
}

func NewValidPoolCreateParams(t *fuzz.T) *poolCreateParams {
	// Generate valid fee tier
	feeIndex := fuzz.IntRange(0, len(VALID_FEE_TIERS)-1).Draw(t, "feeIndex").(int)
	fee := VALID_FEE_TIERS[feeIndex]

	sqrtPriceVal := fuzz.Uint256Range(MIN_SQRT_RATIO, MAX_SQRT_RATIO).Draw(t, "sqrtPrice").(*u256.Uint)

	// Generate random token pair
	token0Path, token1Path := generateTokenPair(t)

	return &poolCreateParams{
		token0Path:   token0Path,
		token1Path:   token1Path,
		fee:          fee,
		sqrtPriceX96: sqrtPriceVal.ToString(),
	}
}

func NewRandomizedPoolCreateParams(t *fuzz.T) *poolCreateParams {
	// Generate random fee (may be invalid)
	fee := fuzz.Uint32Range(0, 20000).Draw(t, "fee").(uint32)

	sqrtPriceVal := fuzz.Uint256().Draw(t, "sqrtPrice").(*u256.Uint)

	// Generate random token pair
	token0Path, token1Path := generateTokenPair(t)

	return &poolCreateParams{
		token0Path:   token0Path,
		token1Path:   token1Path,
		fee:          fee,
		sqrtPriceX96: sqrtPriceVal.ToString(),
	}
}
