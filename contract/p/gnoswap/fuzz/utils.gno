// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzz

import (
	"math"
	"math/bits"
)

const (
	biasLabel     = "bias"
	intBitsLabel  = "intbits"
	coinFlipLabel = "coinflip"
	dieRollLabel  = "dieroll"
	repeatLabel   = "@repeat"
)

// bitmask64 returns a mask containing the requested number of low-order one bits.
//
// Parameters:
//   - n: Number of low-order bits to set; values at least 64 request the full uint64 mask.
//
// Returns:
//   - uint64: A mask with bits [0, n) set, or math.MaxUint64 when n >= 64.
func bitmask64(n uint) uint64 {
	if n >= 64 {
		return math.MaxUint64
	}
	return (1 << n) - 1
}

// genFloat01 draws a uniformly spaced float64 in the half-open interval [0, 1).
//
// Parameters:
//   - s: Bit stream from which the 53 random mantissa bits are drawn.
//
// Returns:
//   - float64: A value in [0, 1) with 53 bits of random precision.
func genFloat01(s bitStream) float64 {
	u := s.drawBits(53)
	return float64(u) / (1 << 53)
}

// genGeom generates a geometrically distributed value.
// Used for biased generation of integers.
//
// Parameters:
//   - s: Bit stream supplying the random draw.
//   - p: Geometric continuation parameter; it must satisfy 0 < p < 1.
//
// Returns:
//   - uint64: A nonnegative geometrically distributed count, with invalid p causing an assertion panic.
func genGeom(s bitStream, p float64) uint64 {
	assertf(p > 0 && p < 1, "genGeom: p must be in (0, 1)")

	f := genFloat01(s)
	if f >= 1 {
		f = 1 - math.SmallestNonzeroFloat64
	}

	return uint64(math.Log(1-f) / math.Log(1-p))
}

// genUintNNoReject draws a bounded unsigned integer without rejection sampling.
//
// Parameters:
//   - s: Bit stream supplying the random bits.
//   - max: Inclusive upper bound for the result.
//
// Returns:
//   - uint64: A value in [0, max]; bit patterns above max are clamped to max rather than redrawn.
func genUintNNoReject(s bitStream, max uint64) uint64 {
	bitlen := bits.Len64(max)
	i := s.beginGroup(intBitsLabel, false)
	u := s.drawBits(bitlen)
	s.endGroup(i, false)
	if u > max {
		u = max
	}
	return u
}

// genUintNUnbiased draws an unsigned integer uniformly from an inclusive range.
//
// Parameters:
//   - s: Bit stream supplying random bit patterns until one is accepted.
//   - max: Inclusive upper bound for the result.
//
// Returns:
//   - uint64: A uniformly selected value in [0, max].
func genUintNUnbiased(s bitStream, max uint64) uint64 {
	bitlen := bits.Len64(max)

	for {
		u := s.drawBits(bitlen)
		if u <= max {
			return u
		}
	}
}

// genUintNBiased generates a biased uint64 in [0, max].
// Prefers smaller values for better test case minimization.
// Returns (value, isMin, isMax).
//
// Parameters:
//   - s: Bit stream supplying bias and integer-bit draws.
//   - max: Inclusive upper bound for the generated value.
//
// Returns:
//   - value: A value in [0, max], favoring smaller values to produce shrink-friendly cases.
//   - isMin: True when value is zero and the draw used minimal bit usage; false otherwise.
//   - isMax: True when value equals max and the draw used high bit usage; false otherwise.
func genUintNBiased(s bitStream, max uint64) (uint64, bool, bool) {
	bitlen := bits.Len64(max)

	// Draw from geometric distribution for bit length
	i := s.beginGroup(biasLabel, false)
	m := math.Max(8, (float64(bitlen)+48)/7)
	n := genGeom(s, 1/(m+1)) + 1
	s.endGroup(i, false)

	if int(n) < bitlen {
		bitlen = int(n)
	} else if int(n) >= 64-(16-int(m))*4 {
		bitlen = 65 // Will return max
	}

	for {
		i := s.beginGroup(intBitsLabel, false)
		u := s.drawBits(bitlen)
		ok := bitlen > 64 || u <= max
		s.endGroup(i, !ok)

		if bitlen > 64 {
			u = max
		}
		if u <= max {
			// isMin is true when we drew 0 with minimal bit usage (n==1)
			// isMax is true when we drew max with high bit usage
			isMin := u == 0 && int(n) <= 1
			isMax := u == max && bitlen >= int(n)
			return u, isMin, isMax
		}
	}
}

