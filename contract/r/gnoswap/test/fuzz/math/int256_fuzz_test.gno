package math

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	i256 "gno.land/p/gnoswap/int256"
)

// TestFuzzInt256Add_ValidParams_Stateless tests Add with valid parameters
func TestFuzzInt256Add_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.Add(x, y)
		params.AddResult(z)
	})
}

// TestFuzzInt256Add_RandomizedParams_Stateless tests Add with randomized parameters
func TestFuzzInt256Add_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256AddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.Add(x, y)
		params.AddResult(z)
	})
}

// TestFuzzInt256AddOverflow_ValidParams_Stateless tests AddOverflow with valid (non-overflowing) parameters
func TestFuzzInt256AddOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AddOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		_, overflow := z.AddOverflow(x, y)
		params.AddResult(z, overflow)

		// Verify IsValid prediction matches actual result
		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256AddOverflow_RandomizedParams_Stateless tests AddOverflow with randomized parameters
func TestFuzzInt256AddOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256AddOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		result, overflow := z.AddOverflow(x, y)
		params.AddResult(result, overflow)

		if overflow {
			panic("overflow occurred: " + params.ToString())
		}
	})
}

// TestFuzzInt256Sub_ValidParams_Stateless tests Sub with valid parameters
func TestFuzzInt256Sub_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256SubParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.Sub(x, y)
	})
}

// TestFuzzInt256Sub_RandomizedParams_Stateless tests Sub with randomized parameters
func TestFuzzInt256Sub_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256SubParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.Sub(x, y)
	})
}

// TestFuzzInt256SubOverflow_ValidParams_Stateless tests SubOverflow with valid (non-overflowing) parameters
func TestFuzzInt256SubOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256SubOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		_, overflow := z.SubOverflow(x, y)

		// Verify IsValid prediction matches actual result
		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256SubOverflow_RandomizedParams_Stateless tests SubOverflow with randomized parameters
func TestFuzzInt256SubOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256SubOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		_, overflow := z.SubOverflow(x, y)

		if overflow {
			panic("overflow occurred: " + params.ToString())
		}
	})
}

// TestFuzzInt256Mul_ValidParams_Stateless tests Mul with valid parameters
func TestFuzzInt256Mul_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256MulParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.Mul(x, y)
	})
}

// TestFuzzInt256Mul_RandomizedParams_Stateless tests Mul with randomized parameters
func TestFuzzInt256Mul_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256MulParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.Mul(x, y)
	})
}

// TestFuzzInt256MulOverflow_ValidParams_Stateless tests MulOverflow with valid (non-overflowing) parameters
func TestFuzzInt256MulOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256MulOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		_, overflow := z.MulOverflow(x, y)

		// Verify IsValid prediction matches actual result
		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256MulOverflow_RandomizedParams_Stateless tests MulOverflow with randomized parameters
func TestFuzzInt256MulOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256MulOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		_, overflow := z.MulOverflow(x, y)

		if overflow {
			panic("overflow occurred: " + params.ToString())
		}
	})
}

// TestFuzzInt256Div_ValidParams_Stateless tests Div with valid parameters
func TestFuzzInt256Div_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256DivParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.Div(x, y)
	})
}

// TestFuzzInt256Div_RandomizedParams_Stateless tests Div with randomized parameters
func TestFuzzInt256Div_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256DivParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		// Skip if y is zero (would panic)
		if y.IsZero() {
			return
		}

		z := new(i256.Int)
		z.Div(x, y)
	})
}

// TestFuzzInt256Neg_RandomizedParams_Stateless tests Neg with randomized parameters
func TestFuzzInt256Neg_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256NegParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := new(i256.Int)
		z.Neg(x)
	})
}

// TestFuzzInt256Abs_ValidParams_Stateless tests Abs with valid parameters
func TestFuzzInt256Abs_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AbsParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		abs := x.Abs()

		// Verify abs is non-negative (as uint256)
		if abs == nil {
			panic("Abs returned nil")
		}
	})
}

// TestFuzzInt256Abs_RandomizedParams_Stateless tests Abs with randomized parameters
func TestFuzzInt256Abs_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256AbsParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		abs := x.Abs()

		// Verify abs is non-negative (as uint256)
		if abs == nil {
			panic("Abs returned nil")
		}
	})
}
