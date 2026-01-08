package math

import (
	"math/bits"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	u256 "gno.land/p/gnoswap/uint256"
)

// Arithmetic Identity Laws Tests
// TestFuzzUint256Arithmetic_AdditionAssociativity tests (a + b) + c == a + (b + c)
func TestFuzzUint256Arithmetic_AdditionAssociativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		b := u256.MustFromDecimal(params.b)
		c := u256.MustFromDecimal(params.c)

		// (a + b) + c
		ab, overflowAb := new(u256.Uint).AddOverflow(a, b)
		left, overflowLeft := new(u256.Uint).AddOverflow(ab, c)

		leftOverflowed := overflowAb || overflowLeft

		// a + (b + c)
		bc, overflowBc := new(u256.Uint).AddOverflow(b, c)
		right, overflowRight := new(u256.Uint).AddOverflow(a, bc)

		rightOverflowed := overflowBc || overflowRight

		if leftOverflowed != rightOverflowed {
			panic("Addition associativity failed: left overflowed != right overflowed")
		}

		if !left.Eq(right) {
			panic("Addition associativity failed: (a + b) + c != a + (b + c)")
		}
	})
}

// TestFuzzUint256Arithmetic_AdditionCommutativity tests a + b == b + a
func TestFuzzUint256Arithmetic_AdditionCommutativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		b := u256.MustFromDecimal(params.b)

		ab := new(u256.Uint).Add(a, b)
		ba := new(u256.Uint).Add(b, a)

		if !ab.Eq(ba) {
			panic("Addition commutativity failed: a + b != b + a")
		}
	})
}

// TestFuzzUint256Arithmetic_MultiplicationAssociativity tests (a * b) * c == a * (b * c)
func TestFuzzUint256Arithmetic_MultiplicationAssociativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - use small values to avoid overflow
		params := NewValidIdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		b := u256.MustFromDecimal(params.b)
		c := u256.MustFromDecimal(params.c)

		// (a * b) * c
		ab := new(u256.Uint).Mul(a, b)
		left := new(u256.Uint).Mul(ab, c)

		// a * (b * c)
		bc := new(u256.Uint).Mul(b, c)
		right := new(u256.Uint).Mul(a, bc)

		if !left.Eq(right) {
			panic("Multiplication associativity failed: (a * b) * c != a * (b * c)")
		}
	})
}

// TestFuzzUint256Arithmetic_MultiplicationCommutativity tests a * b == b * a
func TestFuzzUint256Arithmetic_MultiplicationCommutativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		b := u256.MustFromDecimal(params.b)

		ab := new(u256.Uint).Mul(a, b)
		ba := new(u256.Uint).Mul(b, a)

		if !ab.Eq(ba) {
			panic("Multiplication commutativity failed: a * b != b * a")
		}
	})
}

// TestFuzzUint256Arithmetic_DistributiveLaw tests a * (b + c) == a*b + a*c
func TestFuzzUint256Arithmetic_DistributiveLaw(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - use small values to avoid overflow
		params := NewValidIdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		b := u256.MustFromDecimal(params.b)
		c := u256.MustFromDecimal(params.c)

		// a * (b + c)
		bPlusC := new(u256.Uint).Add(b, c)
		left := new(u256.Uint).Mul(a, bPlusC)

		// a*b + a*c
		ab := new(u256.Uint).Mul(a, b)
		ac := new(u256.Uint).Mul(a, c)
		right := new(u256.Uint).Add(ab, ac)

		if !left.Eq(right) {
			panic("Distributive law failed: a * (b + c) != a*b + a*c")
		}
	})
}

// TestFuzzUint256Arithmetic_AdditionIdentity tests a + 0 == a
func TestFuzzUint256Arithmetic_AdditionIdentity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		zero := u256.Zero()

		result := new(u256.Uint).Add(a, zero)
		if !result.Eq(a) {
			panic("Addition identity failed: a + 0 != a")
		}
	})
}

// TestFuzzUint256Arithmetic_MultiplicationIdentity tests a * 1 == a
func TestFuzzUint256Arithmetic_MultiplicationIdentity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		one := u256.One()

		result := new(u256.Uint).Mul(a, one)
		if !result.Eq(a) {
			panic("Multiplication identity failed: a * 1 != a")
		}
	})
}

// TestFuzzUint256Arithmetic_MultiplicationZero tests a * 0 == 0
func TestFuzzUint256Arithmetic_MultiplicationZero(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)
		zero := u256.Zero()

		result := new(u256.Uint).Mul(a, zero)
		if !result.IsZero() {
			panic("Multiplication zero failed: a * 0 != 0")
		}
	})
}

// TestFuzzUint256Arithmetic_SubtractionInverse tests a - a == 0
func TestFuzzUint256Arithmetic_SubtractionInverse(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedIdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := u256.MustFromDecimal(params.a)

		result := new(u256.Uint).Sub(a, a)
		if !result.IsZero() {
			panic("Subtraction inverse failed: a - a != 0")
		}
	})
}

// TestFuzzUint256Arithmetic_DivModRelation tests Div(x, y) * y + Mod(x, y) == x
func TestFuzzUint256Arithmetic_DivModRelation(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		x := fuzz.Uint256().Draw(ft, "x").(*u256.Uint)
		y := fuzz.Uint64Range(1, 1<<63-1).Draw(ft, "y").(uint64)
		yU := u256.NewUint(y)

		params := &identityLawParams{
			a: x.ToString(),
			b: yU.ToString(),
			c: "0",
		}

		// when
		fuzzResult.AddParams(index, params)

		// then: Div(x, y) * y + Mod(x, y) == x
		div := new(u256.Uint).Div(x, yU)
		mod := new(u256.Uint).Mod(x, yU)
		mulBack := new(u256.Uint).Mul(div, yU)
		result := new(u256.Uint).Add(mulBack, mod)

		if !result.Eq(x) {
			panic("DivMod relation failed: Div(x, y) * y + Mod(x, y) != x")
		}
	})
}

