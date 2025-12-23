package math

import (
	"gno.land/p/gnoswap/fuzz"
	i256 "gno.land/p/gnoswap/int256"
	"gno.land/p/nt/ufmt"
)

// Add Parameters
type int256AddParams struct {
	x      string
	y      string
	result *i256.Int
}

func (p *int256AddParams) IsValid() bool {
	// Add always succeeds (wraps on overflow)
	return true
}

func (p *int256AddParams) AddResult(result *i256.Int) {
	p.result = result
}

func (p *int256AddParams) ToString() string {
	resultStr := "-"
	if p.result != nil {
		resultStr = p.result.ToString()
	}

	return ufmt.Sprintf("x: %s, y: %s, result: %s", p.x, p.y, resultStr)
}

func NewValidInt256AddParams(t *fuzz.T) *int256AddParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256AddParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedInt256AddParams(t *fuzz.T) *int256AddParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256AddParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// AddOverflow Parameters
type int256AddOverflowParams struct {
	x        string
	y        string
	result   *i256.Int
	overflow bool
}

func (p *int256AddOverflowParams) IsValid() bool {
	x := i256.MustFromDecimal(p.x)
	y := i256.MustFromDecimal(p.y)

	// Check if addition would overflow
	// Overflow occurs when:
	// - Both positive and sum > MaxInt256
	// - Both negative and sum < MinInt256
	if x.Sign() >= 0 && y.Sign() >= 0 {
	    // Both non-negative: check if x + y > MaxInt256
		maxInt := i256.MaxInt256()
		remain := new(i256.Int).Sub(maxInt, y)
		return x.Lte(remain)
	}

	if x.Sign() < 0 && y.Sign() < 0 {
	    // Both negative: check if x + y < MinInt256
		minInt := i256.MinInt256()
		remain := new(i256.Int).Sub(minInt, y)
		return x.Gte(remain)
	}

	// Different signs: no overflow possible
	return true
}

func (p *int256AddOverflowParams) AddResult(result *i256.Int, overflow bool) {
	p.result = result
	p.overflow = overflow
}

func (p *int256AddOverflowParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s, result: %s, overflow: %t", p.x, p.y, p.result.ToString(), p.overflow)
}

func NewValidInt256AddOverflowParams(t *fuzz.T) *int256AddOverflowParams {
	// Generate values that won't overflow when added
	x := fuzz.Int64Range(-1<<62, 1<<62).Draw(t, "x").(int64)
	y := fuzz.Int64Range(-1<<62, 1<<62).Draw(t, "y").(int64)

	return &int256AddOverflowParams{
		x: i256.NewInt(x).ToString(),
		y: i256.NewInt(y).ToString(),
	}
}

func NewRandomizedInt256AddOverflowParams(t *fuzz.T) *int256AddOverflowParams {
	// Use int64 range to avoid issues with full int256 generator
	x := fuzz.Int64().Draw(t, "x").(int64)
	y := fuzz.Int64().Draw(t, "y").(int64)

	return &int256AddOverflowParams{
		x: i256.NewInt(x).ToString(),
		y: i256.NewInt(y).ToString(),
	}
}

// Sub Parameters
type int256SubParams struct {
	x      string
	y      string
	result *i256.Int
}

func (p *int256SubParams) IsValid() bool {
	// Sub always succeeds (wraps on underflow)
	return true
}

