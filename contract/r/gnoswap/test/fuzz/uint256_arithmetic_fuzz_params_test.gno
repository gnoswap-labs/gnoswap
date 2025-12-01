package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// Arithmetic Identity Laws Parameters
type identityLawParams struct {
	a string
	b string
	c string
}

func (p *identityLawParams) IsValid() bool {
	// Identity laws are always valid (we test with wrap-around semantics)
	return true
}

func (p *identityLawParams) ToString() string {
	return ufmt.Sprintf("a: %s, b: %s, c: %s", p.a, p.b, p.c)
}

func NewValidIdentityLawParams(t *fuzz.T) *identityLawParams {
	// Use smaller values to avoid overflow in some tests
	a := fuzz.Uint64Range(0, 1<<21).Draw(t, "a").(uint64)
	b := fuzz.Uint64Range(0, 1<<21).Draw(t, "b").(uint64)
	c := fuzz.Uint64Range(0, 1<<21).Draw(t, "c").(uint64)

	return &identityLawParams{
		a: u256.NewUint(a).ToString(),
		b: u256.NewUint(b).ToString(),
		c: u256.NewUint(c).ToString(),
	}
}

func NewRandomizedIdentityLawParams(t *fuzz.T) *identityLawParams {
	a := fuzz.Uint256().Draw(t, "a").(*u256.Uint)
	b := fuzz.Uint256().Draw(t, "b").(*u256.Uint)
	c := fuzz.Uint256().Draw(t, "c").(*u256.Uint)

	return &identityLawParams{
		a: a.ToString(),
		b: b.ToString(),
		c: c.ToString(),
	}
}

// umul Sparse Parameters
type umulSparseParams struct {
	x0 uint64
	x1 uint64
	x2 uint64
	x3 uint64
	y0 uint64
	y1 uint64
	y2 uint64
	y3 uint64
}

func (p *umulSparseParams) IsValid() bool {
	// umul is always valid
	return true
}

func (p *umulSparseParams) ToString() string {
	return ufmt.Sprintf("x: [%d, %d, %d, %d], y: [%d, %d, %d, %d]",
		p.x0, p.x1, p.x2, p.x3,
		p.y0, p.y1, p.y2, p.y3)
}

// NewValidUmulSparseParams generates sparse patterns for testing umul code paths
func NewValidUmulSparseParams(t *fuzz.T) *umulSparseParams {
	patternType := fuzz.IntRange(0, 9).Draw(t, "patternType").(int)

	var x0, x1, x2, x3, y0, y1, y2, y3 uint64
	maxU64 := uint64(0xFFFFFFFFFFFFFFFF)

	switch patternType {
	case 0: // lenX=1, lenY=1: {MAX_UINT64, 0, 0, 0} × {MAX_UINT64, 0, 0, 0}
		x0, x1, x2, x3 = maxU64, 0, 0, 0
		y0, y1, y2, y3 = maxU64, 0, 0, 0
	case 1: // lenX=4, lenY=4 high only: {0, 0, 0, MAX_UINT64} × {0, 0, 0, MAX_UINT64}
		x0, x1, x2, x3 = 0, 0, 0, maxU64
		y0, y1, y2, y3 = 0, 0, 0, maxU64
	case 2: // lenX=1, lenY=4 asymmetric: {MAX_UINT64, 0, 0, 0} × {1, 2, 3, 4}
		x0, x1, x2, x3 = maxU64, 0, 0, 0
		y0, y1, y2, y3 = 1, 2, 3, 4
	case 3: // lenX=4, lenY=1 asymmetric: {1, 2, 3, 4} × {MAX_UINT64, 0, 0, 0}
		x0, x1, x2, x3 = 1, 2, 3, 4
		y0, y1, y2, y3 = maxU64, 0, 0, 0
	case 4: // zero middle words: {0xFFFF, 0, 0xFFFF, 0} × {1, 1, 1, 1}
		x0, x1, x2, x3 = 0xFFFF, 0, 0xFFFF, 0
		y0, y1, y2, y3 = 1, 1, 1, 1
	case 5: // x == 0: {0, 0, 0, 0} × {1, 2, 3, 4}
		x0, x1, x2, x3 = 0, 0, 0, 0
		y0, y1, y2, y3 = 1, 2, 3, 4
	case 6: // y == 0: {1, 2, 3, 4} × {0, 0, 0, 0}
		x0, x1, x2, x3 = 1, 2, 3, 4
		y0, y1, y2, y3 = 0, 0, 0, 0
	case 7: // MAX × MAX: maximum carry propagation
		x0, x1, x2, x3 = maxU64, maxU64, maxU64, maxU64
		y0, y1, y2, y3 = maxU64, maxU64, maxU64, maxU64
	case 8: // alternating zeros: {0xFFFF, 0, 0xFFFF, 0} × {0, 0xFFFF, 0, 0xFFFF}
		x0, x1, x2, x3 = 0xFFFF, 0, 0xFFFF, 0
		y0, y1, y2, y3 = 0, 0xFFFF, 0, 0xFFFF
	case 9: // random sparse
		mask := fuzz.Uint64Range(0, 15).Draw(t, "mask").(uint64)
		if mask&1 != 0 {
			x0 = fuzz.Uint64().Draw(t, "x0").(uint64)
		}
		if mask&2 != 0 {
			x1 = fuzz.Uint64().Draw(t, "x1").(uint64)
		}
		if mask&4 != 0 {
			x2 = fuzz.Uint64().Draw(t, "x2").(uint64)
		}
		if mask&8 != 0 {
			x3 = fuzz.Uint64().Draw(t, "x3").(uint64)
		}
		y0 = fuzz.Uint64().Draw(t, "y0").(uint64)
		y1 = fuzz.Uint64().Draw(t, "y1").(uint64)
		y2 = fuzz.Uint64().Draw(t, "y2").(uint64)
		y3 = fuzz.Uint64().Draw(t, "y3").(uint64)
	}

	return &umulSparseParams{
		x0: x0, x1: x1, x2: x2, x3: x3,
		y0: y0, y1: y1, y2: y2, y3: y3,
	}
}

func NewRandomizedUmulSparseParams(t *fuzz.T) *umulSparseParams {
	return &umulSparseParams{
		x0: fuzz.Uint64().Draw(t, "x0").(uint64),
		x1: fuzz.Uint64().Draw(t, "x1").(uint64),
		x2: fuzz.Uint64().Draw(t, "x2").(uint64),
		x3: fuzz.Uint64().Draw(t, "x3").(uint64),
		y0: fuzz.Uint64().Draw(t, "y0").(uint64),
		y1: fuzz.Uint64().Draw(t, "y1").(uint64),
		y2: fuzz.Uint64().Draw(t, "y2").(uint64),
		y3: fuzz.Uint64().Draw(t, "y3").(uint64),
	}
}