// umul Sparse Tests
// umulBaseline is the reference implementation for comparison
func umulBaseline(x, y *u256.Uint) [8]uint64 {
	var (
		res                           [8]uint64
		carry, carry4, carry5, carry6 uint64
		res1, res2, res3, res4, res5  uint64
	)

	carry, res[0] = bits.Mul64(x[0], y[0])
	carry, res1 = umulHopLocal(carry, x[1], y[0])
	carry, res2 = umulHopLocal(carry, x[2], y[0])
	carry4, res3 = umulHopLocal(carry, x[3], y[0])

	carry, res[1] = umulHopLocal(res1, x[0], y[1])
	carry, res2 = umulStepLocal(res2, x[1], y[1], carry)
	carry, res3 = umulStepLocal(res3, x[2], y[1], carry)
	carry5, res4 = umulStepLocal(carry4, x[3], y[1], carry)

	carry, res[2] = umulHopLocal(res2, x[0], y[2])
	carry, res3 = umulStepLocal(res3, x[1], y[2], carry)
	carry, res4 = umulStepLocal(res4, x[2], y[2], carry)
	carry6, res5 = umulStepLocal(carry5, x[3], y[2], carry)

	carry, res[3] = umulHopLocal(res3, x[0], y[3])
	carry, res[4] = umulStepLocal(res4, x[1], y[3], carry)
	carry, res[5] = umulStepLocal(res5, x[2], y[3], carry)
	res[7], res[6] = umulStepLocal(carry6, x[3], y[3], carry)

	return res
}

func umulStepLocal(z, x, y, carry uint64) (hi, lo uint64) {
	hi, lo = bits.Mul64(x, y)
	lo, carry = bits.Add64(lo, carry, 0)
	hi += carry
	lo, carry = bits.Add64(lo, z, 0)
	hi += carry
	return hi, lo
}

func umulHopLocal(z, x, y uint64) (hi, lo uint64) {
	hi, lo = bits.Mul64(x, y)
	lo, carry := bits.Add64(lo, z, 0)
	hi += carry
	return hi, lo
}

// TestFuzzUint256UmulSparse_ValidParams tests umul with sparse patterns
func TestFuzzUmulSparse_ValidParams(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidUmulSparseParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := &u256.Uint{params.x0, params.x1, params.x2, params.x3}
		y := &u256.Uint{params.y0, params.y1, params.y2, params.y3}

		// Verify using MulOverflow (which uses umul internally)
		var z u256.Uint
		z.MulOverflow(x, y)

		// Compare with baseline
		expected := umulBaseline(x, y)

		// The lower 256 bits should match z
		if z[0] != expected[0] || z[1] != expected[1] || z[2] != expected[2] || z[3] != expected[3] {
			panic("umul sparse test failed: lower 256 bits mismatch")
		}
	})
}

// TestFuzzUint256UmulSparse_RandomizedParams tests umul with randomized parameters
func TestFuzzUmulSparse_RandomizedParams(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedUmulSparseParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := &u256.Uint{params.x0, params.x1, params.x2, params.x3}
		y := &u256.Uint{params.y0, params.y1, params.y2, params.y3}

		// Verify using MulOverflow
		var z u256.Uint
		z.MulOverflow(x, y)

		// Compare with baseline
		expected := umulBaseline(x, y)

		// The lower 256 bits should match z
		if z[0] != expected[0] || z[1] != expected[1] || z[2] != expected[2] || z[3] != expected[3] {
			panic("umul randomized test failed: lower 256 bits mismatch")
		}
	})
}

// TestFuzzUint256UmulSparse_Commutativity tests umul(x, y) == umul(y, x) for lower 256 bits
func TestFuzzUmulSparse_Commutativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedUmulSparseParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := &u256.Uint{params.x0, params.x1, params.x2, params.x3}
		y := &u256.Uint{params.y0, params.y1, params.y2, params.y3}

		// x * y
		xy := new(u256.Uint).Mul(x, y)
		// y * x
		yx := new(u256.Uint).Mul(y, x)

		if !xy.Eq(yx) {
			panic("umul commutativity failed: x * y != y * x")
		}
	})
}

// TestFuzzUint256UmulSparse_ZeroMultiplication tests umul(0, y) == 0 and umul(x, 0) == 0
func TestFuzzUmulSparse_ZeroMultiplication(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedUmulSparseParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := &u256.Uint{params.x0, params.x1, params.x2, params.x3}
		zero := u256.Zero()

		// x * 0
		result1 := new(u256.Uint).Mul(x, zero)
		if !result1.IsZero() {
			panic("umul zero test failed: x * 0 != 0")
		}

		// 0 * x
		result2 := new(u256.Uint).Mul(zero, x)
		if !result2.IsZero() {
			panic("umul zero test failed: 0 * x != 0")
		}
	})
}

// TestFuzzUint256UmulSparse_IdentityMultiplication tests umul(x, 1) == x
func TestFuzzUmulSparse_IdentityMultiplication(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedUmulSparseParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := &u256.Uint{params.x0, params.x1, params.x2, params.x3}
		one := u256.One()

		result := new(u256.Uint).Mul(x, one)
		if !result.Eq(x) {
			panic("umul identity test failed: x * 1 != x")
		}
	})
}