func (p *int256SubParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidInt256SubParams(t *fuzz.T) *int256SubParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256SubParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedInt256SubParams(t *fuzz.T) *int256SubParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256SubParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// SubOverflow Parameters
type int256SubOverflowParams struct {
	x string
	y string
}

func (p *int256SubOverflowParams) IsValid() bool {
	x := i256.MustFromDecimal(p.x)
	y := i256.MustFromDecimal(p.y)

	// x - y == x + (-y)
	// Overflow occurs when:
	// - x positive, y negative, and x - y > MaxInt256
	// - x negative, y positive, and x - y < MinInt256
	if x.Sign() >= 0 && y.Sign() < 0 {
	    // x - (-|y|) = x + |y|, check if > MaxInt256
		maxInt := i256.MaxInt256()
		negY := new(i256.Int).Neg(y)
		remain := new(i256.Int).Sub(maxInt, negY)
		return x.Lte(remain)
	}

	if x.Sign() < 0 && y.Sign() > 0 {
	    // x - y where x < 0, y > 0, check if < MinInt256
		minInt := i256.MinInt256()
		remain := new(i256.Int).Add(minInt, y)
		return x.Gte(remain)
	}

	// Same signs: no overflow possible
	return true
}

func (p *int256SubOverflowParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidInt256SubOverflowParams(t *fuzz.T) *int256SubOverflowParams {
	// Generate values that won't overflow when subtracted
	x := fuzz.Int64Range(-1<<62, 1<<62).Draw(t, "x").(int64)
	y := fuzz.Int64Range(-1<<62, 1<<62).Draw(t, "y").(int64)

	return &int256SubOverflowParams{
		x: i256.NewInt(x).ToString(),
		y: i256.NewInt(y).ToString(),
	}
}

func NewRandomizedInt256SubOverflowParams(t *fuzz.T) *int256SubOverflowParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256SubOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Mul Parameters
type int256MulParams struct {
	x string
	y string
}

func (p *int256MulParams) IsValid() bool {
	// Mul always succeeds (truncates overflow)
	return true
}

func (p *int256MulParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidInt256MulParams(t *fuzz.T) *int256MulParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256MulParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedInt256MulParams(t *fuzz.T) *int256MulParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256MulParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// MulOverflow Parameters
type int256MulOverflowParams struct {
	x string
	y string
}

func (p *int256MulOverflowParams) IsValid() bool {
	x := i256.MustFromDecimal(p.x)
	y := i256.MustFromDecimal(p.y)

	// Check for multiplication overflow
	// Special case: multiplication by 0 never overflows
	if x.IsZero() || y.IsZero() {
		return true
	}

	// Use MulOverflow to check
	_, overflow := new(i256.Int).MulOverflow(x, y)
	return !overflow
}

func (p *int256MulOverflowParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidInt256MulOverflowParams(t *fuzz.T) *int256MulOverflowParams {
	// Use smaller values to avoid overflow
	x := fuzz.Int64Range(-1<<31, 1<<31).Draw(t, "x").(int64)
	y := fuzz.Int64Range(-1<<31, 1<<31).Draw(t, "y").(int64)

	return &int256MulOverflowParams{
		x: i256.NewInt(x).ToString(),
		y: i256.NewInt(y).ToString(),
	}
}

func NewRandomizedInt256MulOverflowParams(t *fuzz.T) *int256MulOverflowParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256MulOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Div Parameters
type int256DivParams struct {
	x string
	y string
}

func (p *int256DivParams) IsValid() bool {
	// Division by zero panics
	y := i256.MustFromDecimal(p.y)
	return !y.IsZero()
}

func (p *int256DivParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidInt256DivParams(t *fuzz.T) *int256DivParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	// Ensure y is non-zero
	y := fuzz.Int64Range(1, 1<<62).Draw(t, "y").(int64)
	// Randomly make y negative
	if fuzz.Bool().Draw(t, "yNeg").(bool) {
		y = -y
	}

	return &int256DivParams{
		x: x.ToString(),
		y: i256.NewInt(y).ToString(),
	}
}

func NewRandomizedInt256DivParams(t *fuzz.T) *int256DivParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256DivParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Rem Parameters
type int256RemParams struct {
	x string
	y string
}

func (p *int256RemParams) IsValid() bool {
	// Remainder by zero panics
	y := i256.MustFromDecimal(p.y)
	return !y.IsZero()
}

func (p *int256RemParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidInt256RemParams(t *fuzz.T) *int256RemParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int64Range(1, 1<<62).Draw(t, "y").(int64)
	if fuzz.Bool().Draw(t, "yNeg").(bool) {
		y = -y
	}

	return &int256RemParams{
		x: x.ToString(),
		y: i256.NewInt(y).ToString(),
	}
}

func NewRandomizedInt256RemParams(t *fuzz.T) *int256RemParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256RemParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Neg Parameters
type int256NegParams struct {
	x string
}

func (p *int256NegParams) IsValid() bool {
	// Neg always succeeds
	return true
}

func (p *int256NegParams) ToString() string {
	return ufmt.Sprintf("x: %s", p.x)
}

func NewValidInt256NegParams(t *fuzz.T) *int256NegParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	return &int256NegParams{
		x: x.ToString(),
	}
}

func NewRandomizedInt256NegParams(t *fuzz.T) *int256NegParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	return &int256NegParams{
		x: x.ToString(),
	}
}

// Abs Parameters
type int256AbsParams struct {
	x string
}

func (p *int256AbsParams) IsValid() bool {
	// Abs always succeeds (returns uint256)
	return true
}

func (p *int256AbsParams) ToString() string {
	return ufmt.Sprintf("x: %s", p.x)
}

func NewValidInt256AbsParams(t *fuzz.T) *int256AbsParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	return &int256AbsParams{
		x: x.ToString(),
	}
}

func NewRandomizedInt256AbsParams(t *fuzz.T) *int256AbsParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)

	return &int256AbsParams{
		x: x.ToString(),
	}
}
