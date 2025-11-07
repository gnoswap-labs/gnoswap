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

func (g *uint256Gen) String() string {
	var b strings.Builder
	b.WriteString("Uint256(")
	b.WriteString(g.min.ToString())
	b.WriteString(", ")
	b.WriteString(g.max.ToString())
	b.WriteByte(')')
	return b.String()
}

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
func Uint256() *Generator {
	return Uint256RangeFrom(uint256.NewUint(0), maxUint256Value)
}

// Uint256Max generates uint256 values from 0 to the specified max
// max: maximum value as decimal string
//
// Example:
//
//	Uint256Max("1000000") generates values from 0 to 1000000
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
func Uint256Min(min string) *Generator {
	minVal, err := uint256.FromDecimal(min)
	if err != nil {
		minVal = uint256.NewUint(0)
	}
	return Uint256RangeFrom(minVal, maxUint256Value)
}

// Uint256RangeFrom builds a uint256 generator from already parsed bounds.
func Uint256RangeFrom(minVal *uint256.Uint, maxVal *uint256.Uint) *Generator {
	assertf(minVal != nil && maxVal != nil, "Uint256RangeFrom: nil bounds")
	return newGenerator(newUint256Gen(minVal, maxVal))
}

// Int256 Generators

type int256Gen struct {
	min  *int256.Int
	max  *int256.Int
	span *uint256.Uint
}

func (g *int256Gen) String() string {
	var b strings.Builder
	b.WriteString("Int256(")
	b.WriteString(g.min.ToString())
	b.WriteString(", ")
	b.WriteString(g.max.ToString())
	b.WriteByte(')')
	return b.String()
}

func (g *int256Gen) value(t *T) any {
	if g.span.IsZero() {
		consumeEntropyBit(t.s)
		return g.min.Clone()
	}

	offset := drawUint256UpTo(t.s, g.span)
	result := g.min.Clone()
	result.AddUint256(g.min, offset)
	return result
}

// Int256 generates random int256 values across the full int256 range [-2^255, 2^255-1]
//
// Example:
//
//	Int256() generates values from min int256 to max int256
func Int256() *Generator {
	return Int256RangeFrom(minInt256Value, maxInt256Value)
}

// Int256Max generates int256 values from min int256 to the specified max
// max: maximum value as decimal string
//
// Example:
//
//	Int256Max("1000000") generates values from min int256 to 1000000
func Int256Max(max string) *Generator {
	maxVal, err := int256.FromDecimal(max)
	if err != nil {
		maxVal = int256.NewInt(1000000)
	}
	return Int256RangeFrom(minInt256Value, maxVal)
}

// Int256Range generates int256 values within a specified range [min, max]
// min and max are decimal strings
//
// Example:
//
//	Int256Range("-1000", "999999") generates values between -1000 and 999999
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

// Int256Min generates int256 values from the specified min to max int256
// min: minimum value as decimal string
//
// Example:
//
//	Int256Min("-1000") generates values from -1000 to max int256
func Int256Min(min string) *Generator {
	minVal, err := int256.FromDecimal(min)
	if err != nil {
		minVal = int256.NewInt(0)
	}
	return Int256RangeFrom(minVal, maxInt256Value)
}

// Int256RangeFrom builds an int256 generator from already parsed bounds.
func Int256RangeFrom(minVal *int256.Int, maxVal *int256.Int) *Generator {
	assertf(minVal != nil && maxVal != nil, "Int256RangeFrom: nil bounds")
	return newGenerator(newInt256Gen(minVal, maxVal))
}

func newUint256Gen(minVal *uint256.Uint, maxVal *uint256.Uint) *uint256Gen {
	minClone := minVal.Clone()
	maxClone := maxVal.Clone()
	assertf(minClone.Cmp(maxClone) <= 0, "invalid uint256 range [%s, %s]", minClone.ToString(), maxClone.ToString())
	span := new(uint256.Uint).Sub(maxClone, minClone)
	return &uint256Gen{min: minClone, max: maxClone, span: span}
}

func newInt256Gen(minVal *int256.Int, maxVal *int256.Int) *int256Gen {
	minClone := minVal.Clone()
	maxClone := maxVal.Clone()
	assertf(minClone.Cmp(maxClone) <= 0, "invalid int256 range [%s, %s]", minClone.ToString(), maxClone.ToString())
	diff := new(int256.Int).Sub(maxClone, minClone)
	assertf(diff.Sign() >= 0, "negative span for int256 range")
	return &int256Gen{min: minClone, max: maxClone, span: diff.Abs()}
}

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
		if candidate.Cmp(max) <= 0 {
			return candidate.Clone()
		}
	}

	panic(invalidData("failed to sample uint256 within range"))
}

func consumeEntropyBit(s bitStream) {
	s.drawBits(1)
}
