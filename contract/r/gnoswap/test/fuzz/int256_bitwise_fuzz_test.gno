package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	i256 "gno.land/p/gnoswap/int256"
)

// Left Shift (Lsh) Tests

// TestFuzzInt256Lsh_ValidParams_Stateless tests Lsh with valid parameters
func TestFuzzInt256Lsh_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256LshParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := new(i256.Int)
		z.Lsh(x, params.n)
		params.AddResult(z)
	})
}

// TestFuzzInt256Lsh_RandomizedParams_Stateless tests Lsh with randomized parameters
func TestFuzzInt256Lsh_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256LshParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := new(i256.Int)
		z.Lsh(x, params.n)
		params.AddResult(z)
	})
}

// TestFuzzInt256Lsh_ZeroShift tests Lsh with shift by 0 returns same value
func TestFuzzInt256Lsh_ZeroShift(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256LshParams(ft)
		params.n = 0

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := new(i256.Int)
		z.Lsh(x, 0)
		params.AddResult(z)

		if !z.Eq(x) {
			panic("Lsh by 0 should return same value")
		}
	})
}

// TestFuzzInt256Lsh_SignPreservation tests Lsh preserves sign
func TestFuzzInt256Lsh_SignPreservation(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256LshParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		// Skip zero (has no sign)
		if x.IsZero() {
			return
		}

		z := new(i256.Int)
		z.Lsh(x, params.n)
		params.AddResult(z)

		// If result is not zero, sign should be preserved
		if !z.IsZero() {
			if x.IsNeg() != z.IsNeg() {
				panic("Lsh changed sign of non-zero result")
			}
		}
	})
}

// Right Shift (Rsh) Tests

// TestFuzzInt256Rsh_ValidParams_Stateless tests Rsh with valid parameters
func TestFuzzInt256Rsh_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256RshParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := new(i256.Int)
		z.Rsh(x, params.n)

		params.AddResult(z)
	})
}

// TestFuzzInt256Rsh_RandomizedParams_Stateless tests Rsh with randomized parameters
func TestFuzzInt256Rsh_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256RshParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := new(i256.Int)
		z.Rsh(x, params.n)

		params.AddResult(z)
	})
}

// TestFuzzInt256Rsh_ZeroShift tests Rsh with shift by 0 returns same value
func TestFuzzInt256Rsh_ZeroShift(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256RshParams(ft)
		params.n = 0

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := new(i256.Int)
		z.Rsh(x, 0)

		if !z.Eq(x) {
			panic("Rsh by 0 should return same value")
		}
	})
}

// TestFuzzInt256Rsh_ArithmeticShift tests Rsh performs arithmetic right shift (sign extension)
func TestFuzzInt256Rsh_ArithmeticShift(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256RshParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		z := new(i256.Int)
		z.Rsh(x, params.n)

		params.AddResult(z)

		// For negative numbers, result should remain negative (or be -1 for large shifts)
		if x.IsNeg() && !z.IsNeg() && !z.IsZero() {
			panic("Arithmetic right shift of negative number should preserve negativity")
		}
	})
}

// And Tests

// TestFuzzInt256And_ValidParams_Stateless tests And with valid parameters
func TestFuzzInt256And_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AndParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.And(x, y)
	})
}

// TestFuzzInt256And_RandomizedParams_Stateless tests And with randomized parameters
func TestFuzzInt256And_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256AndParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.And(x, y)
	})
}

// TestFuzzInt256And_Commutativity tests And commutativity: x & y == y & x
func TestFuzzInt256And_Commutativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AndParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		xy := new(i256.Int).And(x, y)
		yx := new(i256.Int).And(y, x)

		if !xy.Eq(yx) {
			panic("And commutativity failed: x & y != y & x")
		}
	})
}

// TestFuzzInt256And_Idempotence tests And idempotence: x & x == x
func TestFuzzInt256And_Idempotence(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AndParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		xx := new(i256.Int).And(x, x)

		if !xx.Eq(x) {
			panic("And idempotence failed: x & x != x")
		}
	})
}

