package fuzzing

import (
	"std"

	"gno.land/p/gnoswap/uint256"
)

// Gnoswap domain-specific generators

// Constants for boundary values
const (
	MAX_UINT128 = "340282366920938463463374607431768211455" // 2^128 - 1
	MAX_INT128  = "170141183460469231731687303715884105727"  // 2^127 - 1
	MIN_INT128  = "-170141183460469231731687303715884105728" // -2^127
	MAX_UINT64  = 18446744073709551615                      // 2^64 - 1

	MIN_TICK = -887272
	MAX_TICK = 887272
)

// Big Number Generators

type uint256Gen struct {
	maxBits uint
}

func (g *uint256Gen) value(t *T) any {
	// 10% chance for special boundary values
	if flipBiasedCoin(t.s, 0.1) {
		choice := int(genIntRange(t.s, 0, 5, false))
		switch choice {
		case 0:
			return uint256.Zero()
		case 1:
			return uint256.One()
		case 2:
			return uint256.MustFromDecimal(MAX_UINT128)
		case 3:
			return uint256.MustFromDecimal(MAX_INT128)
		case 4:
			return uint256.NewUint(MAX_UINT64)
		case 5:
			// MAX_UINT256 approximation
			max := uint256.MustFromDecimal(MAX_UINT128)
			max = new(uint256.Uint).Lsh(max, 128)
			max = new(uint256.Uint).Sub(max, uint256.One())
			return max
		}
	}

	// Generate random value within maxBits
	if g.maxBits == 0 || g.maxBits > 256 {
		g.maxBits = 256
	}

	// Generate value bit by bit
	result := uint256.Zero()
	numBits := int(genIntRange(t.s, 1, int64(g.maxBits), true))

	for i := 0; i < numBits; i++ {
		if flipBiasedCoin(t.s, 0.5) {
			bit := uint256.One()
			bit = new(uint256.Uint).Lsh(bit, uint(i))
			result = new(uint256.Uint).Or(result, bit)
		}
	}

	return result
}

// Uint256 generates uint256 values with specified maximum bits.
func Uint256(maxBits uint) *Generator {
	return newGenerator(&uint256Gen{maxBits: maxBits})
}

// Uint256WithBoundaries generates uint256 values with higher probability of boundary cases.
func Uint256WithBoundaries(maxBits uint) *Generator {
	return newGenerator(&uint256Gen{maxBits: maxBits})
}

type int256Gen struct {
	allowZero     bool
	allowNegative bool
	maxBits       uint
}

func (g *int256Gen) value(t *T) any {
	// 10% chance for special boundary values
	if flipBiasedCoin(t.s, 0.1) {
		choice := int(genIntRange(t.s, 0, 6, false))
		switch choice {
		case 0:
			if g.allowZero {
				return uint256.Zero()
			}
		case 1:
			return uint256.One()
		case 2:
			if g.allowNegative {
				// -1
				return uint256.MustFromDecimal(MIN_INT128)
			}
		case 3:
			return uint256.MustFromDecimal(MAX_INT128)
		case 4:
			if g.allowNegative {
				return uint256.MustFromDecimal(MIN_INT128)
			}
		case 5:
			return uint256.NewUint(MAX_UINT64)
		case 6:
			if g.allowNegative {
				// Random negative
				val := uint256.NewUint(uint64(genIntRange(t.s, 1, MAX_UINT64, true)))
				return new(uint256.Uint).Neg(val)
			}
		}
	}

	// Generate random value
	if g.maxBits == 0 || g.maxBits > 255 {
		g.maxBits = 255 // int256 uses 255 bits + sign
	}

	result := uint256.Zero()
	numBits := int(genIntRange(t.s, 1, int64(g.maxBits), true))

	for i := 0; i < numBits; i++ {
		if flipBiasedCoin(t.s, 0.5) {
			bit := uint256.One()
			bit = new(uint256.Uint).Lsh(bit, uint(i))
			result = new(uint256.Uint).Or(result, bit)
		}
	}

	// Apply sign
	if g.allowNegative && flipBiasedCoin(t.s, 0.5) {
		result = new(uint256.Uint).Neg(result)
	}

	// Handle zero
	if !g.allowZero && result.IsZero() {
		result = uint256.One()
	}

	return result
}

// Int256 generates int256 values with specified constraints.
func Int256(allowZero, allowNegative bool, maxBits uint) *Generator {
	return newGenerator(&int256Gen{
		allowZero:     allowZero,
		allowNegative: allowNegative,
		maxBits:       maxBits,
	})
}

// Int256WithBoundaries generates int256 values with higher probability of boundary cases.
func Int256WithBoundaries(allowZero, allowNegative bool, maxBits uint) *Generator {
	return newGenerator(&int256Gen{
		allowZero:     allowZero,
		allowNegative: allowNegative,
		maxBits:       maxBits,
	})
}

// Pool & Position Generators

type tickRangeGen struct {
	tickSpacing int32
}

