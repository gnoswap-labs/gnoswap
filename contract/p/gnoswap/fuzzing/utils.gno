package fuzzing

import (
	"math"
	"math/bits"
)

const (
	small = 5 // Bias towards small values and small collection sizes

	// Label constants for groups
	biasLabel      = "bias"
	intBitsLabel   = "intbits"
	coinFlipLabel  = "coinflip"
	repeatLabel    = ":repeat"
	tryLabel       = "try"
)

// genFloat01 generates a float64 in [0, 1) from bitstream.
func genFloat01(s bitStream) float64 {
	// Generate 53 bits for mantissa (IEEE 754 double precision)
	u := s.drawBits(53)
	return float64(u) / (1 << 53)
}

// genGeom generates a geometrically distributed value.
// Used for biased generation of integers.
func genGeom(s bitStream, p float64) uint64 {
	assertf(p > 0 && p < 1, "genGeom: p must be in (0, 1)")

	f := genFloat01(s)
	if f >= 1 {
		f = 1 - math.SmallestNonzeroFloat64
	}

	return uint64(math.Log(1-f) / math.Log(1-p))
}

// genUintNUnbiased generates a uniform uint64 in [0, max].
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

// genUintN generates a uint64 in [0, max] with optional bias.
func genUintN(s bitStream, max uint64, bias bool) (uint64, bool, bool) {
	if bias {
		return genUintNBiased(s, max)
	}
	return genUintNUnbiased(s, max), false, false
}

// genUintRange generates a uint64 in [min, max] with optional bias.
func genUintRange(s bitStream, min uint64, max uint64, bias bool) (uint64, bool, bool) {
	assertf(min <= max, "genUintRange: min > max")

	u, lOverflow, rOverflow := genUintN(s, max-min, bias)
	return min + u, lOverflow, rOverflow
}

// genIntRange generates an int64 in [min, max] with optional bias.
// Handles negative ranges and prefers zero when range includes it.
func genIntRange(s bitStream, min int64, max int64, bias bool) (int64, bool, bool) {
	assertf(min <= max, "genIntRange: min > max")

	var posMin, negMin uint64
	var pNeg float64

	if min >= 0 {
		// Positive range only
		posMin = uint64(min)
		pNeg = 0
	} else if max <= 0 {
		// Negative range only
		negMin = uint64(-max)
		pNeg = 1
	} else {
		// Range includes zero
		posMin = 0
		negMin = 1
		pos := uint64(max) + 1
		neg := uint64(-min)
		pNeg = float64(neg) / (float64(neg) + float64(pos))
		if bias {
			pNeg = 0.5 // Prefer zero crossing equally
		}
	}

	if flipBiasedCoin(s, pNeg) {
		// Generate negative
		u, lOverflow, rOverflow := genUintRange(s, negMin, uint64(-min), bias)
		return -int64(u), rOverflow, lOverflow && max <= 0
	}

	// Generate positive
	u, lOverflow, rOverflow := genUintRange(s, posMin, uint64(max), bias)
	return int64(u), lOverflow && min >= 0, rOverflow
}

// genIndex generates an index in [0, n-1] with optional bias.
func genIndex(s bitStream, n int, bias bool) int {
	assertf(n > 0, "genIndex: n must be positive")

	u, _, _ := genUintN(s, uint64(n-1), bias)
	return int(u)
}

// flipBiasedCoin returns true with probability p.
// Used for branching decisions in generation.
func flipBiasedCoin(s bitStream, p float64) bool {
	assertf(p >= 0 && p <= 1, "flipBiasedCoin: p must be in [0, 1]")

	i := s.beginGroup(coinFlipLabel, false)
	f := genFloat01(s)
	s.endGroup(i, false)

	return f >= 1-p
}

// repeat controls iteration count for Repeat-style operations.
// Implements geometric distribution for natural-looking test sizes.
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

// newRepeat creates a new repeat controller.
// minCount: minimum iterations (can be -1 for 0)
// maxCount: maximum iterations (can be -1 for unlimited)
// avgCount: average iterations (can be -1 for auto)
// label: group label
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

// avg returns the expected average count.
func (r *repeat) avg() int {
	return int(math.Ceil(r.avgCount))
}

// more returns true if another iteration should run.
// Uses geometric distribution to determine count.
func (r *repeat) more(s bitStream) bool {
	if r.group >= 0 {
		s.endGroup(r.group, r.rejected)
	}

	// Check forceStop before starting new group
	if r.forceStop {
		return false
	}

	r.group = s.beginGroup(r.label, true)
	r.rejected = false

	pCont := r.pContinue
	if r.count < r.minCount {
		pCont = 1 // Must continue until minCount
	} else if r.count >= r.maxCount {
		pCont = 0 // Must stop at maxCount
	}

	cont := flipBiasedCoin(s, pCont)
	if cont {
		r.count++
	} else {
		s.endGroup(r.group, false)
	}

	return cont
}

// reject marks the current iteration as rejected.
// Useful for Filter-style operations.
func (r *repeat) reject() {
	r.rejected = true
	r.rejections++
}