// Or Tests

// TestFuzzInt256Or_ValidParams_Stateless tests Or with valid parameters
func TestFuzzInt256Or_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256OrParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.Or(x, y)
	})
}

// TestFuzzInt256Or_RandomizedParams_Stateless tests Or with randomized parameters
func TestFuzzInt256Or_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256OrParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		z := new(i256.Int)
		z.Or(x, y)
	})
}

// TestFuzzInt256Or_Commutativity tests Or commutativity: x | y == y | x
func TestFuzzInt256Or_Commutativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256OrParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		xy := new(i256.Int).Or(x, y)
		yx := new(i256.Int).Or(y, x)

		if !xy.Eq(yx) {
			panic("Or commutativity failed: x | y != y | x")
		}
	})
}

// TestFuzzInt256Or_Idempotence tests Or idempotence: x | x == x
func TestFuzzInt256Or_Idempotence(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256OrParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		xx := new(i256.Int).Or(x, x)

		if !xx.Eq(x) {
			panic("Or idempotence failed: x | x != x")
		}
	})
}

// Bitwise Identity Tests

// TestFuzzInt256Bitwise_AndZero tests x & 0 == 0
func TestFuzzInt256Bitwise_AndZero(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AndParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		zero := i256.Zero()

		result := new(i256.Int).And(x, zero)

		if !result.IsZero() {
			panic("x & 0 should equal 0")
		}
	})
}

// TestFuzzInt256Bitwise_OrZero tests x | 0 == x
func TestFuzzInt256Bitwise_OrZero(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256OrParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		zero := i256.Zero()

		result := new(i256.Int).Or(x, zero)

		if !result.Eq(x) {
			panic("x | 0 should equal x")
		}
	})
}

// TestFuzzInt256Bitwise_Absorption tests absorption law: x & (x | y) == x
func TestFuzzInt256Bitwise_Absorption(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256AndParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		// x & (x | y) == x
		xOrY := new(i256.Int).Or(x, y)
		result := new(i256.Int).And(x, xOrY)

		if !result.Eq(x) {
			panic("Absorption law failed: x & (x | y) != x")
		}
	})
}

// Shift Relationship Tests

// TestFuzzInt256Shift_LshMultiplication tests Lsh by 1 is multiplication by 2 for small positive values
func TestFuzzInt256Shift_LshMultiplication(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - use small values to avoid overflow
		x := fuzz.Int64Range(0, 1<<62).Draw(ft, "x").(int64)
		params := &int256ShiftParams{
			x: i256.NewInt(x).ToString(),
			n: 1,
		}

		// when
		fuzzResult.AddParams(index, params)

		// then
		val := i256.NewInt(x)

		shifted := new(i256.Int).Lsh(val, 1)
		multiplied := new(i256.Int).Mul(val, i256.NewInt(2))

		if !shifted.Eq(multiplied) {
			panic("Lsh by 1 should equal multiplication by 2")
		}
	})
}

// TestFuzzInt256Shift_RshDivision tests Rsh by 1 is division by 2 for positive values
func TestFuzzInt256Shift_RshDivision(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - use positive values
		x := fuzz.Int64Range(0, 1<<62).Draw(ft, "x").(int64)
		params := &int256ShiftParams{
			x: i256.NewInt(x).ToString(),
			n: 1,
		}

		// when
		fuzzResult.AddParams(index, params)

		// then
		val := i256.NewInt(x)

		shifted := new(i256.Int).Rsh(val, 1)
		divided := new(i256.Int).Div(val, i256.NewInt(2))

		if !shifted.Eq(divided) {
			panic("Rsh by 1 should equal division by 2 for positive values")
		}
	})
}

// TestFuzzInt256Shift_LargeRsh tests behavior with large right shift values
func TestFuzzInt256Shift_LargeRsh(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256ShiftParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)

		// Large right shift should be handled without panic
		// Right shift by large amount should give 0 for positive, -1 for negative
		z := new(i256.Int)
		z.Rsh(x, 200)

		// If shift is very large, result approaches 0 or -1
		// Just verify no panic
	})
}

