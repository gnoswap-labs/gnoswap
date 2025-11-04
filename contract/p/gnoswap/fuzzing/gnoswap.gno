package fuzzing

import (
	"gno.land/p/gnoswap/int256"
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
		choice, _, _ := genIntRange(t.s, 0, 5, false)
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
	maxBits := g.maxBits
	if maxBits == 0 || maxBits > 256 {
		maxBits = 256
	}

	// Generate value bit by bit
	result := uint256.Zero()
	numBits64, _, _ := genIntRange(t.s, 1, int64(maxBits), true)
	numBits := int(numBits64)

	for i := 0; i < numBits; i++ {
		if flipBiasedCoin(t.s, 0.5) {
			bit := uint256.One()
			bit = new(uint256.Uint).Lsh(bit, uint(i))
			result = new(uint256.Uint).Or(result, bit)
		}
	}

	return result
}

func (g *uint256Gen) String() string {
	return "Uint256"
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
		choice, _, _ := genIntRange(t.s, 0, 4, false)
		switch choice {
		case 0:
			return int256.One()
		case 1:
			if g.allowNegative {
				return int256.NewInt(-1)
			}
			return int256.One()
		case 2:
			return int256.MustFromDecimal(MAX_INT128)
		case 3:
			if g.allowNegative {
				return int256.MustFromDecimal(MIN_INT128)
			}
			return int256.MustFromDecimal(MAX_INT128)
		case 4:
			return int256.NewInt(int64(MAX_UINT64 >> 1))
		}
	}

	// Generate random value
	maxBits := g.maxBits
	if maxBits == 0 || maxBits > 255 {
		maxBits = 255 // int256 uses 255 bits + sign
	}

	uResult := uint256.Zero()
	numBits64, _, _ := genIntRange(t.s, 1, int64(maxBits), true)
	numBits := int(numBits64)

	for i := 0; i < numBits; i++ {
		if flipBiasedCoin(t.s, 0.5) {
			bit := uint256.One()
			bit = new(uint256.Uint).Lsh(bit, uint(i))
			uResult = new(uint256.Uint).Or(uResult, bit)
		}
	}

	result := int256.FromUint256(uResult)

	// Apply sign
	if g.allowNegative && flipBiasedCoin(t.s, 0.5) {
		result = new(int256.Int).Neg(result)
	}

	// Handle zero
	if !g.allowZero && result.IsZero() {
		result = int256.One()
	}

	return result
}

