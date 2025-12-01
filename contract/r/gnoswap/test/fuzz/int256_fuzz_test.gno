package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestFuzzInt256Add_ValidParams_Stateless tests Add with valid parameters
func TestFuzzInt256Add_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Add(x, y)
	})
}

// TestFuzzInt256Add_RandomizedParams_Stateless tests Add with randomized parameters
func TestFuzzInt256Add_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256AddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Add(x, y)
	})
}

// TestFuzzInt256AddOverflow_ValidParams_Stateless tests AddOverflow with valid (non-overflowing) parameters
func TestFuzzInt256AddOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AddOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		_, overflow := z.AddOverflow(x, y)

		// Verify IsValid prediction matches actual result
		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256AddOverflow_RandomizedParams_Stateless tests AddOverflow with randomized parameters
func TestFuzzInt256AddOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256AddOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		_, overflow := z.AddOverflow(x, y)

		if overflow {
			panic("overflow occurred: " + params.ToString())
		}
	})
}

// TestFuzzInt256Sub_ValidParams_Stateless tests Sub with valid parameters
func TestFuzzInt256Sub_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256SubParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Sub(x, y)
	})
}

// TestFuzzInt256Sub_RandomizedParams_Stateless tests Sub with randomized parameters
func TestFuzzInt256Sub_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256SubParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Sub(x, y)
	})
}

// TestFuzzInt256SubOverflow_ValidParams_Stateless tests SubOverflow with valid (non-overflowing) parameters
func TestFuzzInt256SubOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256SubOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		_, overflow := z.SubOverflow(x, y)

		// Verify IsValid prediction matches actual result
		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256SubOverflow_RandomizedParams_Stateless tests SubOverflow with randomized parameters
func TestFuzzInt256SubOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256SubOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		_, overflow := z.SubOverflow(x, y)

		if overflow {
			panic("overflow occurred: " + params.ToString())
		}
	})
}

// TestFuzzInt256Mul_ValidParams_Stateless tests Mul with valid parameters
func TestFuzzInt256Mul_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256MulParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Mul(x, y)
	})
}

// TestFuzzInt256Mul_RandomizedParams_Stateless tests Mul with randomized parameters
func TestFuzzInt256Mul_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256MulParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Mul(x, y)
	})
}

// TestFuzzInt256MulOverflow_ValidParams_Stateless tests MulOverflow with valid (non-overflowing) parameters
func TestFuzzInt256MulOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256MulOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		_, overflow := z.MulOverflow(x, y)

		// Verify IsValid prediction matches actual result
		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256MulOverflow_RandomizedParams_Stateless tests MulOverflow with randomized parameters
func TestFuzzInt256MulOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256MulOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		_, overflow := z.MulOverflow(x, y)

		if overflow {
			panic("overflow occurred: " + params.ToString())
		}
	})
}

// TestFuzzInt256Div_ValidParams_Stateless tests Div with valid parameters
func TestFuzzInt256Div_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256DivParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Div(x, y)
	})
}

// TestFuzzInt256Div_RandomizedParams_Stateless tests Div with randomized parameters
func TestFuzzInt256Div_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
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

		z := i256.New()
		z.Div(x, y)
	})
}

// TestFuzzInt256Quo_ValidParams_Stateless tests Quo with valid parameters
func TestFuzzInt256Quo_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256QuoParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Quo(x, y)
	})
}

// TestFuzzInt256Quo_RandomizedParams_Stateless tests Quo with randomized parameters
func TestFuzzInt256Quo_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256QuoParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		// Skip if y is zero (would panic)
		if y.IsZero() {
			return
		}

		z := i256.New()
		z.Quo(x, y)
	})
}

// TestFuzzInt256Rem_ValidParams_Stateless tests Rem with valid parameters
func TestFuzzInt256Rem_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256RemParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Rem(x, y)
	})
}

// TestFuzzInt256Rem_RandomizedParams_Stateless tests Rem with randomized parameters
func TestFuzzInt256Rem_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256RemParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		// Skip if y is zero (would panic)
		if y.IsZero() {
			return
		}

		z := i256.New()
		z.Rem(x, y)
	})
}