// Sparse Pattern Tests

// TestFuzzInt256Bitwise_SparsePatterns tests bitwise operations with sparse patterns
func TestFuzzInt256Bitwise_SparsePatterns(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params1 := NewValidInt256BitwiseSparseParams(ft)
		params2 := NewValidInt256BitwiseSparseParams(ft)

		// when
		fuzzResult.AddParams(index, params1)

		// then
		x := params1.GetValue()
		y := params2.GetValue()

		// Test And
		andResult := new(i256.Int).And(x, y)
		_ = andResult

		// Test Or
		orResult := new(i256.Int).Or(x, y)
		_ = orResult

		// Test Rsh (Rsh is always safe, Lsh can overflow for boundary values)
		rshResult := new(i256.Int).Rsh(x, 1)
		_ = rshResult

		// Test Lsh only for safe values (not MinInt256 or near-max values)
		// Skip Lsh for extreme values that could overflow
		// patternType 4 is MinInt256 which causes Abs() overflow
		if params1.patternType == 4 || params1.patternType == 3 {
			// Skip MinInt256 and MaxInt256 for Lsh tests
			return
		}

		// Safe to call Abs() now
		abs := x.Abs()
		bitLen := abs.BitLen()
		if bitLen < 255 && !abs.IsZero() {
			lshResult := new(i256.Int).Lsh(x, 1)
			_ = lshResult
		}
	})
}

// Combined Operation Tests

// TestFuzzInt256Bitwise_AndOrDistributive tests distributive law: x & (y | z) == (x & y) | (x & z)
func TestFuzzInt256Bitwise_AndOrDistributive(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.a)
		y := i256.MustFromDecimal(params.b)
		z := i256.MustFromDecimal(params.c)

		// x & (y | z)
		yOrZ := new(i256.Int).Or(y, z)
		left := new(i256.Int).And(x, yOrZ)

		// (x & y) | (x & z)
		xAndY := new(i256.Int).And(x, y)
		xAndZ := new(i256.Int).And(x, z)
		right := new(i256.Int).Or(xAndY, xAndZ)

		if !left.Eq(right) {
			panic("Distributive law failed: x & (y | z) != (x & y) | (x & z)")
		}
	})
}

// TestFuzzInt256Bitwise_OrAndDistributive tests distributive law: x | (y & z) == (x | y) & (x | z)
func TestFuzzInt256Bitwise_OrAndDistributive(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.a)
		y := i256.MustFromDecimal(params.b)
		z := i256.MustFromDecimal(params.c)

		// x | (y & z)
		yAndZ := new(i256.Int).And(y, z)
		left := new(i256.Int).Or(x, yAndZ)

		// (x | y) & (x | z)
		xOrY := new(i256.Int).Or(x, y)
		xOrZ := new(i256.Int).Or(x, z)
		right := new(i256.Int).And(xOrY, xOrZ)

		if !left.Eq(right) {
			panic("Distributive law failed: x | (y & z) != (x | y) & (x | z)")
		}
	})
}

// TestFuzzInt256Bitwise_Associativity tests associativity of And and Or
func TestFuzzInt256Bitwise_Associativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.a)
		y := i256.MustFromDecimal(params.b)
		z := i256.MustFromDecimal(params.c)

		// Test And associativity: (x & y) & z == x & (y & z)
		xy := new(i256.Int).And(x, y)
		leftAnd := new(i256.Int).And(xy, z)

		yz := new(i256.Int).And(y, z)
		rightAnd := new(i256.Int).And(x, yz)

		if !leftAnd.Eq(rightAnd) {
			panic("And associativity failed: (x & y) & z != x & (y & z)")
		}

		// Test Or associativity: (x | y) | z == x | (y | z)
		xyOr := new(i256.Int).Or(x, y)
		leftOr := new(i256.Int).Or(xyOr, z)

		yzOr := new(i256.Int).Or(y, z)
		rightOr := new(i256.Int).Or(x, yzOr)

		if !leftOr.Eq(rightOr) {
			panic("Or associativity failed: (x | y) | z != x | (y | z)")
		}
	})
}
