package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	i256 "gno.land/p/gnoswap/int256"
	"gno.land/p/nt/ufmt"
)

// Left Shift (Lsh) Parameters
type int256LshParams struct {
	x      string
	n      uint
	result *i256.Int
}

func (p *int256LshParams) IsValid() bool {
	// Check if the shift would cause overflow in uint256
	// For safety, limit shift to 255 bits max
	if p.n > 255 {
		return false
	}

	x := i256.MustFromDecimal(p.x)
	abs := x.Abs()

	// If x is 0, shift is always valid
	if abs.IsZero() {
		return true
	}

	// Check if shift would overflow by checking bit length
	bitLen := abs.BitLen()
	if bitLen+int(p.n) > 256 {
		return false
	}

	return true
}

func (p *int256LshParams) AddResult(result *i256.Int) {
	p.result = result
}

func (p *int256LshParams) ToString() string {
	resultStr := "-"
	if p.result != nil {
		resultStr = p.result.ToString()
	}

	return ufmt.Sprintf("x: %s, n: %d, result: %s", p.x, p.n, resultStr)
}

func NewValidInt256LshParams(t *fuzz.T) *int256LshParams {
	// Use small values to avoid overflow when shifting
	x := fuzz.Int64Range(-1<<20, 1<<20).Draw(t, "x").(int64)
	// Use small shift values to avoid extreme results
	n := fuzz.Uint64Range(0, 32).Draw(t, "n").(uint64)

	return &int256LshParams{
		x: i256.NewInt(x).ToString(),
		n: uint(n),
	}
}

func NewRandomizedInt256LshParams(t *fuzz.T) *int256LshParams {
	// Use int64 range to avoid issues with full int256 generator
	x := fuzz.Int64().Draw(t, "x").(int64)
	// Use smaller shift values for randomized testing
	n := fuzz.Uint64Range(0, 64).Draw(t, "n").(uint64)

	return &int256LshParams{
		x: i256.NewInt(x).ToString(),
		n: uint(n),
	}
}

// Right Shift (Rsh) Parameters
type int256RshParams struct {
	x      string
	n      uint
	result *i256.Int
}

func (p *int256RshParams) IsValid() bool {
	// Rsh is always valid
	return true
}

func (p *int256RshParams) AddResult(result *i256.Int) {
	p.result = result
}

func (p *int256RshParams) ToString() string {
	resultStr := "-"
	if p.result != nil {
		resultStr = p.result.ToString()
	}

	return ufmt.Sprintf("x: %s, n: %d, result: %s", p.x, p.n, resultStr)
}

func NewValidInt256RshParams(t *fuzz.T) *int256RshParams {
	// Use int64 range to avoid issues with full int256 generator
	x := fuzz.Int64().Draw(t, "x").(int64)
	// Use small shift values
	n := fuzz.Uint64Range(0, 64).Draw(t, "n").(uint64)

	return &int256RshParams{
		x: i256.NewInt(x).ToString(),
		n: uint(n),
	}
}

func NewRandomizedInt256RshParams(t *fuzz.T) *int256RshParams {
	// Use int64 range to avoid issues with full int256 generator
	x := fuzz.Int64().Draw(t, "x").(int64)
	// Allow larger shift values for randomized testing
	n := fuzz.Uint64Range(0, 128).Draw(t, "n").(uint64)

	return &int256RshParams{
		x: i256.NewInt(x).ToString(),
		n: uint(n),
	}
}

// And Parameters
type int256AndParams struct {
	x string
	y string
}

func (p *int256AndParams) IsValid() bool {
	// And is always valid
	return true
}

func (p *int256AndParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidInt256AndParams(t *fuzz.T) *int256AndParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256AndParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedInt256AndParams(t *fuzz.T) *int256AndParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256AndParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Or Parameters
type int256OrParams struct {
	x string
	y string
}

func (p *int256OrParams) IsValid() bool {
	// Or is always valid
	return true
}

func (p *int256OrParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s", p.x, p.y)
}

func NewValidInt256OrParams(t *fuzz.T) *int256OrParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256OrParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

func NewRandomizedInt256OrParams(t *fuzz.T) *int256OrParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)

	return &int256OrParams{
		x: x.ToString(),
		y: y.ToString(),
	}
}

