package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	i256 "gno.land/p/gnoswap/int256"
)

// TestFuzzInt256Add_ValidParams_Stateless tests Add with valid parameters
func TestFuzzInt256Add_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidIntAddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		z.Add(x, y)
	})
}

// TestFuzzInt256Add_RandomizedParams_Stateless tests Add with randomized parameters
func TestFuzzInt256Add_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIntAddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		z.Add(x, y)
	})
}

// TestFuzzInt256AddOverflow_ValidParams_Stateless tests AddOverflow with valid (non-overflowing) parameters
func TestFuzzInt256AddOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidIntAddOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		_, overflow := z.AddOverflow(x, y)

		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256AddOverflow_RandomizedParams_Stateless tests AddOverflow with randomized parameters
func TestFuzzInt256AddOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIntAddOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		_, overflow := z.AddOverflow(x, y)

		switch {
		case params.IsValid() && overflow:
			panic("IsValid returned true but overflow occurred")
		case !params.IsValid() && !overflow:
			panic("expected overflow" + params.ToString())
		case !params.IsValid() && overflow:
			// expected overflow: signal error so fuzz harness aligns with IsValid=false
			panic("overflow as expected " + params.ToString())
		}
	})
}

// TestFuzzInt256Sub_ValidParams_Stateless tests Sub with valid parameters
func TestFuzzInt256Sub_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidIntSubParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		z.Sub(x, y)
	})
}

// TestFuzzInt256Sub_RandomizedParams_Stateless tests Sub with randomized parameters
func TestFuzzInt256Sub_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIntSubParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		z.Sub(x, y)
	})
}

// TestFuzzInt256SubOverflow_ValidParams_Stateless tests SubOverflow with valid (non-overflowing) parameters
func TestFuzzInt256SubOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidIntSubOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		_, overflow := z.SubOverflow(x, y)

		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256SubOverflow_RandomizedParams_Stateless tests SubOverflow with randomized parameters
func TestFuzzInt256SubOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIntSubOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		_, overflow := z.SubOverflow(x, y)

		switch {
		case params.IsValid() && overflow:
			panic("IsValid returned true but overflow occurred")
		case !params.IsValid() && !overflow:
			panic("expected underflow" + params.ToString())
		case !params.IsValid() && overflow:
			// expected underflow: signal error so fuzz harness aligns with IsValid=false
			panic("underflow as expected " + params.ToString())
		}
	})
}

// TestFuzzInt256Mul_ValidParams_Stateless tests Mul with valid parameters
func TestFuzzInt256Mul_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidIntMulParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		z.Mul(x, y)
	})
}

// TestFuzzInt256Mul_RandomizedParams_Stateless tests Mul with randomized parameters
func TestFuzzInt256Mul_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIntMulParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		z.Mul(x, y)
	})
}

// TestFuzzInt256MulOverflow_ValidParams_Stateless tests MulOverflow with valid (non-overflowing) parameters
func TestFuzzInt256MulOverflow_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidIntMulOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		_, overflow := z.MulOverflow(x, y)

		if overflow {
			panic("IsValid returned true but overflow occurred")
		}
	})
}

// TestFuzzInt256MulOverflow_RandomizedParams_Stateless tests MulOverflow with randomized parameters
func TestFuzzInt256MulOverflow_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIntMulOverflowParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		_, overflow := z.MulOverflow(x, y)

		switch {
		case params.IsValid() && overflow:
			panic("IsValid returned true but overflow occurred")
		case !params.IsValid() && !overflow:
			panic("expected overflow" + params.ToString())
		case !params.IsValid() && overflow:
			// expected overflow: signal error so fuzz harness aligns with IsValid=false
			panic("overflow as expected " + params.ToString())
		}
	})
}

// TestFuzzInt256Div_ValidParams_Stateless tests Div with valid parameters
func TestFuzzInt256Div_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidIntDivParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		z.Div(x, y)
	})
}

// TestFuzzInt256Div_RandomizedParams_Stateless tests Div with randomized parameters
func TestFuzzInt256Div_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIntDivParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		var z i256.Int
		z.Div(x, y)
	})
}
