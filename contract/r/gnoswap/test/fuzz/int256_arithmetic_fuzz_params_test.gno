package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	i256 "gno.land/p/gnoswap/int256"
	"gno.land/p/nt/ufmt"
)

// Arithmetic Identity Laws Parameters (for associativity, commutativity, distributivity tests)
type int256IdentityLawParams struct {
	a string
	b string
	c string
}

func (p *int256IdentityLawParams) IsValid() bool {
	// Identity laws are always valid (we test with wrap-around semantics)
	return true
}

func (p *int256IdentityLawParams) ToString() string {
	return ufmt.Sprintf("a: %s, b: %s, c: %s", p.a, p.b, p.c)
}

func NewValidInt256IdentityLawParams(t *fuzz.T) *int256IdentityLawParams {
	// Use smaller values to avoid overflow in some tests
	a := fuzz.Int64Range(-1<<20, 1<<20).Draw(t, "a").(int64)
	b := fuzz.Int64Range(-1<<20, 1<<20).Draw(t, "b").(int64)
	c := fuzz.Int64Range(-1<<20, 1<<20).Draw(t, "c").(int64)

	return &int256IdentityLawParams{
		a: i256.NewInt(a).ToString(),
		b: i256.NewInt(b).ToString(),
		c: i256.NewInt(c).ToString(),
	}
}

func NewRandomizedInt256IdentityLawParams(t *fuzz.T) *int256IdentityLawParams {
	// Use int64 range to avoid overflow issues with full int256 range
	a := fuzz.Int64().Draw(t, "a").(int64)
	b := fuzz.Int64().Draw(t, "b").(int64)
	c := fuzz.Int64().Draw(t, "c").(int64)

	return &int256IdentityLawParams{
		a: i256.NewInt(a).ToString(),
		b: i256.NewInt(b).ToString(),
		c: i256.NewInt(c).ToString(),
	}
}

// Comparison Parameters
type int256CmpParams struct {
	x string
	y string
}

func (p *int256CmpParams) IsValid() bool {
	// Comparison is always valid
	return true
}

func (p *int256CmpParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidInt256CmpParams(t *fuzz.T) *int256CmpParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256CmpParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedInt256CmpParams(t *fuzz.T) *int256CmpParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256CmpParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Sign Test Parameters
type int256SignParams struct {
	x string
}

func (p *int256SignParams) IsValid() bool {
	return true
}

func (p *int256SignParams) ToString() string {
	return ufmt.Sprintf("x: %s", p.x)
}

func NewValidInt256SignParams(t *fuzz.T) *int256SignParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	return &int256SignParams{
		x: x.ToString(),
	}
}

func NewRandomizedInt256SignParams(t *fuzz.T) *int256SignParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	return &int256SignParams{
		x: x.ToString(),
	}
}

// Clone Parameters
type int256CloneParams struct {
	x string
}

func (p *int256CloneParams) IsValid() bool {
	return true
}

func (p *int256CloneParams) ToString() string {
	return ufmt.Sprintf("x: %s", p.x)
}

func NewValidInt256CloneParams(t *fuzz.T) *int256CloneParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	return &int256CloneParams{
		x: x.ToString(),
	}
}

func NewRandomizedInt256CloneParams(t *fuzz.T) *int256CloneParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	return &int256CloneParams{
		x: x.ToString(),
	}
}

// Conversion Parameters (Int64, Uint64)
type int256ConversionParams struct {
	x string
}

func (p *int256ConversionParams) IsValid() bool {
	return true
}

func (p *int256ConversionParams) ToString() string {
	return ufmt.Sprintf("x: %s", p.x)
}

func NewValidInt256ConversionParams(t *fuzz.T) *int256ConversionParams {
	// Use values within int64 range for predictable conversion
	x := fuzz.Int64().Draw(t, "x").(int64)

	return &int256ConversionParams{
		x: i256.NewInt(x).ToString(),
	}
}

