package math

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestFuzzUint256Mul_ValidParams_Stateless tests Mul with valid parameters
func TestFuzzUint256Mul_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidMulParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		z.Mul(x, y)
	})
}

// TestFuzzUint256Mul_RandomizedParams_Stateless tests Mul with randomized parameters
func TestFuzzUint256Mul_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedMulParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		z.Mul(x, y)
	})
}

// TestFuzzUint256MulOverflow_ValidParams_Stateless tests MulOverflow with valid (non-overflowing) parameters
func TestFuzzUint256MulOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidMulOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		_, overflow := z.MulOverflow(x, y)

		// Verify IsValid prediction matches actual result
		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzUint256MulOverflow_RandomizedParams_Stateless tests MulOverflow with randomized parameters
func TestFuzzUint256MulOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedMulOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		_, overflow := z.MulOverflow(x, y)

		// If overflow occurs, panic (IsValid() predicts this)
		if overflow {
			panic("overflow occurred: " + params.ToString())
		}
	})
}

// TestFuzzUint256Div_ValidParams_Stateless tests Div with valid parameters
func TestFuzzUint256Div_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidDivParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		z.Div(x, y)
	})
}

// TestFuzzUint256Div_RandomizedParams_Stateless tests Div with randomized parameters
func TestFuzzUint256Div_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedDivParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		z.Div(x, y)
	})
}

// TestFuzzUint256Mod_ValidParams_Stateless tests Mod with valid parameters
func TestFuzzUint256Mod_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidModParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		z.Mod(x, y)
	})
}

// TestFuzzUint256Mod_RandomizedParams_Stateless tests Mod with randomized parameters
func TestFuzzUint256Mod_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedModParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		z.Mod(x, y)
	})
}

// TestFuzzUint256DivMod_ValidParams_Stateless tests DivMod with valid parameters
func TestFuzzUint256DivMod_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidDivModParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var q, m u256.Uint
		q.DivMod(x, y, &m)
	})
}

// TestFuzzUint256DivMod_RandomizedParams_Stateless tests DivMod with randomized parameters
func TestFuzzUint256DivMod_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedDivModParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var q, m u256.Uint
		q.DivMod(x, y, &m)
	})
}

// TestFuzzUint256Add_ValidParams_Stateless tests Add with valid parameters
func TestFuzzUint256Add_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidAddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		z.Add(x, y)
	})
}

// TestFuzzUint256Add_RandomizedParams_Stateless tests Add with randomized parameters
func TestFuzzUint256Add_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedAddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		z.Add(x, y)
	})
}

// TestFuzzUint256AddOverflow_ValidParams_Stateless tests AddOverflow with valid (non-overflowing) parameters
func TestFuzzUint256AddOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidAddOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		_, overflow := z.AddOverflow(x, y)

		// Verify IsValid prediction matches actual result
		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzUint256AddOverflow_RandomizedParams_Stateless tests AddOverflow with randomized parameters
func TestFuzzUint256AddOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedAddOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		_, overflow := z.AddOverflow(x, y)

		if overflow {
			panic("expected overflow" + params.ToString())
		}
	})
}

// TestFuzzUint256Sub_ValidParams_Stateless tests Sub with valid parameters
func TestFuzzUint256Sub_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidSubParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		z.Sub(x, y)
	})
}

// TestFuzzUint256Sub_RandomizedParams_Stateless tests Sub with randomized parameters
func TestFuzzUint256Sub_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedSubParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		z.Sub(x, y)
	})
}

// TestFuzzUint256SubOverflow_ValidParams_Stateless tests SubOverflow with valid (non-underflowing) parameters
func TestFuzzUint256SubOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidSubOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		_, underflow := z.SubOverflow(x, y)

		// Verify IsValid prediction matches actual result
		if underflow {
			panic("IsValid returned true but underflow occurred")
		}
	})
}

// TestFuzzUint256SubOverflow_RandomizedParams_Stateless tests SubOverflow with randomized parameters
func TestFuzzUint256SubOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedSubOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := u256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		var z u256.Uint
		_, underflow := z.SubOverflow(x, y)

		if underflow {
			panic("expected underflow" + params.ToString())
		}
	})
}
