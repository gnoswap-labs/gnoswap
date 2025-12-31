package math

import (
	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// MulDiv Parameters
type mulDivParams struct {
	a           string
	b           string
	denominator string
}

func (p *mulDivParams) IsValid() bool {
	d := u256.MustFromDecimal(p.denominator)
	// denominator must be non-zero
	if d.IsZero() {
		return false
	}

	a := u256.MustFromDecimal(p.a)
	b := u256.MustFromDecimal(p.b)

	// Compute hi (upper 256 bits of a * b)
	hi := mulHi(a, b)

	// MulDiv panics when hi >= denominator
	return hi.Lt(d)
}

func (p *mulDivParams) ToString() string {
	return ufmt.Sprintf("a: %s, b: %s, denominator: %s", p.a, p.b, p.denominator)
}

func NewValidMulDivParams(t *fuzz.T) *mulDivParams {
	// Use smaller values to avoid overflow
	a := fuzz.Uint64Range(1, 1<<32-1).Draw(t, "a").(uint64)
	b := fuzz.Uint64Range(1, 1<<32-1).Draw(t, "b").(uint64)
	d := fuzz.Uint64Range(1, 1<<32-1).Draw(t, "denominator").(uint64)

	return &mulDivParams{
		a:           u256.NewUint(a).ToString(),
		b:           u256.NewUint(b).ToString(),
		denominator: u256.NewUint(d).ToString(),
	}
}

func NewRandomizedMulDivParams(t *fuzz.T) *mulDivParams {
	a := fuzz.Uint256().Draw(t, "a").(*u256.Uint)
	b := fuzz.Uint256().Draw(t, "b").(*u256.Uint)
	d := fuzz.Uint256().Draw(t, "denominator").(*u256.Uint)

	return &mulDivParams{
		a:           a.ToString(),
		b:           b.ToString(),
		denominator: d.ToString(),
	}
}

// MulDivRoundingUp Parameters
type mulDivRoundingUpParams struct {
	a           string
	b           string
	denominator string
}

func (p *mulDivRoundingUpParams) IsValid() bool {
	d := u256.MustFromDecimal(p.denominator)
	// denominator must be non-zero
	if d.IsZero() {
		return false
	}

	a := u256.MustFromDecimal(p.a)
	b := u256.MustFromDecimal(p.b)

	// Compute hi (upper 256 bits of a * b)
	hi := mulHi(a, b)

	// MulDivRoundingUp panics when hi >= denominator
	return hi.Lt(d)
}

func (p *mulDivRoundingUpParams) ToString() string {
	return ufmt.Sprintf("a: %s, b: %s, denominator: %s", p.a, p.b, p.denominator)
}

func NewValidMulDivRoundingUpParams(t *fuzz.T) *mulDivRoundingUpParams {
	a := fuzz.Uint64Range(1, 1<<32-1).Draw(t, "a").(uint64)
	b := fuzz.Uint64Range(1, 1<<32-1).Draw(t, "b").(uint64)
	d := fuzz.Uint64Range(1, 1<<32-1).Draw(t, "denominator").(uint64)

	return &mulDivRoundingUpParams{
		a:           u256.NewUint(a).ToString(),
		b:           u256.NewUint(b).ToString(),
		denominator: u256.NewUint(d).ToString(),
	}
}

func NewRandomizedMulDivRoundingUpParams(t *fuzz.T) *mulDivRoundingUpParams {
	a := fuzz.Uint256().Draw(t, "a").(*u256.Uint)
	b := fuzz.Uint256().Draw(t, "b").(*u256.Uint)
	d := fuzz.Uint256().Draw(t, "denominator").(*u256.Uint)

	return &mulDivRoundingUpParams{
		a:           a.ToString(),
		b:           b.ToString(),
		denominator: d.ToString(),
	}
}

// DivRoundingUp Parameters

type divRoundingUpParams struct {
	x string
	y string
}

func (p *divRoundingUpParams) IsValid() bool {
	// DivRoundingUp panics only on zero denominator
	y := u256.MustFromDecimal(p.y)
	return !y.IsZero()
}

func (p *divRoundingUpParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidDivRoundingUpParams(t *fuzz.T) *divRoundingUpParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint64Range(1, 1<<63-1).Draw(t, "y").(uint64)

	return &divRoundingUpParams{
		x: x.ToString(),
		y: u256.NewUint(y).ToString(),
	}
}

func NewRandomizedDivRoundingUpParams(t *fuzz.T) *divRoundingUpParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &divRoundingUpParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}
