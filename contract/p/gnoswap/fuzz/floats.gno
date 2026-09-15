// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzz

import (
	"math"
	"math/bits"

	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	float32ExpBits    = 8
	float32SignifBits = 23

	float64ExpBits    = 11
	float64SignifBits = 52

	floatExpLabel    = "floatexp"
	floatSignifLabel = "floatsignif"
)

// floatGen generates floating-point values
type floatGen struct {
	kind   string
	min    float64
	max    float64
	minVal float64
	maxVal float64
	is32   bool
}

// String describes the floating-point generator's kind and configured bounds.
//
// Returns:
//   - string: A constructor-style description such as Float32(), Float64Min(x), or a bounded range.
func (g *floatGen) String() string {
	if g.min != g.minVal && g.max != g.maxVal {
		return ufmt.Sprintf("%sRange(%g, %g)", g.kind, g.min, g.max)
	} else if g.min != g.minVal {
		return ufmt.Sprintf("%sMin(%g)", g.kind, g.min)
	} else if g.max != g.maxVal {
		return ufmt.Sprintf("%sMax(%g)", g.kind, g.max)
	}
	return ufmt.Sprintf("%s()", g.kind)
}

// value generates a floating-point value with the configured precision and bounds.
//
// Parameters:
//   - t: Test state providing the bit stream used to choose the sign, exponent, and significand.
//
// Returns:
//   - any: A float32 when this generator is configured for 32-bit values, otherwise a float64, within the configured range.
func (g *floatGen) value(t *T) any {
	if g.is32 {
		sign, e, si, sf := genFloatRange(t.s, g.min, g.max, float32SignifBits)
		return float32FromParts(sign, e, si, sf)
	}
	sign, e, si, sf := genFloatRange(t.s, g.min, g.max, float64SignifBits)
	return float64FromParts(sign, e, si, sf)
}

// Float32 creates a generator for float32 values
//
// Returns:
//   - *Generator: A generator spanning the full finite float32 range from -math.MaxFloat32 through math.MaxFloat32.
func Float32() *Generator {
	return Float32Range(-math.MaxFloat32, math.MaxFloat32)
}

// Float32Min creates a generator for float32 values >= min
//
// Parameters:
//   - min: Inclusive lower bound for generated float32 values.
//
// Returns:
//   - *Generator: A float32 generator whose values are at least min and at most math.MaxFloat32.
func Float32Min(min float32) *Generator {
	return Float32Range(min, math.MaxFloat32)
}

// Float32Max creates a generator for float32 values <= max
//
// Parameters:
//   - max: Inclusive upper bound for generated float32 values.
//
// Returns:
//   - *Generator: A float32 generator whose values are at least -math.MaxFloat32 and at most max.
func Float32Max(max float32) *Generator {
	return Float32Range(-math.MaxFloat32, max)
}

// Float32Range creates a generator for float32 values in [min, max]
//
// Parameters:
//   - min: Inclusive lower bound for generated float32 values; NaN is rejected.
//   - max: Inclusive upper bound for generated float32 values; NaN or a value below min is rejected.
//
// Returns:
//   - *Generator: A float32 generator producing values in the inclusive [min, max] range.
func Float32Range(min float32, max float32) *Generator {
	assertf(min == min, "min should not be a NaN")
	assertf(max == max, "max should not be a NaN")
	assertf(min <= max, "invalid range [%v, %v]", min, max)

	return newGenerator(&floatGen{
		kind:   "Float32",
		min:    float64(min),
		max:    float64(max),
		minVal: -math.MaxFloat32,
		maxVal: math.MaxFloat32,
		is32:   true,
	})
}

// Float64 creates a generator for float64 values
//
// Returns:
//   - *Generator: A generator spanning the full finite float64 range from -math.MaxFloat64 through math.MaxFloat64.
func Float64() *Generator {
	return Float64Range(-math.MaxFloat64, math.MaxFloat64)
}

// Float64Min creates a generator for float64 values >= min
//
// Parameters:
//   - min: Inclusive lower bound for generated float64 values.
//
// Returns:
//   - *Generator: A float64 generator whose values are at least min and at most math.MaxFloat64.
func Float64Min(min float64) *Generator {
	return Float64Range(min, math.MaxFloat64)
}

// Float64Max creates a generator for float64 values <= max
//
// Parameters:
//   - max: Inclusive upper bound for generated float64 values.
//
// Returns:
//   - *Generator: A float64 generator whose values are at least -math.MaxFloat64 and at most max.
func Float64Max(max float64) *Generator {
	return Float64Range(-math.MaxFloat64, max)
}