// TestFuzzInt256Mod_ValidParams_Stateless tests Mod with valid parameters
func TestFuzzInt256Mod_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256ModParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Mod(x, y)
	})
}

// TestFuzzInt256Mod_RandomizedParams_Stateless tests Mod with randomized parameters
func TestFuzzInt256Mod_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256ModParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := i256.New()
		z.Mod(x, y)
	})
}

// TestFuzzInt256Neg_ValidParams_Stateless tests Neg with valid parameters
func TestFuzzInt256Neg_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256NegParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := i256.New()
		z.Neg(x)
	})
}

// TestFuzzInt256Neg_RandomizedParams_Stateless tests Neg with randomized parameters
func TestFuzzInt256Neg_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256NegParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := i256.New()
		z.Neg(x)
	})
}

// TestFuzzInt256NegOverflow_ValidParams_Stateless tests NegOverflow with valid (non-overflowing) parameters
func TestFuzzInt256NegOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256NegOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := i256.New()
		_, overflow := z.NegOverflow(x)

		// Verify IsValid prediction matches actual result
		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256NegOverflow_RandomizedParams_Stateless tests NegOverflow with randomized parameters
func TestFuzzInt256NegOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256NegOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := i256.New()
		_, overflow := z.NegOverflow(x)

		if overflow {
			panic("overflow occurred: " + params.ToString())
		}
	})
}

// TestFuzzInt256Abs_ValidParams_Stateless tests Abs with valid parameters
func TestFuzzInt256Abs_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
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
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
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

// TestFuzzInt256AbsOverflow_ValidParams_Stateless tests AbsOverflow with valid (non-overflowing) parameters
func TestFuzzInt256AbsOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AbsOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := i256.New()
		_, overflow := z.AbsOverflow(x)

		// Verify IsValid prediction matches actual result
		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256AbsOverflow_RandomizedParams_Stateless tests AbsOverflow with randomized parameters
func TestFuzzInt256AbsOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256AbsOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := i256.New()
		_, overflow := z.AbsOverflow(x)

		if overflow {
			panic("overflow occurred: " + params.ToString())
		}
	})
}

// TestFuzzInt256AddUint256_ValidParams_Stateless tests AddUint256 with valid parameters
func TestFuzzInt256AddUint256_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AddUint256Params(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		z := i256.New()
		z.AddUint256(x, y)
	})
}

// TestFuzzInt256AddUint256_RandomizedParams_Stateless tests AddUint256 with randomized parameters
func TestFuzzInt256AddUint256_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256AddUint256Params(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		z := i256.New()
		z.AddUint256(x, y)
	})
}

// TestFuzzInt256SubUint256_ValidParams_Stateless tests SubUint256 with valid parameters
func TestFuzzInt256SubUint256_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256SubUint256Params(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		z := i256.New()
		z.SubUint256(x, y)
	})
}

// TestFuzzInt256SubUint256_RandomizedParams_Stateless tests SubUint256 with randomized parameters
func TestFuzzInt256SubUint256_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256SubUint256Params(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		z := i256.New()
		z.SubUint256(x, y)
	})
}

// TestFuzzInt256MulUint256_ValidParams_Stateless tests MulUint256 with valid parameters
func TestFuzzInt256MulUint256_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256MulUint256Params(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		z := i256.New()
		z.MulUint256(x, y)
	})
}

// TestFuzzInt256MulUint256_RandomizedParams_Stateless tests MulUint256 with randomized parameters
func TestFuzzInt256MulUint256_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256MulUint256Params(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		z := i256.New()
		z.MulUint256(x, y)
	})
}

// TestFuzzInt256DivUint256_ValidParams_Stateless tests DivUint256 with valid parameters
func TestFuzzInt256DivUint256_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256DivUint256Params(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		z := i256.New()
		z.DivUint256(x, y)
	})
}

// TestFuzzInt256DivUint256_RandomizedParams_Stateless tests DivUint256 with randomized parameters
func TestFuzzInt256DivUint256_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256DivUint256Params(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := u256.MustFromDecimal(params.y)

		z := i256.New()
		z.DivUint256(x, y)
	})
}