// genUintN chooses biased or unbiased bounded-integer generation.
//
// Parameters:
//   - s: Bit stream supplying the random choices.
//   - max: Inclusive upper bound for the generated value.
//   - bias: True to favor smaller values and report endpoint metadata; false to use rejection sampling.
//
// Returns:
//   - value: The generated value in [0, max].
//   - lOverflow: In biased mode, true only when the generated offset is zero with a minimal bit-length request; false when bias is false.
//   - rOverflow: In biased mode, true only when the generated offset equals max with a bit width at least the geometric request; false when bias is false.
func genUintN(s bitStream, max uint64, bias bool) (uint64, bool, bool) {
	if bias {
		return genUintNBiased(s, max)
	}
	return genUintNUnbiased(s, max), false, false
}

// genUintRange shifts bounded generation into an inclusive unsigned range.
//
// Parameters:
//   - s: Bit stream supplying the random choices.
//   - min: Inclusive lower bound of the range.
//   - max: Inclusive upper bound of the range; it must not be below min.
//   - bias: True to use shrink-friendly biased generation; false to use unbiased rejection sampling.
//
// Returns:
//   - value: The generated value in [min, max].
//   - lOverflow: Low-side metadata propagated from genUintN for the offset; when true, value is min and the biased draw used minimal bit width, and it is false for unbiased generation.
//   - rOverflow: High-side metadata propagated from genUintN for the offset; when true, value is max and the biased draw used its high-bit-width condition, and it is false for unbiased generation.
func genUintRange(s bitStream, min uint64, max uint64, bias bool) (uint64, bool, bool) {
	if min > max {
		assertf(false, "invalid range [%v, %v]", min, max)
	}

	u, lOverflow, rOverflow := genUintN(s, max-min, bias)

	return min + u, lOverflow, rOverflow
}

// genIntRange generates a bounded signed integer, selecting a sign when the range crosses zero.
//
// Parameters:
//   - s: Bit stream supplying sign and magnitude draws.
//   - min: Inclusive signed lower bound; it must not exceed max.
//   - max: Inclusive signed upper bound.
//   - bias: True to favor smaller magnitudes and preserve endpoint metadata; false to use unbiased bounded draws.
//
// Returns:
//   - value: The generated signed integer in [min, max].
//   - lOverflow: In biased mode, metadata indicating that the generated value reached the range's low/min endpoint with the corresponding endpoint representation; false for unbiased draws or unreachable endpoints.
//   - rOverflow: In biased mode, metadata indicating that the generated value reached the range's high/max endpoint with the corresponding endpoint representation; false for unbiased draws or unreachable endpoints.
func genIntRange(s bitStream, min int64, max int64, bias bool) (int64, bool, bool) {
	if min > max {
		assertf(false, "invalid range [%v, %v]", min, max)
	}

	var posMin, negMin uint64
	var pNeg float64
	if min >= 0 {
		posMin = uint64(min)
		pNeg = 0
	} else if max <= 0 {
		negMin = uint64(-max)
		pNeg = 1
	} else {
		posMin = 0
		negMin = 1
		pos := uint64(max) + 1
		neg := uint64(-min)
		pNeg = float64(neg) / (float64(neg) + float64(pos))
		if bias {
			pNeg = 0.5
		}
	}

	if flipBiasedCoin(s, pNeg) {
		u, lOverflow, rOverflow := genUintRange(s, negMin, uint64(-min), bias)
		return -int64(u), rOverflow, lOverflow && max <= 0
	}
	u, lOverflow, rOverflow := genUintRange(s, posMin, uint64(max), bias)
	return int64(u), lOverflow && min >= 0, rOverflow
}

// genIndex generates an index for a collection of n elements.
//
// Parameters:
//   - s: Bit stream supplying the bounded integer draw.
//   - n: Number of elements; must be positive.
//   - bias: True to favor lower indexes; false to use an unbiased draw.
//
// Returns:
//   - int: An index in the half-open interval [0, n); an invalid n causes an assertion panic.
func genIndex(s bitStream, n int, bias bool) int {
	assert(n > 0)

	u, _, _ := genUintN(s, uint64(n-1), bias)

	return int(u)
}

