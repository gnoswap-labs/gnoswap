package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	u256 "gno.land/p/gnoswap/uint256"
)

// MulDiv Tests
// TestFuzzUint256MulDiv_ValidParams_Stateless tests MulDiv with valid parameters
func TestFuzzUint256MulDiv_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidMulDivParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then - should not panic since IsValid ensures valid params
		a := u256.MustFromDecimal(params.a)
		b := u256.MustFromDecimal(params.b)
		d := u256.MustFromDecimal(params.denominator)

		// Verify IsValid prediction: should not panic
		u256.MulDiv(a, b, d)
	})
}

// TestFuzzUint256MulDiv_RandomizedParams_Stateless tests MulDiv with randomized parameters
func TestFuzzUint256MulDiv_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedMulDivParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		b := u256.MustFromDecimal(params.b)
		d := u256.MustFromDecimal(params.denominator)

		u256.MulDiv(a, b, d)
	})
}

// TestFuzzUint256MulDiv_Identity tests MulDiv(a, d, d) == a
func TestFuzzUint256MulDiv_Identity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - use non-zero value for d
		a := fuzz.Uint64Range(0, 1<<32-1).Draw(ft, "a").(uint64)
		d := fuzz.Uint64Range(1, 1<<32-1).Draw(ft, "d").(uint64)

		aU := u256.NewUint(a)
		dU := u256.NewUint(d)

		params := &mulDivParams{
			a:           aU.ToString(),
			b:           dU.ToString(),
			denominator: dU.ToString(),
		}

		// when
		fuzzResult.AddParams(index, params)

		// then: MulDiv(a, d, d) should equal a
		result := u256.MulDiv(aU, dU, dU)
		if !result.Eq(aU) {
			panic("MulDiv(a, d, d) != a")
		}
	})
}

// TestFuzzUint256MulDiv_ZeroNumerator tests MulDiv(0, b, d) == 0
func TestFuzzUint256MulDiv_ZeroNumerator(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		b := fuzz.Uint64Range(1, 1<<32-1).Draw(ft, "b").(uint64)
		d := fuzz.Uint64Range(1, 1<<32-1).Draw(ft, "d").(uint64)

		zero := u256.Zero()
		bU := u256.NewUint(b)
		dU := u256.NewUint(d)

		params := &mulDivParams{
			a:           zero.ToString(),
			b:           bU.ToString(),
			denominator: dU.ToString(),
		}

		// when
		fuzzResult.AddParams(index, params)

		// then: MulDiv(0, b, d) should equal 0
		result := u256.MulDiv(zero, bU, dU)
		if !result.IsZero() {
			panic("MulDiv(0, b, d) != 0")
		}
	})
}

// MulDivRoundingUp Tests
// TestFuzzUint256MulDivRoundingUp_ValidParams_Stateless tests MulDivRoundingUp with valid parameters
func TestFuzzUint256MulDivRoundingUp_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidMulDivRoundingUpParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then - should not panic since IsValid ensures valid params
		a := u256.MustFromDecimal(params.a)
		b := u256.MustFromDecimal(params.b)
		d := u256.MustFromDecimal(params.denominator)

		// Verify IsValid prediction: should not panic
		u256.MulDivRoundingUp(a, b, d)
	})
}

// TestFuzzUint256MulDivRoundingUp_RandomizedParams_Stateless tests MulDivRoundingUp with randomized parameters
func TestFuzzUint256MulDivRoundingUp_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedMulDivRoundingUpParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		b := u256.MustFromDecimal(params.b)
		d := u256.MustFromDecimal(params.denominator)

		u256.MulDivRoundingUp(a, b, d)
	})
}

// TestFuzzUint256MulDivRoundingUp_GreaterOrEqualMulDiv tests MulDivRoundingUp >= MulDiv
func TestFuzzUint256MulDivRoundingUp_GreaterOrEqualMulDiv(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidMulDivRoundingUpParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		b := u256.MustFromDecimal(params.b)
		d := u256.MustFromDecimal(params.denominator)

		floor := u256.MulDiv(a, b, d)
		ceil := u256.MulDivRoundingUp(a, b, d)

		if ceil.Lt(floor) {
			panic("MulDivRoundingUp < MulDiv")
		}

		// Difference should be at most 1
		diff := new(u256.Uint).Sub(ceil, floor)
		if diff.Gt(u256.NewUint(1)) {
			panic("MulDivRoundingUp - MulDiv > 1")
		}
	})
}

