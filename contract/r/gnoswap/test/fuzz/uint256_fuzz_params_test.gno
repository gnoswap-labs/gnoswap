package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// Mul Parameters
type mulParams struct {
	x string
	y string
}

func (p *mulParams) IsValid() bool {
	// Mul always succeeds (truncates overflow)
	return true
}

func (p *mulParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidMulParams(t *fuzz.T) *mulParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &mulParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedMulParams(t *fuzz.T) *mulParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &mulParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// MulOverflow Parameters
type mulOverflowParams struct {
	x string
	y string
}

func (p *mulOverflowParams) IsValid() bool {
	// Valid means no overflow: hi part of x*y must be zero
	x := u256.MustFromDecimal(p.x)
	y := u256.MustFromDecimal(p.y)
	hi := mulHi(x, y)
	return hi.IsZero()
}

func (p *mulOverflowParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidMulOverflowParams(t *fuzz.T) *mulOverflowParams {
	// Use smaller values to avoid overflow
	x := fuzz.Uint64Range(0, 1<<32-1).Draw(t, "x").(uint64)
	y := fuzz.Uint64Range(0, 1<<32-1).Draw(t, "y").(uint64)

	return &mulOverflowParams{
		x: u256.NewUint(x).ToString(),
		y: u256.NewUint(y).ToString(),
	}
}

func NewRandomizedMulOverflowParams(t *fuzz.T) *mulOverflowParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &mulOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Div Parameters
type divParams struct {
	x string
	y string
}

func (p *divParams) IsValid() bool {
	// Division by zero returns 0 (not panic), so always valid
	return true
}

func (p *divParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidDivParams(t *fuzz.T) *divParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	// Ensure y is non-zero
	y := fuzz.Uint64Range(1, 1<<63-1).Draw(t, "y").(uint64)

	return &divParams{
		x: x.ToString(),
		y: u256.NewUint(y).ToString(),
	}
}

func NewRandomizedDivParams(t *fuzz.T) *divParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &divParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Mod Parameters
type modParams struct {
	x string
	y string
}

func (p *modParams) IsValid() bool {
	// Mod by zero returns 0 (not panic), so always valid
	return true
}

func (p *modParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidModParams(t *fuzz.T) *modParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint64Range(1, 1<<63-1).Draw(t, "y").(uint64)

	return &modParams{
		x: x.ToString(),
		y: u256.NewUint(y).ToString(),
	}
}

func NewRandomizedModParams(t *fuzz.T) *modParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &modParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// DivMod Parameters
type divModParams struct {
	x string
	y string
}

func (p *divModParams) IsValid() bool {
	// DivMod by zero returns (0, 0) (not panic), so always valid
	return true
}

func (p *divModParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidDivModParams(t *fuzz.T) *divModParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint64Range(1, 1<<63-1).Draw(t, "y").(uint64)

	return &divModParams{
		x: x.ToString(),
		y: u256.NewUint(y).ToString(),
	}
}

func NewRandomizedDivModParams(t *fuzz.T) *divModParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &divModParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Add Parameters
type addParams struct {
	x string
	y string
}

func (p *addParams) IsValid() bool {
	// Add always succeeds (wraps on overflow)
	return true
}

func (p *addParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidAddParams(t *fuzz.T) *addParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &addParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedAddParams(t *fuzz.T) *addParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &addParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// AddOverflow Parameters
type addOverflowParams struct {
	x string
	y string
}

func (p *addOverflowParams) IsValid() bool {
	x := u256.MustFromDecimal(p.x)
	y := u256.MustFromDecimal(p.y)
	var z u256.Uint
	_, overflow := z.AddOverflow(x, y)
	return !overflow
}

func (p *addOverflowParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidAddOverflowParams(t *fuzz.T) *addOverflowParams {
	// Generate values that won't overflow when added
	x := fuzz.Uint64Range(0, 1<<63-1).Draw(t, "x").(uint64)
	y := fuzz.Uint64Range(0, 1<<63-1).Draw(t, "y").(uint64)

	return &addOverflowParams{
		x: u256.NewUint(x).ToString(),
		y: u256.NewUint(y).ToString(),
	}
}

func NewRandomizedAddOverflowParams(t *fuzz.T) *addOverflowParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &addOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Sub Parameters
type subParams struct {
	x string
	y string
}

func (p *subParams) IsValid() bool {
	// Sub always succeeds (wraps on underflow)
	return true
}

func (p *subParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidSubParams(t *fuzz.T) *subParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &subParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedSubParams(t *fuzz.T) *subParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &subParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// SubOverflow Parameters
type subOverflowParams struct {
	x string
	y string
}

func (p *subOverflowParams) IsValid() bool {
	x := u256.MustFromDecimal(p.x)
	y := u256.MustFromDecimal(p.y)
	return x.Gte(y)
}

func (p *subOverflowParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidSubOverflowParams(t *fuzz.T) *subOverflowParams {
	// Generate x and y such that x >= y
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	// Ensure x >= y by swapping if necessary
	if y.Gt(x) {
		x, y = y, x
	}

	return &subOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedSubOverflowParams(t *fuzz.T) *subOverflowParams {
	x := fuzz.Uint256().Draw(t, "x").(*u256.Uint)
	y := fuzz.Uint256().Draw(t, "y").(*u256.Uint)

	return &subOverflowParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// mulHi computes the upper 256 bits of x * y (512-bit multiplication)
// This matches the umul implementation in uint256 package
func mulHi(x, y *u256.Uint) *u256.Uint {
	var (
		res                           [8]uint64
		carry, carry4, carry5, carry6 uint64
		res1, res2, res3, res4, res5  uint64
	)

	carry, res[0] = mul64(x[0], y[0])
	carry, res1 = umulHop(carry, x[1], y[0])
	carry, res2 = umulHop(carry, x[2], y[0])
	carry4, res3 = umulHop(carry, x[3], y[0])

	carry, res[1] = umulHop(res1, x[0], y[1])
	carry, res2 = umulStep(res2, x[1], y[1], carry)
	carry, res3 = umulStep(res3, x[2], y[1], carry)
	carry5, res4 = umulStep(carry4, x[3], y[1], carry)

	carry, res[2] = umulHop(res2, x[0], y[2])
	carry, res3 = umulStep(res3, x[1], y[2], carry)
	carry, res4 = umulStep(res4, x[2], y[2], carry)
	carry6, res5 = umulStep(carry5, x[3], y[2], carry)

	carry, res[3] = umulHop(res3, x[0], y[3])
	carry, res[4] = umulStep(res4, x[1], y[3], carry)
	carry, res[5] = umulStep(res5, x[2], y[3], carry)
	res[7], res[6] = umulStep(carry6, x[3], y[3], carry)

	return &u256.Uint{res[4], res[5], res[6], res[7]}
}

// umulStep computes (hi * 2^64 + lo) = z + (x * y) + carry
func umulStep(z, x, y, carry uint64) (hi, lo uint64) {
	hi, lo = mul64(x, y)
	lo, c := add64(lo, carry)
	hi += c
	lo, c = add64(lo, z)
	hi += c
	return hi, lo
}

// umulHop computes (hi * 2^64 + lo) = z + (x * y)
func umulHop(z, x, y uint64) (hi, lo uint64) {
	hi, lo = mul64(x, y)
	lo, c := add64(lo, z)
	hi += c
	return hi, lo
}

func mul64(x, y uint64) (hi, lo uint64) {
	const mask32 = 1<<32 - 1
	x0 := x & mask32
	x1 := x >> 32
	y0 := y & mask32
	y1 := y >> 32
	w0 := x0 * y0
	t := x1*y0 + w0>>32
	w1 := t & mask32
	w2 := t >> 32
	w1 += x0 * y1
	hi = x1*y1 + w2 + w1>>32
	lo = x * y
	return
}

func mulAddCarry(x, y, z uint64) (hi, lo uint64) {
	hi, lo = mul64(x, y)
	var c uint64
	lo, c = add64(lo, z)
	hi += c
	return
}

func mulAddCarry2(x, y, z, w uint64) (hi, lo uint64) {
	hi, lo = mul64(x, y)
	var c uint64
	lo, c = add64(lo, z)
	hi += c
	lo, c = add64(lo, w)
	hi += c
	return
}

func add64(x, y uint64) (sum, carry uint64) {
	sum = x + y
	if sum < x {
		carry = 1
	}
	return
}