func (g *tickRangeGen) value(t *T) any {
	// 15% chance for boundary values
	if flipBiasedCoin(t.s, 0.15) {
		choice := int(genIntRange(t.s, 0, 2, false))
		switch choice {
		case 0:
			return int32(MIN_TICK)
		case 1:
			return int32(MAX_TICK)
		case 2:
			return int32(0)
		}
	}

	// Generate random tick aligned to spacing
	tick := int32(genIntRange(t.s, MIN_TICK, MAX_TICK, true))

	// Align to spacing
	if g.tickSpacing > 0 {
		tick = (tick / g.tickSpacing) * g.tickSpacing
	}

	// Ensure within bounds
	if tick < MIN_TICK {
		tick = MIN_TICK
	}
	if tick > MAX_TICK {
		tick = MAX_TICK
	}

	return tick
}

// TickRange generates valid tick values respecting tick spacing.
func TickRange(tickSpacing int32) *Generator {
	return newGenerator(&tickRangeGen{tickSpacing: tickSpacing})
}

// TickRangeWithBoundaries generates tick values with higher probability of boundaries.
func TickRangeWithBoundaries(tickSpacing int32) *Generator {
	return newGenerator(&tickRangeGen{tickSpacing: tickSpacing})
}

type feeAmountGen struct{}

func (g *feeAmountGen) value(t *T) any {
	// Valid fee tiers in basis points
	validFees := []uint32{100, 500, 3000, 10000}
	idx := int(genIntRange(t.s, 0, int64(len(validFees)-1), false))
	return validFees[idx]
}

// FeeAmount generates valid fee tier values (100, 500, 3000, 10000).
func FeeAmount() *Generator {
	return newGenerator(&feeAmountGen{})
}

type tickSpacingGen struct {
	feeAmount uint32
}

func (g *tickSpacingGen) value(t *T) any {
	// Map fee amounts to tick spacing
	switch g.feeAmount {
	case 100:
		return int32(1)
	case 500:
		return int32(10)
	case 3000:
		return int32(60)
	case 10000:
		return int32(200)
	default:
		// Default to 60 for unknown fee amounts
		return int32(60)
	}
}

// TickSpacing generates valid tick spacing for the given fee amount.
func TickSpacing(feeAmount uint32) *Generator {
	return newGenerator(&tickSpacingGen{feeAmount: feeAmount})
}

type sqrtPriceX96Gen struct{}

func (g *sqrtPriceX96Gen) value(t *T) any {
	// MIN_SQRT_RATIO = 4295128739
	// MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342
	minSqrt := uint256.NewUint(4295128739)
	maxSqrt := uint256.MustFromDecimal("1461446703485210103287273052203988822378723970342")

	// 10% chance for boundary values
	if flipBiasedCoin(t.s, 0.1) {
		if flipBiasedCoin(t.s, 0.5) {
			return minSqrt
		}
		return maxSqrt
	}

	// Generate random value in range
	// For simplicity, generate in smaller range and scale
	randomBits := uint(genIntRange(t.s, 32, 160, true))
	result := Uint256(randomBits).value(t).(*uint256.Uint)

	// Ensure it's within valid range
	if result.Lt(minSqrt) {
		result = minSqrt
	}
	if result.Gt(maxSqrt) {
		result = maxSqrt
	}

	return result
}

// SqrtPriceX96 generates valid sqrt price values in Q64.96 format.
func SqrtPriceX96() *Generator {
	return newGenerator(&sqrtPriceX96Gen{})
}

// Token & Address Generators

type gnoAddressGen struct{}

func (g *gnoAddressGen) value(t *T) any {
	// Generate valid gno address (g1 + 38 alphanumeric chars)
	chars := "0123456789abcdefghjkmnpqrstuvwxyz" // base32 without i, l, o
	addr := "g1"

	for i := 0; i < 38; i++ {
		idx := int(genIntRange(t.s, 0, int64(len(chars)-1), false))
		addr += string(chars[idx])
	}

	return std.Address(addr)
}

// GnoAddress generates valid gno address format.
func GnoAddress() *Generator {
	return newGenerator(&gnoAddressGen{})
}

type tokenPathGen struct{}

func (g *tokenPathGen) value(t *T) any {
	// Common token path patterns
	patterns := []string{
		"gno.land/r/demo/gns",
		"gno.land/r/demo/wugnot",
		"gno.land/r/demo/usdc",
		"gno.land/r/demo/foo",
		"gno.land/r/demo/bar",
		"gno.land/r/demo/baz",
	}

	idx := int(genIntRange(t.s, 0, int64(len(patterns)-1), false))
	return patterns[idx]
}

// TokenPath generates token realm paths.
func TokenPath() *Generator {
	return newGenerator(&tokenPathGen{})
}

type tokenPairGen struct{}