// TestFuzzUint256MulDivRoundingUp_ExactDivision tests that when there's no remainder, ceil == floor
func TestFuzzUint256MulDivRoundingUp_ExactDivision(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - create values where a*b is divisible by d
		a := fuzz.Uint64Range(1, 1<<16).Draw(ft, "a").(uint64)
		d := fuzz.Uint64Range(1, 1<<16).Draw(ft, "d").(uint64)

		aU := u256.NewUint(a)
		dU := u256.NewUint(d)

		params := &mulDivRoundingUpParams{
			a:           aU.ToString(),
			b:           dU.ToString(),
			denominator: dU.ToString(),
		}

		// when
		fuzzResult.AddParams(index, params)

		// then: MulDivRoundingUp(a, d, d) == MulDiv(a, d, d) == a
		floor := u256.MulDiv(aU, dU, dU)
		ceil := u256.MulDivRoundingUp(aU, dU, dU)

		if !floor.Eq(ceil) {
			panic("MulDivRoundingUp != MulDiv for exact division")
		}
	})
}

// DivRoundingUp Tests

// TestFuzzUint256DivRoundingUp_ValidParams_Stateless tests DivRoundingUp with valid parameters
func TestFuzzUint256DivRoundingUp_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidDivRoundingUpParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then - should not panic since IsValid ensures non-zero denominator
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		// Verify IsValid prediction: should not panic
		u256.DivRoundingUp(x, y)
	})
}

// TestFuzzUint256DivRoundingUp_RandomizedParams_Stateless tests DivRoundingUp with randomized parameters
func TestFuzzUint256DivRoundingUp_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedDivRoundingUpParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		u256.DivRoundingUp(x, y)
	})
}

// TestFuzzUint256DivRoundingUp_GreaterOrEqualDiv tests DivRoundingUp >= Div
func TestFuzzUint256DivRoundingUp_GreaterOrEqualDiv(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidDivRoundingUpParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		floor := new(u256.Uint).Div(x, y)
		ceil := u256.DivRoundingUp(x, y)

		if ceil.Lt(floor) {
			panic("DivRoundingUp < Div")
		}

		// Difference should be at most 1
		diff := new(u256.Uint).Sub(ceil, floor)
		if diff.Gt(u256.NewUint(1)) {
			panic("DivRoundingUp - Div > 1")
		}
	})
}

// TestFuzzUint256DivRoundingUp_ExactDivision tests that when there's no remainder, ceil == floor
func TestFuzzUint256DivRoundingUp_ExactDivision(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - create x that is divisible by y
		y := fuzz.Uint64Range(1, 1<<16).Draw(ft, "y").(uint64)
		multiplier := fuzz.Uint64Range(1, 1<<16).Draw(ft, "multiplier").(uint64)

		yU := u256.NewUint(y)
		xU := new(u256.Uint).Mul(u256.NewUint(multiplier), yU)

		params := &divRoundingUpParams{
			x: xU.ToString(),
			y: yU.ToString(),
		}

		// when
		fuzzResult.AddParams(index, params)

		// then
		floor := new(u256.Uint).Div(xU, yU)
		ceil := u256.DivRoundingUp(xU, yU)

		if !floor.Eq(ceil) {
			panic("DivRoundingUp != Div for exact division")
		}
	})
}

// TestFuzzUint256DivRoundingUp_WithRemainder tests that when there's a remainder, ceil == floor + 1
func TestFuzzUint256DivRoundingUp_WithRemainder(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - create x that is not divisible by y
		y := fuzz.Uint64Range(2, 1<<16).Draw(ft, "y").(uint64)
		multiplier := fuzz.Uint64Range(1, 1<<16).Draw(ft, "multiplier").(uint64)
		remainder := fuzz.Uint64Range(1, y-1).Draw(ft, "remainder").(uint64)

		yU := u256.NewUint(y)
		xU := new(u256.Uint).Mul(u256.NewUint(multiplier), yU)
		xU = new(u256.Uint).Add(xU, u256.NewUint(remainder))

		params := &divRoundingUpParams{
			x: xU.ToString(),
			y: yU.ToString(),
		}

		// when
		fuzzResult.AddParams(index, params)

		// then
		floor := new(u256.Uint).Div(xU, yU)
		ceil := u256.DivRoundingUp(xU, yU)
		expected := new(u256.Uint).Add(floor, u256.NewUint(1))

		if !ceil.Eq(expected) {
			panic("DivRoundingUp != Div + 1 for division with remainder")
		}
	})
}
