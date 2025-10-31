package fuzz

import (
	u256 "gno.land/p/gnoswap/uint256"
	xs "gno.land/p/wyhaines/rand/xorshift64star"
)

// TokenPair represents a pair of tokens
type TokenPair struct {
	Token0 string
	Token1 string
}

// TokenPairGenerator generates random token pairs
type TokenPairGenerator struct {
	rng       *xs.Xorshift64Star
	tokenList []string
}

func NewTokenPairGenerator() Generator {
	return &TokenPairGenerator{
		rng: nil, // Will be initialized on first use
		tokenList: []string{
			"gno.land/r/onbloc/foo",
			"gno.land/r/onbloc/bar",
			"gno.land/r/onbloc/baz",
			"gno.land/r/onbloc/qux",
			"gno.land/r/demo/wugnot",
			"gno.land/r/gnoswap/gns",
			"gno.land/r/demo/usdc",
			"gno.land/r/demo/weth",
		},
	}
}

func (g *TokenPairGenerator) Generate() any {
	initRNG(&g.rng)

	// 10% chance to generate same token (error case)
	if g.rng.Uint64()%10 == 0 {
		idx := int(g.rng.Uint64() % uint64(len(g.tokenList)))
		token := g.tokenList[idx]
		return TokenPair{
			Token0: token,
			Token1: token,
		}
	}

	// Select two different tokens
	idx1 := int(g.rng.Uint64() % uint64(len(g.tokenList)))
	idx2 := int(g.rng.Uint64() % uint64(len(g.tokenList)))

	// Ensure different tokens
	for idx2 == idx1 {
		idx2 = int(g.rng.Uint64() % uint64(len(g.tokenList)))
	}

	token0 := g.tokenList[idx1]
	token1 := g.tokenList[idx2]

	// Return unsorted pairs roughly 30% of the time to exercise contract-side
	// ordering logic. Otherwise, keep pairs sorted so identity-based checks in
	// stateful fuzz runs remain stable.
	if g.rng.Uint64()%10 >= 3 {
		if token0 > token1 {
			token0, token1 = token1, token0
		}
	}

	return TokenPair{
		Token0: token0,
		Token1: token1,
	}
}

// FeeTierGenerator generates fee tiers
type FeeTierGenerator struct {
	rng         *xs.Xorshift64Star
	validFees   []uint32
	invalidFees []uint32
	validRatio  float64 // ratio of valid fees to generate
}

func NewFeeTierGenerator() Generator {
	return &FeeTierGenerator{
		rng:         nil, // Will be initialized on first use
		validFees:   []uint32{100, 500, 3000, 10000},
		invalidFees: []uint32{0, 50, 250, 1500, 5000, 20000, 100000},
		validRatio:  0.8, // 80% valid fees
	}
}

func (g *FeeTierGenerator) Generate() any {
	initRNG(&g.rng)

	// Decide whether to generate valid or invalid fee
	if float64(g.rng.Uint64()%100) < g.validRatio*100 {
		// Generate valid fee
		idx := int(g.rng.Uint64() % uint64(len(g.validFees)))
		return g.validFees[idx]
	} else {
		// Generate invalid fee
		idx := int(g.rng.Uint64() % uint64(len(g.invalidFees)))
		return g.invalidFees[idx]
	}
}

// SqrtPriceGenerator generates sqrt prices in Q96 format
type SqrtPriceGenerator struct {
	rng *xs.Xorshift64Star
}

func NewSqrtPriceGenerator() Generator {
	return &SqrtPriceGenerator{
		rng: nil, // Will be initialized on first use
	}
}

func (g *SqrtPriceGenerator) Generate() any {
	initRNG(&g.rng)

	// Generate different price scenarios
	scenario := g.rng.Uint64() % 100

	switch {
	case scenario < 20: // 20% edge cases (including invalid)
		return g.generateEdgeCase()
	case scenario < 30: // 10% near boundaries
		return g.generateNearBoundary()
	case scenario < 60: // 30% common ratios
		return g.generateCommonRatio()
	default: // 40% random valid prices
		return g.generateRandomValid()
	}
}

func (g *SqrtPriceGenerator) generateEdgeCase() string {
	edges := []string{
		MIN_SQRT_RATIO,                   // Minimum
		MAX_SQRT_RATIO,                   // Maximum
		"0",                              // Zero (invalid)
		"-1",                             // Negative (invalid)
		"79228162514264337593543950336",  // 1:1 ratio
		"112045541949572279837463876454", // 2:1 ratio
		"158456325028528675187087900672", // 4:1 ratio
		"not-a-number",                   // garbage string
		"0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", // hex-like input
		"79228162514264337593543950336 ",             // trailing space
		"",                                           // empty string
	}

	idx := int(g.rng.Uint64() % uint64(len(edges)))
	return edges[idx]
}

func (g *SqrtPriceGenerator) generateNearBoundary() string {
	minPrice, _ := u256.FromDecimal(MIN_SQRT_RATIO)
	maxPrice, _ := u256.FromDecimal(MAX_SQRT_RATIO)

	if g.rng.Uint64()%2 == 0 {
		// Near minimum
		offset := u256.NewUint(g.rng.Uint64() % 1000000)
		price := new(u256.Uint).Add(minPrice, offset)
		return price.ToString()
	} else {
		// Near maximum
		offset := u256.NewUint(g.rng.Uint64() % 1000000)
		price := new(u256.Uint).Sub(maxPrice, offset)
		return price.ToString()
	}
}

func (g *SqrtPriceGenerator) generateCommonRatio() string {
	// Common price ratios in DeFi
	commonPrices := []string{
		"79228162514264337593543950336",  // 1:1
		"112045541949572279837463876454", // 2:1
		"158456325028528675187087900672", // 4:1
		"39614081257132168796771975168",  // 1:4
		"25054144837504793118641380156",  // 1:10
		"250541448375047931186413801569", // 10:1
		"7922816251426433759354395033",   // 1:100
		"792281625142643375935439503360", // 100:1
	}

	idx := int(g.rng.Uint64() % uint64(len(commonPrices)))
	return commonPrices[idx]
}

func (g *SqrtPriceGenerator) generateRandomValid() string {
	// Generate random price within valid range
	minPrice, _ := u256.FromDecimal(MIN_SQRT_RATIO)
	maxPrice, _ := u256.FromDecimal(MAX_SQRT_RATIO)

	// Generate random value between min and max
	range96 := new(u256.Uint).Sub(maxPrice, minPrice)

	// Generate random factor (0 to 1 scaled to uint256)
	factor := new(u256.Uint).SetUint64(g.rng.Uint64())
	factor = factor.Lsh(factor, 192) // Scale up

	// Calculate: min + (range * factor / 2^256)
	scaled := new(u256.Uint).Mul(range96, factor)
	scaled = scaled.Rsh(scaled, 256)

	result := new(u256.Uint).Add(minPrice, scaled)
	return result.ToString()
}
