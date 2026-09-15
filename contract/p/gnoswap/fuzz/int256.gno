package fuzz

import (
	"strings"

	"gno.land/p/gnoswap/int256"
	"gno.land/p/gnoswap/uint256"
)

const (
	maxUint256SampleAttempts = 64
	maxUint256Dec            = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
	maxInt256Dec             = "57896044618658097711785492504343953926634992332820282019728792003956564819967"
	minInt256Dec             = "-57896044618658097711785492504343953926634992332820282019728792003956564819968"
)

var (
	maxUint256Value = uint256.MustFromDecimal(maxUint256Dec)
	maxInt256Value  = int256.MustFromDecimal(maxInt256Dec)
	minInt256Value  = int256.MustFromDecimal(minInt256Dec)
)

// Uint256 Generators

type uint256Gen struct {
	min  *uint256.Uint
	max  *uint256.Uint
	span *uint256.Uint
}

// String returns the uint256 generator's inclusive bounds in decimal form.
//
// Returns:
//   - text: Text containing the generator name and its minimum and maximum uint256 values.
func (g *uint256Gen) String() string {
	var b strings.Builder
	b.WriteString("Uint256(")
	b.WriteString(g.min.ToString())
	b.WriteString(", ")
	b.WriteString(g.max.ToString())
	b.WriteByte(')')
	return b.String()
}

// value samples one uint256 value from the configured inclusive range.
//
// Parameters:
//   - t: Fuzzing context whose bit stream supplies the random offset.
//
// Returns:
//   - value: A new *uint256.Uint in the configured range; a zero-width range returns a clone of min.
func (g *uint256Gen) value(t *T) any {
	if g.span.IsZero() {
		consumeEntropyBit(t.s)
		return g.min.Clone()
	}

	offset := drawUint256UpTo(t.s, g.span)
	return new(uint256.Uint).Add(g.min, offset)
}

// Uint256 generates random uint256 values across the full uint256 range [0, 2^256-1]
//
// Example:
//
//	Uint256() generates values from 0 to max uint256
//
// Returns:
//   - generator: Generator producing uint256 values from zero through the maximum representable uint256, inclusive.
func Uint256() *Generator {
	return Uint256RangeFrom(uint256.NewUint(0), maxUint256Value)
}

// Uint256Max generates uint256 values from 0 to the specified max
// max: maximum value as decimal string
//
// Example:
//
//	Uint256Max("1000000") generates values from 0 to 1000000
//
// Parameters:
//   - max: Decimal uint256 upper bound, inclusive; invalid text falls back to 1,000,000.
//
// Returns:
//   - generator: Generator producing uint256 values from zero through the parsed or fallback max, inclusive.
func Uint256Max(max string) *Generator {
	maxVal, err := uint256.FromDecimal(max)
	if err != nil {
		maxVal = uint256.NewUint(1000000)
	}
	return Uint256RangeFrom(uint256.NewUint(0), maxVal)
}

// Uint256Range generates uint256 values within a specified range [min, max]
// min and max are decimal strings
//
// Example:
//
//	Uint256Range("1000", "999999") generates values between 1000 and 999999
//
// Parameters:
//   - minStr: Decimal uint256 lower bound, inclusive; invalid text falls back to zero.
//   - maxStr: Decimal uint256 upper bound, inclusive; invalid text falls back to 1,000,000.
//
// Returns:
//   - generator: Generator producing uint256 values within the parsed inclusive bounds.
func Uint256Range(minStr, maxStr string) *Generator {
	min, err := uint256.FromDecimal(minStr)
	if err != nil {
		min = uint256.NewUint(0)
	}

	max, err := uint256.FromDecimal(maxStr)
	if err != nil {
		max = uint256.NewUint(1000000)
	}

	return Uint256RangeFrom(min, max)
}

// Uint256Min generates uint256 values from the specified min to uint256 max
// min: minimum value as decimal string
//
// Example:
//
//	Uint256Min("1000") generates values from 1000 to max uint256
//
// Parameters:
//   - min: Decimal uint256 lower bound, inclusive; invalid text falls back to zero.
//
// Returns:
//   - generator: Generator producing uint256 values from the parsed or fallback min through max uint256, inclusive.
func Uint256Min(min string) *Generator {
	minVal, err := uint256.FromDecimal(min)
	if err != nil {
		minVal = uint256.NewUint(0)
	}
	return Uint256RangeFrom(minVal, maxUint256Value)
}

// Uint256RangeFrom builds a uint256 generator from already parsed bounds.
//
// Parameters:
//   - minVal: Parsed uint256 lower bound, inclusive; must be non-nil and no greater than maxVal.
//   - maxVal: Parsed uint256 upper bound, inclusive; must be non-nil and no less than minVal.
//
// Returns:
//   - generator: Generator retaining cloned bounds and producing uint256 values in their inclusive range.
func Uint256RangeFrom(minVal *uint256.Uint, maxVal *uint256.Uint) *Generator {
	assertf(minVal != nil && maxVal != nil, "Uint256RangeFrom: nil bounds")
	return newGenerator(newUint256Gen(minVal, maxVal))
}