// Float64Range creates a generator for float64 values in [min, max]
//
// Parameters:
//   - min: Inclusive lower bound for generated float64 values; NaN is rejected.
//   - max: Inclusive upper bound for generated float64 values; NaN or a value below min is rejected.
//
// Returns:
//   - *Generator: A float64 generator producing values in the inclusive [min, max] range.
func Float64Range(min float64, max float64) *Generator {
	assertf(min == min, "min should not be a NaN")
	assertf(max == max, "max should not be a NaN")
	assertf(min <= max, "invalid range [%v, %v]", min, max)

	return newGenerator(&floatGen{
		kind:   "Float64",
		min:    min,
		max:    max,
		minVal: -math.MaxFloat64,
		maxVal: math.MaxFloat64,
		is32:   false,
	})
}

// ufloatFracBits computes how many low significand bits are fractional at exponent e.
//
// Parameters:
//   - e: Unbiased exponent of the nonnegative floating-point magnitude.
//   - signifBits: Number of significand fraction bits in the target format.
//
// Returns:
//   - uint: Number of significand bits retained as the fractional portion; it is signifBits for nonpositive e and zero once e reaches signifBits.
func ufloatFracBits(e int32, signifBits uint) uint {
	if e <= 0 {
		return signifBits
	} else if uint(e) < signifBits {
		return signifBits - uint(e)
	}
	return 0
}

// ufloat32Parts decomposes a nonnegative float32 magnitude into its exponent and significand components.
//
// Parameters:
//   - f: Float32 magnitude to decompose; the sign bit is discarded.
//
// Returns:
//   - e: Unbiased exponent component.
//   - si: Integer portion of the significand after shifting away fractional bits.
//   - sf: Low fractional significand bits, masked to the precision required by e.
func ufloat32Parts(f float32) (int32, uint64, uint64) {
	u := math.Float32bits(f) & math.MaxInt32

	e := int32(u>>float32SignifBits) - int32(bitmask64(float32ExpBits-1))
	s := uint64(u) & bitmask64(float32SignifBits)
	n := ufloatFracBits(e, float32SignifBits)

	return e, s >> n, s & bitmask64(n)
}

// ufloat64Parts decomposes a nonnegative float64 magnitude into its exponent and significand components.
//
// Parameters:
//   - f: Float64 magnitude to decompose; the sign bit is discarded.
//
// Returns:
//   - e: Unbiased exponent component.
//   - si: Integer portion of the significand after shifting away fractional bits.
//   - sf: Low fractional significand bits, masked to the precision required by e.
func ufloat64Parts(f float64) (int32, uint64, uint64) {
	u := math.Float64bits(f) & math.MaxInt64

	e := int32(u>>float64SignifBits) - int32(bitmask64(float64ExpBits-1))
	s := u & bitmask64(float64SignifBits)
	n := ufloatFracBits(e, float64SignifBits)

	return e, s >> n, s & bitmask64(n)
}

// ufloat32FromParts reconstructs a nonnegative float32 magnitude from its components.
//
// Parameters:
//   - e: Unbiased exponent component.
//   - si: Integer significand component.
//   - sf: Fractional significand bits for the exponent's remaining precision.
//
// Returns:
//   - float32: The reconstructed nonnegative float32 magnitude.
func ufloat32FromParts(e int32, si uint64, sf uint64) float32 {
	e_ := (uint32(e) + uint32(bitmask64(float32ExpBits-1))) << float32SignifBits
	s_ := (uint32(si) << ufloatFracBits(e, float32SignifBits)) | uint32(sf)

	return math.Float32frombits(e_ | s_)
}

// ufloat64FromParts reconstructs a nonnegative float64 magnitude from its components.
//
// Parameters:
//   - e: Unbiased exponent component.
//   - si: Integer significand component.
//   - sf: Fractional significand bits for the exponent's remaining precision.
//
// Returns:
//   - float64: The reconstructed nonnegative float64 magnitude.
func ufloat64FromParts(e int32, si uint64, sf uint64) float64 {
	e_ := (uint64(e) + bitmask64(float64ExpBits-1)) << float64SignifBits
	s_ := (si << ufloatFracBits(e, float64SignifBits)) | sf

	return math.Float64frombits(e_ | s_)
}

// float32FromParts reconstructs a float32 value and applies its sign.
//
// Parameters:
//   - sign: True to negate the reconstructed magnitude; false to leave it nonnegative.
//   - e: Unbiased exponent component.
//   - si: Integer significand component.
//   - sf: Fractional significand bits for the exponent's remaining precision.
//
// Returns:
//   - float32: The float32 value represented by the supplied sign, exponent, and significand components.
func float32FromParts(sign bool, e int32, si uint64, sf uint64) float32 {
	f := ufloat32FromParts(e, si, sf)
	if sign {
		return -f
	}
	return f
}

// float64FromParts reconstructs a float64 value and applies its sign.
//
// Parameters:
//   - sign: True to negate the reconstructed magnitude; false to leave it nonnegative.
//   - e: Unbiased exponent component.
//   - si: Integer significand component.
//   - sf: Fractional significand bits for the exponent's remaining precision.
//
// Returns:
//   - float64: The float64 value represented by the supplied sign, exponent, and significand components.
func float64FromParts(sign bool, e int32, si uint64, sf uint64) float64 {
	f := ufloat64FromParts(e, si, sf)
	if sign {
		return -f
	}
	return f
}