func (g *int256Gen) String() string {
	return "Int256"
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
		choice, _, _ := genIntRange(t.s, 0, 2, false)
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
	tick64, _, _ := genIntRange(t.s, MIN_TICK, MAX_TICK, true)
	tick := int32(tick64)

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

func (g *tickRangeGen) String() string {
	return "TickRange"
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
	idx, _, _ := genIntRange(t.s, 0, int64(len(validFees)-1), false)
	return validFees[idx]
}

func (g *feeAmountGen) String() string {
	return "FeeAmount"
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

func (g *tickSpacingGen) String() string {
	return "TickSpacing"
}

// TickSpacing generates valid tick spacing for the given fee amount.
func TickSpacing(feeAmount uint32) *Generator {
	return newGenerator(&tickSpacingGen{feeAmount: feeAmount})
}

// Token & Address Generators

type gnoAddressGen struct{}

func (g *gnoAddressGen) value(t *T) any {
	// Generate valid gno address (g1 + 38 alphanumeric chars)
	chars := "0123456789abcdefghjkmnpqrstuvwxyz" // base32 without i, l, o
	addr := "g1"

	for i := 0; i < 38; i++ {
		idx, _, _ := genIntRange(t.s, 0, int64(len(chars)-1), false)
		addr += string(chars[idx])
	}

	return addr
}

func (g *gnoAddressGen) String() string {
	return "GnoAddress"
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

	idx, _, _ := genIntRange(t.s, 0, int64(len(patterns)-1), false)
	return patterns[idx]
}

func (g *tokenPathGen) String() string {
	return "TokenPath"
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

	idx1, _, _ := genIntRange(t.s, 0, int64(len(allPaths)-1), false)
	idx2, _, _ := genIntRange(t.s, 0, int64(len(allPaths)-1), false)

	// Ensure distinct
	for idx2 == idx1 {
		idx2, _, _ = genIntRange(t.s, 0, int64(len(allPaths)-1), false)
	}

	return []string{allPaths[idx1], allPaths[idx2]}
}

func (g *tokenPairGen) String() string {
	return "TokenPair"
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

	result, _, _ := genIntRange(t.s, min, max, true)
	return result
}

func (g *timestampGen) String() string {
	return "Timestamp"
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
		idx, _, _ := genIntRange(t.s, 0, int64(len(commonValues)-1), false)
		return commonValues[idx]
	}

	result, _, _ := genIntRange(t.s, 0, 10000, true)
	return uint64(result)
}

func (g *percentageGen) String() string {
	return "Percentage"
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

	result, _, _ := genIntRange(t.s, 0, int64(max), true)
	return uint64(result)
}

func (g *basisPointsGen) String() string {
	return "BasisPoints"
}

// BasisPoints generates basis point values (1bp = 0.01%).
func BasisPoints(max uint64) *Generator {
	return newGenerator(&basisPointsGen{max: max})
}

// T convenience methods for Gnoswap generators

// Uint256 generates a uint256 value with specified maximum bits.
func (t *T) Uint256(maxBits uint) *uint256.Uint {
	return Uint256(maxBits).value(t).(*uint256.Uint)
}

// Uint256WithBoundaries generates a uint256 with higher probability of boundary cases.
func (t *T) Uint256WithBoundaries(maxBits uint) *uint256.Uint {
	return Uint256WithBoundaries(maxBits).value(t).(*uint256.Uint)
}

// Int256 generates an int256 value with specified constraints.
func (t *T) Int256(allowZero, allowNegative bool, maxBits uint) *int256.Int {
	return Int256(allowZero, allowNegative, maxBits).value(t).(*int256.Int)
}

// Int256WithBoundaries generates an int256 with higher probability of boundary cases.
func (t *T) Int256WithBoundaries(allowZero, allowNegative bool, maxBits uint) *int256.Int {
	return Int256WithBoundaries(allowZero, allowNegative, maxBits).value(t).(*int256.Int)
}

// TickRange generates valid tick values respecting tick spacing.
func (t *T) TickRange(tickSpacing int32) int32 {
	return TickRange(tickSpacing).value(t).(int32)
}

// TickRangeWithBoundaries generates tick values with higher probability of boundaries.
func (t *T) TickRangeWithBoundaries(tickSpacing int32) int32 {
	return TickRangeWithBoundaries(tickSpacing).value(t).(int32)
}

// FeeAmount generates valid fee tier values (100, 500, 3000, 10000).
func (t *T) FeeAmount() uint32 {
	return FeeAmount().value(t).(uint32)
}

// TickSpacing generates valid tick spacing for the given fee amount.
func (t *T) TickSpacing(feeAmount uint32) int32 {
	return TickSpacing(feeAmount).value(t).(int32)
}

// GnoAddress generates valid gno address format.
func (t *T) GnoAddress() string {
	return GnoAddress().value(t).(string)
}

// TokenPath generates token realm paths.
func (t *T) TokenPath() string {
	return TokenPath().value(t).(string)
}

// TokenPair generates a pair of distinct token paths.
func (t *T) TokenPair() []string {
	return TokenPair().value(t).([]string)
}

// Timestamp generates Unix timestamp values.
func (t *T) Timestamp(min, max int64) int64 {
	return Timestamp(min, max).value(t).(int64)
}

// Percentage generates percentage values in basis points (0-10000).
func (t *T) Percentage() uint64 {
	return Percentage().value(t).(uint64)
}

// BasisPoints generates basis point values (1bp = 0.01%).
func (t *T) BasisPoints(max uint64) uint64 {
	return BasisPoints(max).value(t).(uint64)
}