// Int256 Generators

type int256Gen struct {
	min  *int256.Int
	max  *int256.Int
	span *int256.Int
}

// String returns the int256 generator's inclusive bounds in decimal form.
//
// Returns:
//   - text: Text containing the generator name and its minimum and maximum signed-int256 values.
func (g *int256Gen) String() string {
	var b strings.Builder
	b.WriteString("Int256(")
	b.WriteString(g.min.ToString())
	b.WriteString(", ")
	b.WriteString(g.max.ToString())
	b.WriteByte(')')
	return b.String()
}

// value samples one signed-int256 value from the configured inclusive range.
//
// Parameters:
//   - t: Fuzzing context whose bit stream supplies the non-negative random offset.
//
// Returns:
//   - value: A new *int256.Int in the configured range; a zero-width range returns a clone of min.
func (g *int256Gen) value(t *T) any {
	if g.span.IsZero() {
		consumeEntropyBit(t.s)
		return g.min.Clone()
	}

	offset := drawInt256UpTo(t.s, g.span)
	result := g.min.Clone()
	result.Add(g.min, offset)
	return result
}

// Int256 generates values using the configured full signed-int256 bounds.
// For a span wider than the signed-positive range, the current implementation
// caps the span at MaxInt256; because offsets are non-negative, Int256() then
// samples MinInt256 through -1 rather than the complete signed range.
//
// Returns:
//   - generator: Generator using the configured signed-int256 bounds; the implementation caps spans wider than MaxInt256 as described above.
func Int256() *Generator {
	return Int256RangeFrom(minInt256Value, maxInt256Value)
}

// Int256Max generates values from min int256 to the specified max.
// max: maximum value as decimal string
//
// If max - MinInt256 exceeds MaxInt256, the current capped-span
// implementation samples the negative half (MinInt256 through -1) instead of
// reaching the supplied positive max.
//
// Parameters:
//   - max: Decimal signed-int256 upper bound, inclusive; invalid text falls back to 1,000,000.
//
// Returns:
//   - generator: Generator spanning min int256 through the parsed or fallback max, subject to the documented capped-span behavior.
func Int256Max(max string) *Generator {
	maxVal, err := int256.FromDecimal(max)
	if err != nil {
		maxVal = int256.NewInt(1000000)
	}
	return Int256RangeFrom(minInt256Value, maxVal)
}

// Int256Range generates int256 values within a specified range [min, max].
// min and max are decimal strings.
//
// If max-min exceeds MaxInt256, the implementation caps the span at
// MaxInt256; generated offsets remain non-negative and may not reach max.
// Int256RangeFrom also panics when the bounds are nil or min > max.
//
// Parameters:
//   - minStr: Decimal signed-int256 lower bound, inclusive; invalid text falls back to zero.
//   - maxStr: Decimal signed-int256 upper bound, inclusive; invalid text falls back to 1,000,000.
//
// Returns:
//   - generator: Generator configured with the parsed inclusive bounds; invalid ordering panics in Int256RangeFrom.
func Int256Range(minStr, maxStr string) *Generator {
	min, err := int256.FromDecimal(minStr)
	if err != nil {
		min = int256.NewInt(0)
	}

	max, err := int256.FromDecimal(maxStr)
	if err != nil {
		max = int256.NewInt(1000000)
	}

	return Int256RangeFrom(min, max)
}

// Int256Min generates int256 values from the specified min to max int256.
// min: minimum value as decimal string
//
// When maxInt256-min exceeds MaxInt256, the capped-span implementation may
// not reach maxInt256; it samples min plus a non-negative offset up to
// MaxInt256.
//
// Parameters:
//   - min: Decimal signed-int256 lower bound, inclusive; invalid text falls back to zero.
//
// Returns:
//   - generator: Generator spanning the parsed or fallback min through max int256, subject to the documented capped-span behavior.
func Int256Min(min string) *Generator {
	minVal, err := int256.FromDecimal(min)
	if err != nil {
		minVal = int256.NewInt(0)
	}
	return Int256RangeFrom(minVal, maxInt256Value)
}

// Int256RangeFrom builds an int256 generator from already parsed bounds.
//
// Parameters:
//   - minVal: Parsed signed-int256 lower bound, inclusive; must be non-nil and no greater than maxVal.
//   - maxVal: Parsed signed-int256 upper bound, inclusive; must be non-nil and no less than minVal.
//
// Returns:
//   - generator: Generator retaining cloned bounds and producing signed-int256 values in their inclusive range.
func Int256RangeFrom(minVal *int256.Int, maxVal *int256.Int) *Generator {
	assertf(minVal != nil && maxVal != nil, "Int256RangeFrom: nil bounds")
	return newGenerator(newInt256Gen(minVal, maxVal))
}