// genUfloatRange generates nonnegative floating-point components within an inclusive magnitude range.
//
// Parameters:
//   - s: Bit stream supplying the random choices for exponent and significand.
//   - min: Nonnegative inclusive lower bound for the magnitude.
//   - max: Inclusive upper bound for the magnitude; it must be at least min.
//   - signifBits: Significand precision selector: 23 uses float32 decomposition, while other values use float64 decomposition.
//
// Returns:
//   - e: Unbiased exponent of the generated magnitude.
//   - si: Integer significand component of the generated magnitude.
//   - sf: Fractional significand bits of the generated magnitude.
func genUfloatRange(s bitStream, min float64, max float64, signifBits uint) (int32, uint64, uint64) {
	assert(min >= 0 && min <= max)

	var (
		minExp, maxExp                                 int32
		minSignifI, maxSignifI, minSignifF, maxSignifF uint64
	)
	if signifBits == float32SignifBits {
		minExp, minSignifI, minSignifF = ufloat32Parts(float32(min))
		maxExp, maxSignifI, maxSignifF = ufloat32Parts(float32(max))
	} else {
		minExp, minSignifI, minSignifF = ufloat64Parts(min)
		maxExp, maxSignifI, maxSignifF = ufloat64Parts(max)
	}

	i := s.beginGroup(floatExpLabel, false)
	e, lOverflow, rOverflow := genIntRange(s, int64(minExp), int64(maxExp), true)
	s.endGroup(i, false)

	fracBits := ufloatFracBits(int32(e), signifBits)

	j := s.beginGroup(floatSignifLabel, false)
	var siMin, siMax uint64
	switch {
	case lOverflow:
		siMin, siMax = minSignifI, minSignifI
	case rOverflow:
		siMin, siMax = maxSignifI, maxSignifI
	case minExp == maxExp:
		siMin, siMax = minSignifI, maxSignifI
	case int32(e) == minExp:
		siMin, siMax = minSignifI, bitmask64(signifBits-fracBits)
	case int32(e) == maxExp:
		siMin, siMax = 0, maxSignifI
	default:
		siMin, siMax = 0, bitmask64(signifBits-fracBits)
	}
	si, _, _ := genUintRange(s, siMin, siMax, false)
	var sfMin, sfMax uint64
	switch {
	case lOverflow:
		sfMin, sfMax = minSignifF, minSignifF
	case rOverflow:
		sfMin, sfMax = maxSignifF, maxSignifF
	case minExp == maxExp && minSignifI == maxSignifI:
		sfMin, sfMax = minSignifF, maxSignifF
	case int32(e) == minExp && si == minSignifI:
		sfMin, sfMax = minSignifF, bitmask64(fracBits)
	case int32(e) == maxExp && si == maxSignifI:
		sfMin, sfMax = 0, maxSignifF
	default:
		sfMin, sfMax = 0, bitmask64(fracBits)
	}
	maxR := bits.Len64(sfMax - sfMin)
	r := genUintNNoReject(s, uint64(maxR))
	sf, _, _ := genUintRange(s, sfMin, sfMax, false)
	s.endGroup(j, false)

	for i := uint(0); i < uint(maxR)-uint(r); i++ {
		mask := ^(uint64(1) << i)
		if sf&mask < sfMin {
			break
		}
		sf &= mask
	}

	return int32(e), si, sf
}

// genFloatRange generates signed floating-point components within an inclusive range.
//
// Parameters:
//   - s: Bit stream supplying the random sign, exponent, and significand choices.
//   - min: Inclusive lower bound for the generated value.
//   - max: Inclusive upper bound for the generated value.
//   - signifBits: Significand precision selector: 23 generates float32 components, while other values generate float64 components.
//
// Returns:
//   - sign: True when the generated value is negative, false when it is nonnegative.
//   - e: Unbiased exponent of the generated magnitude.
//   - si: Integer significand component of the generated magnitude.
//   - sf: Fractional significand bits of the generated magnitude.
func genFloatRange(s bitStream, min float64, max float64, signifBits uint) (bool, int32, uint64, uint64) {
	var posMin, negMin, pNeg float64
	if min >= 0 {
		posMin = min
		pNeg = 0
	} else if max <= 0 {
		negMin = -max
		pNeg = 1
	} else {
		pNeg = 0.5
	}

	if flipBiasedCoin(s, pNeg) {
		e, si, sf := genUfloatRange(s, negMin, -min, signifBits)
		return true, e, si, sf
	}
	e, si, sf := genUfloatRange(s, posMin, max, signifBits)
	return false, e, si, sf
}