func (g *tokenPairGen) value(t *T) any {
	// Generate two distinct token paths
	allPaths := []string{
		"gno.land/r/demo/gns",
		"gno.land/r/demo/wugnot",
		"gno.land/r/demo/usdc",
		"gno.land/r/demo/foo",
		"gno.land/r/demo/bar",
		"gno.land/r/demo/baz",
	}

	idx1 := int(genIntRange(t.s, 0, int64(len(allPaths)-1), false))
	idx2 := int(genIntRange(t.s, 0, int64(len(allPaths)-1), false))

	// Ensure distinct
	for idx2 == idx1 {
		idx2 = int(genIntRange(t.s, 0, int64(len(allPaths)-1), false))
	}

	return []string{allPaths[idx1], allPaths[idx2]}
}

// TokenPair generates a pair of distinct token paths.
func TokenPair() *Generator {
	return newGenerator(&tokenPairGen{})
}

// Time & Ratio Generators

type timestampGen struct {
	min int64
	max int64
}

func (g *timestampGen) value(t *T) any {
	min := g.min
	max := g.max

	if min == 0 {
		min = 1600000000 // ~2020-09-13
	}
	if max == 0 {
		max = 2000000000 // ~2033-05-18
	}

	// 10% chance for boundary values
	if flipBiasedCoin(t.s, 0.1) {
		if flipBiasedCoin(t.s, 0.5) {
			return min
		}
		return max
	}

	return genIntRange(t.s, min, max, true)
}

// Timestamp generates Unix timestamp values.
func Timestamp(min, max int64) *Generator {
	return newGenerator(&timestampGen{min: min, max: max})
}

type percentageGen struct{}

func (g *percentageGen) value(t *T) any {
	// Generate percentage as uint64 (0-100 with decimals as basis points)
	// 10000 = 100%, 5000 = 50%, etc.

	// 10% chance for common values
	if flipBiasedCoin(t.s, 0.1) {
		commonValues := []uint64{0, 2500, 5000, 7500, 10000} // 0%, 25%, 50%, 75%, 100%
		idx := int(genIntRange(t.s, 0, int64(len(commonValues)-1), false))
		return commonValues[idx]
	}

	return uint64(genIntRange(t.s, 0, 10000, true))
}

// Percentage generates percentage values in basis points (0-10000).
func Percentage() *Generator {
	return newGenerator(&percentageGen{})
}

type basisPointsGen struct {
	max uint64
}

func (g *basisPointsGen) value(t *T) any {
	max := g.max
	if max == 0 {
		max = 10000 // 100%
	}

	// 10% chance for 0
	if flipBiasedCoin(t.s, 0.1) {
		return uint64(0)
	}

	return uint64(genIntRange(t.s, 0, int64(max), true))
}

// BasisPoints generates basis point values (1bp = 0.01%).
func BasisPoints(max uint64) *Generator {
	return newGenerator(&basisPointsGen{max: max})
}

// Amount Generators

type tokenAmountGen struct {
	decimals uint8
	maxBits  uint
}

func (g *tokenAmountGen) value(t *T) any {
	// Generate amount considering token decimals
	if g.decimals == 0 {
		g.decimals = 18 // Default to 18 decimals
	}

	if g.maxBits == 0 {
		g.maxBits = 128
	}

	// 10% chance for 0
	if flipBiasedCoin(t.s, 0.1) {
		return uint256.Zero()
	}

	// 10% chance for 1 unit (10^decimals)
	if flipBiasedCoin(t.s, 0.1) {
		unit := uint256.NewUint(1)
		for i := uint8(0); i < g.decimals; i++ {
			unit = new(uint256.Uint).Mul(unit, uint256.NewUint(10))
		}
		return unit
	}

	// Generate random amount
	return Uint256(g.maxBits).value(t)
}

// TokenAmount generates token amounts considering decimals.
func TokenAmount(decimals uint8, maxBits uint) *Generator {
	return newGenerator(&tokenAmountGen{decimals: decimals, maxBits: maxBits})
}

type liquidityAmountGen struct{}

func (g *liquidityAmountGen) value(t *T) any {
	// Liquidity is typically a uint128
	// 10% chance for small values (0, 1)
	if flipBiasedCoin(t.s, 0.1) {
		if flipBiasedCoin(t.s, 0.5) {
			return uint256.Zero()
		}
		return uint256.One()
	}

	return Uint256(128).value(t)
}

// LiquidityAmount generates liquidity values (typically uint128).
func LiquidityAmount() *Generator {
	return newGenerator(&liquidityAmountGen{})
}

type rewardAmountGen struct {
	maxBits uint
}

func (g *rewardAmountGen) value(t *T) any {
	if g.maxBits == 0 {
		g.maxBits = 128
	}

	// 15% chance for 0 (no rewards)
	if flipBiasedCoin(t.s, 0.15) {
		return uint256.Zero()
	}

	return Uint256(g.maxBits).value(t)
}

// RewardAmount generates reward values.
func RewardAmount(maxBits uint) *Generator {
	return newGenerator(&rewardAmountGen{maxBits: maxBits})
}
