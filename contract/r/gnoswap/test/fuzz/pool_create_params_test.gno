package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
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

	// Fee must be one of the supported tiers
	if p.fee != 100 && p.fee != 500 && p.fee != 3000 && p.fee != 10000 {
		return false
	}

	// sqrtPriceX96 must be parseable and within valid range
	sqrtPrice, err := u256.FromDecimal(p.sqrtPriceX96)
	if err != nil {
		return false
	}

	// MIN_SQRT_RATIO = 4295128739
	minSqrtRatio := u256.MustFromDecimal("4295128739")
	// MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342
	maxSqrtRatio := u256.MustFromDecimal("1461446703485210103287273052203988822378723970342")

	if sqrtPrice.Cmp(minSqrtRatio) < 0 || sqrtPrice.Cmp(maxSqrtRatio) > 0 {
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
	feeTiers := []uint32{100, 500, 3000, 10000}
	feeIndex := fuzz.IntRange(0, len(feeTiers)-1).Draw(t, "feeIndex").(int)
	fee := feeTiers[feeIndex]

	// Generate valid sqrtPriceX96 within range
	// Use a reasonable range for testing: 10^18 to 10^30
	minPrice := "1000000000000000000"          // 10^18
	maxPrice := "1000000000000000000000000000" // 10^27
	sqrtPriceVal := fuzz.Uint256Range(minPrice, maxPrice).Draw(t, "sqrtPrice").(*u256.Uint)

	return &poolCreateParams{
		token0Path:   "gno.land/r/onbloc/bar",
		token1Path:   "gno.land/r/onbloc/foo",
		fee:          fee,
		sqrtPriceX96: sqrtPriceVal.ToString(),
	}
}

func NewRandomizedPoolCreateParams(t *fuzz.T) *poolCreateParams {
	// Generate random fee (may be invalid)
	fee := fuzz.Uint32Range(0, 20000).Draw(t, "fee").(uint32)

	// Generate random sqrtPriceX96 (may be invalid)
	// Use wider range to test boundary conditions
	sqrtPriceVal := fuzz.Uint256Max("2000000000000000000000000000000000000").Draw(t, "sqrtPrice").(*u256.Uint)

	// Token paths with potential issues
	tokens := []string{
		"gno.land/r/onbloc/bar",
		"gno.land/r/onbloc/foo",
		"gno.land/r/onbloc/baz",
		"gnot",
		"",
	}

	token0Index := fuzz.IntRange(0, len(tokens)-1).Draw(t, "token0Index").(int)
	token1Index := fuzz.IntRange(0, len(tokens)-1).Draw(t, "token1Index").(int)

	return &poolCreateParams{
		token0Path:   tokens[token0Index],
		token1Path:   tokens[token1Index],
		fee:          fee,
		sqrtPriceX96: sqrtPriceVal.ToString(),
	}
}