// newUint256Gen clones and validates uint256 bounds for a generator implementation.
//
// Parameters:
//   - minVal: Source uint256 lower bound, inclusive; must be non-nil.
//   - maxVal: Source uint256 upper bound, inclusive; must be non-nil and no less than minVal.
//
// Returns:
//   - generator: Internal generator with cloned bounds and their uint256 span; invalid ordering panics.
func newUint256Gen(minVal *uint256.Uint, maxVal *uint256.Uint) *uint256Gen {
	minClone := minVal.Clone()
	maxClone := maxVal.Clone()
	assertf(minClone.Cmp(maxClone) <= 0, "invalid uint256 range [%s, %s]", minClone.ToString(), maxClone.ToString())
	span := new(uint256.Uint).Sub(maxClone, minClone)
	return &uint256Gen{min: minClone, max: maxClone, span: span}
}

// newInt256Gen clones and validates signed-int256 bounds and computes a usable span.
//
// Parameters:
//   - minVal: Source signed-int256 lower bound, inclusive; must be non-nil.
//   - maxVal: Source signed-int256 upper bound, inclusive; must be non-nil and no less than minVal.
//
// Returns:
//   - generator: Internal generator with cloned bounds and a non-negative span, capped at MaxInt256 on overflow.
func newInt256Gen(minVal *int256.Int, maxVal *int256.Int) *int256Gen {
	minClone := minVal.Clone()
	maxClone := maxVal.Clone()
	assertf(minClone.Cmp(maxClone) <= 0, "invalid int256 range [%s, %s]", minClone.ToString(), maxClone.ToString())

	// Handle overflow when computing span for full int256 range
	// When max - min would overflow (e.g., MaxInt256 - MinInt256), use MaxInt256 as span
	diff, overflow := new(int256.Int).SubOverflow(maxClone, minClone)
	if overflow || diff.Sign() < 0 {
		// Span would exceed int256 range, use MaxInt256 as approximation
		diff = int256.MaxInt256()
	}
	return &int256Gen{min: minClone, max: maxClone, span: diff}
}

// drawUint256UpTo samples a uint256 offset uniformly by rejection from zero through max, inclusive.
//
// Parameters:
//   - s: Bit stream supplying candidate bytes.
//   - max: Inclusive non-negative uint256 limit; zero returns a zero value without drawing.
//
// Returns:
//   - value: A new uint256 value in [0, max]; panics with invalidData after 64 rejected candidates.
func drawUint256UpTo(s bitStream, max *uint256.Uint) *uint256.Uint {
	if max.IsZero() {
		return uint256.NewUint(0)
	}

	bitlen := max.BitLen()
	numBytes := (bitlen + 7) / 8
	buf := make([]byte, numBytes)
	candidate := new(uint256.Uint)

	for attempt := 0; attempt < maxUint256SampleAttempts; attempt++ {
		for i := 0; i < numBytes; i++ {
			buf[i] = byte(s.drawBits(8))
		}

		extraBits := numBytes*8 - bitlen
		if extraBits > 0 {
			buf[0] &= byte(0xFF >> uint(extraBits))
		}

		candidate.SetBytes(buf)
		if candidate.Lte(max) {
			return candidate.Clone()
		}
	}

	panic(invalidData("failed to sample uint256 within range"))
}

// drawInt256UpTo samples a non-negative signed-int256 offset up to max, inclusive.
//
// Parameters:
//   - s: Bit stream supplying candidate bytes.
//   - max: Inclusive non-negative signed-int256 limit used for rejection sampling.
//
// Returns:
//   - value: A signed-int256 offset in [0, max], or zero if 64 attempts fail.
func drawInt256UpTo(s bitStream, max *int256.Int) *int256.Int {
	if max.IsZero() {
		return int256.NewInt(0)
	}

	// Get absolute value for bit length calculation
	absMax := max.Abs()
	bitlen := absMax.BitLen()
	numBytes := (bitlen + 7) / 8
	buf := make([]byte, numBytes)
	candidate := new(uint256.Uint)

	for attempt := 0; attempt < maxUint256SampleAttempts; attempt++ {
		for i := 0; i < numBytes; i++ {
			buf[i] = byte(s.drawBits(8))
		}

		extraBits := numBytes*8 - bitlen
		if extraBits > 0 {
			buf[0] &= byte(0xFF >> uint(extraBits))
		}

		candidate.SetBytes(buf)

		// Check if candidate fits within max (as unsigned)
		if candidate.Lte(absMax) {
			// Safe to convert - value is within range
			return int256.FromUint256(candidate)
		}
	}

	// Fallback: return 0 if we couldn't sample in range
	return int256.NewInt(0)
}

// consumeEntropyBit consumes one bit without using its value, preserving entropy alignment.
//
// Parameters:
//   - s: Bit stream from which the alignment bit is drawn.
func consumeEntropyBit(s bitStream) {
	s.drawBits(1)
}