// flipBiasedCoin samples a boolean event with probability p.
//
// Parameters:
//   - s: Bit stream supplying the uniform random fraction.
//   - p: Probability of returning true, inclusive from 0 through 1.
//
// Returns:
//   - bool: True with probability p and false with probability 1-p; values of p outside [0, 1] cause an assertion panic.
func flipBiasedCoin(s bitStream, p float64) bool {
	assert(p >= 0 && p <= 1)

	i := s.beginGroup(coinFlipLabel, false)
	f := genFloat01(s)
	s.endGroup(i, false)

	return f >= 1-p
}

type loadedDie struct {
	table []int
}

// newLoadedDie builds a table-backed weighted die.
//
// Parameters:
//   - weights: Relative weights, one per zero-based outcome; the slice must be non-empty. When it has multiple outcomes, each weight must be positive and below 100; the sole weight is ignored.
//
// Returns:
//   - *loadedDie: A die whose table repeats each multi-outcome index according to its weight, or a deterministic outcome-zero die for a single-element slice; invalid multi-outcome weights cause an assertion panic.
func newLoadedDie(weights []int) *loadedDie {
	assert(len(weights) > 0)

	if len(weights) == 1 {
		return &loadedDie{
			table: []int{0},
		}
	}

	total := 0
	for _, w := range weights {
		assert(w > 0 && w < 100)
		total += w
	}

	table := make([]int, total)
	i := 0
	for n, w := range weights {
		for j := i; i < j+w; i++ {
			table[i] = n
		}
	}

	return &loadedDie{
		table: table,
	}
}

// roll draws one outcome from the loaded die's table.
//
// Parameters:
//   - s: Bit stream supplying the uniformly selected table index.
//
// Returns:
//   - int: The zero-based outcome index selected according to the die's configured weights.
func (d *loadedDie) roll(s bitStream) int {
	i := s.beginGroup(dieRollLabel, false)
	ix := genIndex(s, len(d.table), false)
	s.endGroup(i, false)

	return d.table[ix]
}

type repeat struct {
	minCount   int
	maxCount   int
	avgCount   float64
	pContinue  float64
	count      int
	group      int
	rejected   bool
	rejections int
	forceStop  bool
	label      string
}

// newRepeat creates repeat-state bookkeeping for a variable-length generation loop.
//
// Parameters:
//   - minCount: Minimum number of repetitions; negative values are normalized to zero.
//   - maxCount: Maximum number of repetitions; negative values are normalized to math.MaxInt.
//   - avgCount: Target average repetition count; negative values select an internal default derived from the bounds.
//   - label: Prefix used to label the bit-stream group for this repetition sequence.
//
// Returns:
//   - *repeat: Initialized repeat state that tracks count, rejection status, and continuation probability.
func newRepeat(minCount int, maxCount int, avgCount float64, label string) *repeat {
	if minCount < 0 {
		minCount = 0
	}
	if maxCount < 0 {
		maxCount = math.MaxInt
	}
	if avgCount < 0 {
		avgCount = float64(minCount) + math.Min(math.Max(float64(minCount), small), (float64(maxCount)-float64(minCount))/2)
	}

	return &repeat{
		minCount:  minCount,
		maxCount:  maxCount,
		avgCount:  avgCount,
		pContinue: 1 - 1/(1+avgCount-float64(minCount)),
		group:     -1,
		label:     label + repeatLabel,
	}
}

// avg returns the rounded-up target count used for repeat generation.
//
// Returns:
//   - int: The ceiling of the configured average repetition count.
func (r *repeat) avg() int {
	return int(math.Ceil(r.avgCount))
}

// more advances the repeat state and reports whether another item should be generated.
//
// Parameters:
//   - s: Bit stream used to sample continuation and to close the previous repetition group.
//
// Returns:
//   - bool: True when generation should continue and the repetition count is incremented; false when the sequence is stopped and its group is closed.
func (r *repeat) more(s bitStream) bool {
	if r.group >= 0 {
		s.endGroup(r.group, r.rejected)
	}

	r.group = s.beginGroup(r.label, true)
	r.rejected = false

	pCont := r.pContinue
	if r.count < r.minCount {
		pCont = 1
	} else if r.forceStop || r.count >= r.maxCount {
		pCont = 0
	}

	cont := flipBiasedCoin(s, pCont)
	if cont {
		r.count++
	} else {
		s.endGroup(r.group, false)
	}

	return cont
}

// reject removes the most recent repetition and marks its group as rejected.
func (r *repeat) reject() {
	assert(r.count > 0)
	r.count--
	r.rejected = true
	r.rejections++

	if r.rejections > r.count*2 {
		if r.count >= r.minCount {
			r.forceStop = true
		} else {
			panic(invalidData("too many rejections in repeat"))
		}
	}
}