func NewRandomizedInt256ConversionParams(t *fuzz.T) *int256ConversionParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	return &int256ConversionParams{
		x: x.ToString(),
	}
}

// SetString Parameters
type int256SetStringParams struct {
	s string
}

func (p *int256SetStringParams) IsValid() bool {
	// Check if string is a valid decimal
	_, err := i256.FromDecimal(p.s)
	return err == nil
}

func (p *int256SetStringParams) ToString() string {
	return ufmt.Sprintf("s: %s", p.s)
}

func NewValidInt256SetStringParams(t *fuzz.T) *int256SetStringParams {
	// Generate a valid decimal string
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	return &int256SetStringParams{
		s: x.ToString(),
	}
}

func NewRandomizedInt256SetStringParams(t *fuzz.T) *int256SetStringParams {
	// Generate potentially invalid strings
	choice := fuzz.IntRange(0, 4).Draw(t, "choice").(int)

	var s string
	switch choice {
	case 0:
		// Valid positive number
		x := fuzz.Int256().Draw(t, "x").(*i256.Int)
		if x.Sign() < 0 {
			x.Neg(x)
		}
		s = x.ToString()
	case 1:
		// Valid negative number
		x := fuzz.Int256().Draw(t, "x").(*i256.Int)
		if x.Sign() > 0 {
			x.Neg(x)
		}
		s = x.ToString()
	case 2:
		// Zero
		s = "0"
	case 3:
		// Explicit positive sign
		x := fuzz.Uint64Range(1, 1<<62).Draw(t, "x").(uint64)
		s = ufmt.Sprintf("+%d", x)
	case 4:
		// Small int64 value
		x := fuzz.Int64().Draw(t, "x").(int64)
		s = i256.NewInt(x).ToString()
	}

	return &int256SetStringParams{
		s: s,
	}
}

// DivRem Parameters (for testing Div and Rem together)
type int256DivRemParams struct {
	x string
	y string
}

func (p *int256DivRemParams) IsValid() bool {
	// Division by zero panics
	y := i256.MustFromDecimal(p.y)
	return !y.IsZero()
}

func (p *int256DivRemParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidInt256DivRemParams(t *fuzz.T) *int256DivRemParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int64Range(1, 1<<62).Draw(t, "y").(int64)
	if fuzz.Bool().Draw(t, "yNeg").(bool) {
		y = -y
	}

	return &int256DivRemParams{
		x: x.ToString(),
		y: i256.NewInt(y).ToString(),
	}
}

func NewRandomizedInt256DivRemParams(t *fuzz.T) *int256DivRemParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256DivRemParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Boundary Value Parameters
type int256BoundaryParams struct {
	boundaryType int // 0: MinInt256, 1: MaxInt256, 2: Zero, 3: One, 4: NegOne
}

func (p *int256BoundaryParams) IsValid() bool {
	return true
}

func (p *int256BoundaryParams) ToString() string {
	return ufmt.Sprintf("boundaryType: %d", p.boundaryType)
}

func NewValidInt256BoundaryParams(t *fuzz.T) *int256BoundaryParams {
	boundaryType := fuzz.IntRange(0, 4).Draw(t, "boundaryType").(int)

	return &int256BoundaryParams{
		boundaryType: boundaryType,
	}
}

func NewRandomizedInt256BoundaryParams(t *fuzz.T) *int256BoundaryParams {
	boundaryType := fuzz.IntRange(0, 4).Draw(t, "boundaryType").(int)

	return &int256BoundaryParams{
		boundaryType: boundaryType,
	}
}

// Helper function to get Int from boundary type
func (p *int256BoundaryParams) GetValue() *i256.Int {
	switch p.boundaryType {
	case 0:
		return i256.MinInt256()
	case 1:
		return i256.MaxInt256()
	case 2:
		return i256.Zero()
	case 3:
		return i256.One()
	case 4:
		return i256.NewInt(-1)
	default:
		return i256.Zero()
	}
}