// Shift Combined Parameters (for testing Lsh/Rsh together)
type int256ShiftParams struct {
	x string
	n uint
}

func (p *int256ShiftParams) IsValid() bool {
	return true
}

func (p *int256ShiftParams) ToString() string {
	return ufmt.Sprintf("x: %s, n: %d", p.x, p.n)
}

func NewValidInt256ShiftParams(t *fuzz.T) *int256ShiftParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	// Use small shift values for round-trip testing
	n := fuzz.Uint64Range(0, 32).Draw(t, "n").(uint64)

	return &int256ShiftParams{
		x: x.ToString(),
		n: uint(n),
	}
}

func NewRandomizedInt256ShiftParams(t *fuzz.T) *int256ShiftParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	n := fuzz.Uint64Range(0, 128).Draw(t, "n").(uint64)

	return &int256ShiftParams{
		x: x.ToString(),
		n: uint(n),
	}
}

// Sparse Pattern Parameters (for testing edge cases in bitwise operations)
type int256BitwiseSparseParams struct {
	patternType int
}

func (p *int256BitwiseSparseParams) IsValid() bool {
	return true
}

func (p *int256BitwiseSparseParams) ToString() string {
	return ufmt.Sprintf("patternType: %d", p.patternType)
}

func NewValidInt256BitwiseSparseParams(t *fuzz.T) *int256BitwiseSparseParams {
	patternType := fuzz.IntRange(0, 7).Draw(t, "patternType").(int)

	return &int256BitwiseSparseParams{
		patternType: patternType,
	}
}

func NewRandomizedInt256BitwiseSparseParams(t *fuzz.T) *int256BitwiseSparseParams {
	patternType := fuzz.IntRange(0, 7).Draw(t, "patternType").(int)

	return &int256BitwiseSparseParams{
		patternType: patternType,
	}
}

// Helper function to get Int from pattern type
func (p *int256BitwiseSparseParams) GetValue() *i256.Int {
	switch p.patternType {
	case 0:
		// Zero
		return i256.Zero()
	case 1:
		// One
		return i256.One()
	case 2:
		// Negative one
		return i256.NewInt(-1)
	case 3:
		// MaxInt256
		return i256.MaxInt256()
	case 4:
		// MinInt256
		return i256.MinInt256()
	case 5:
		// Small positive
		return i256.NewInt(0x7FFFFFFF)
	case 6:
		// Small negative
		return i256.NewInt(-0x7FFFFFFF)
	case 7:
		// Alternating bits pattern (positive)
		return i256.MustFromDecimal("6148914691236517205") // 0x5555555555555555
	default:
		return i256.Zero()
	}
}

// Combined Bitwise Operation Parameters
type int256BitwiseOpParams struct {
	x         string
	y         string
	operation string // "and", "or"
}

func (p *int256BitwiseOpParams) IsValid() bool {
	return p.operation == "and" || p.operation == "or"
}

func (p *int256BitwiseOpParams) ToString() string {
	return ufmt.Sprintf("x: %s, y: %s, op: %s", p.x, p.y, p.operation)
}

func NewValidInt256BitwiseOpParams(t *fuzz.T) *int256BitwiseOpParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)
	opChoice := fuzz.IntRange(0, 1).Draw(t, "op").(int)

	op := "and"
	if opChoice == 1 {
		op = "or"
	}

	return &int256BitwiseOpParams{
		x:         x.ToString(),
		y:         y.ToString(),
		operation: op,
	}
}

func NewRandomizedInt256BitwiseOpParams(t *fuzz.T) *int256BitwiseOpParams {
	x := fuzz.Int256().Draw(t, "x").(*i256.Int)
	y := fuzz.Int256().Draw(t, "y").(*i256.Int)
	opChoice := fuzz.IntRange(0, 1).Draw(t, "op").(int)

	op := "and"
	if opChoice == 1 {
		op = "or"
	}

	return &int256BitwiseOpParams{
		x:         x.ToString(),
		y:         y.ToString(),
		operation: op,
	}
}
