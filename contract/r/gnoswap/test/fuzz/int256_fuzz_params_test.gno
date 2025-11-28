package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

const (
	smallIntRangeMin = "-1000000000000000000"
	smallIntRangeMax = "1000000000000000000"
	smallMulRangeMin = "-1000000000"
	smallMulRangeMax = "1000000000"
)

var (
	maxInt256Abs = i256.MaxInt256().Abs()
	minInt256Abs = i256.MinInt256().Abs()
)

// Add Parameters
type intAddParams struct {
	x string
	y string
}

func (p *intAddParams) IsValid() bool {
	return true
}

func (p *intAddParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidIntAddParams(t *fuzz.T) *intAddParams {
	x := fuzz.Int256Range(smallIntRangeMin, smallIntRangeMax).Draw(t, "x").(*i256.Int)
	y := fuzz.Int256Range(smallIntRangeMin, smallIntRangeMax).Draw(t, "y").(*i256.Int)

	return &intAddParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedIntAddParams(t *fuzz.T) *intAddParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &intAddParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// AddOverflow Parameters
type intAddOverflowParams struct {
	x string
	y string
}

func (p *intAddOverflowParams) IsValid() bool {
	x := i256.MustFromDecimal(p.x)
	y := i256.MustFromDecimal(p.y)

	_, overflow := new(i256.Int).AddOverflow(x, y)
	return !overflow
}

func (p *intAddOverflowParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidIntAddOverflowParams(t *fuzz.T) *intAddOverflowParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	var limit *u256.Uint
	if x.IsNeg() {
		limit = minInt256Abs
	} else {
		limit = maxInt256Abs
	}

	remaining := new(u256.Uint).Sub(limit, x.Abs())
	yAbs := fuzz.Uint256Range("0", remaining.ToString()).Draw(t, "yAbs").(*u256.Uint)
	y := newIntWithSign(yAbs, x.IsNeg())

	return &intAddOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedIntAddOverflowParams(t *fuzz.T) *intAddOverflowParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &intAddOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Sub Parameters
type intSubParams struct {
	x string
	y string
}

func (p *intSubParams) IsValid() bool {
	return true
}

func (p *intSubParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidIntSubParams(t *fuzz.T) *intSubParams {
	x := fuzz.Int256Range(smallIntRangeMin, smallIntRangeMax).Draw(t, "x").(*i256.Int)
	y := fuzz.Int256Range(smallIntRangeMin, smallIntRangeMax).Draw(t, "y").(*i256.Int)

	return &intSubParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedIntSubParams(t *fuzz.T) *intSubParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &intSubParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// SubOverflow Parameters
type intSubOverflowParams struct {
	x string
	y string
}

func (p *intSubOverflowParams) IsValid() bool {
	x := i256.MustFromDecimal(p.x)
	y := i256.MustFromDecimal(p.y)

	_, overflow := new(i256.Int).SubOverflow(x, y)
	return !overflow
}

func (p *intSubOverflowParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidIntSubOverflowParams(t *fuzz.T) *intSubOverflowParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	var limit *u256.Uint
	if x.IsNeg() {
		limit = minInt256Abs
	} else {
		limit = maxInt256Abs
	}

	remaining := new(u256.Uint).Sub(limit, x.Abs())
	negYAbs := fuzz.Uint256Range("0", remaining.ToString()).Draw(t, "negYAbs").(*u256.Uint)
	negY := newIntWithSign(negYAbs, x.IsNeg())
	y := i256.New().Neg(negY)

	return &intSubOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedIntSubOverflowParams(t *fuzz.T) *intSubOverflowParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &intSubOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Mul Parameters
type intMulParams struct {
	x string
	y string
}

func (p *intMulParams) IsValid() bool {
	return true
}

func (p *intMulParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidIntMulParams(t *fuzz.T) *intMulParams {
	x := fuzz.Int256Range(smallMulRangeMin, smallMulRangeMax).Draw(t, "x").(*i256.Int)
	y := fuzz.Int256Range(smallMulRangeMin, smallMulRangeMax).Draw(t, "y").(*i256.Int)

	return &intMulParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedIntMulParams(t *fuzz.T) *intMulParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &intMulParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// MulOverflow Parameters
type intMulOverflowParams struct {
	x string
	y string
}

func (p *intMulOverflowParams) IsValid() bool {
	x := i256.MustFromDecimal(p.x)
	y := i256.MustFromDecimal(p.y)

	_, overflow := new(i256.Int).MulOverflow(x, y)
	return !overflow
}

func (p *intMulOverflowParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidIntMulOverflowParams(t *fuzz.T) *intMulOverflowParams {
	x := fuzz.Int256Range(smallMulRangeMin, smallMulRangeMax).Draw(t, "x").(*i256.Int)
	y := fuzz.Int256Range(smallMulRangeMin, smallMulRangeMax).Draw(t, "y").(*i256.Int)

	return &intMulOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedIntMulOverflowParams(t *fuzz.T) *intMulOverflowParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &intMulOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Div Parameters
type intDivParams struct {
	x string
	y string
}

func (p *intDivParams) IsValid() bool {
	return !i256.MustFromDecimal(p.y).IsZero()
}

func (p *intDivParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidIntDivParams(t *fuzz.T) *intDivParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)
	if y.IsZero() {
		y = i256.One()
	}

	return &intDivParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedIntDivParams(t *fuzz.T) *intDivParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &intDivParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func newIntWithSign(abs *u256.Uint, neg bool) *i256.Int {
	val := i256.FromUint256(abs)
	if neg && !abs.IsZero() {
		val.Neg(val)
	}
	return val
}
