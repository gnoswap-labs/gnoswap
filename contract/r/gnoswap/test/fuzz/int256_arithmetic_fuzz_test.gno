package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	i256 "gno.land/p/gnoswap/int256"
)

// Arithmetic Identity Laws Tests

// TestFuzzInt256Arithmetic_AdditionAssociativity tests (a + b) + c == a + (b + c)
func TestFuzzInt256Arithmetic_AdditionAssociativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - use valid params to avoid overflow
		params := NewValidInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		b := i256.MustFromDecimal(params.b)
		c := i256.MustFromDecimal(params.c)

		// (a + b) + c
		ab := new(i256.Int).Add(a, b)
		left := new(i256.Int).Add(ab, c)

		// a + (b + c)
		bc := new(i256.Int).Add(b, c)
		right := new(i256.Int).Add(a, bc)

		if !left.Eq(right) {
			panic("Addition associativity failed: (a + b) + c != a + (b + c)")
		}
	})
}

// TestFuzzInt256Arithmetic_AdditionCommutativity tests a + b == b + a
func TestFuzzInt256Arithmetic_AdditionCommutativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		b := i256.MustFromDecimal(params.b)

		ab := new(i256.Int).Add(a, b)
		ba := new(i256.Int).Add(b, a)

		if !ab.Eq(ba) {
			panic("Addition commutativity failed: a + b != b + a")
		}
	})
}

// TestFuzzInt256Arithmetic_MultiplicationAssociativity tests (a * b) * c == a * (b * c)
func TestFuzzInt256Arithmetic_MultiplicationAssociativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - use small values to avoid overflow
		params := NewValidInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		b := i256.MustFromDecimal(params.b)
		c := i256.MustFromDecimal(params.c)

		// (a * b) * c
		ab := new(i256.Int).Mul(a, b)
		left := new(i256.Int).Mul(ab, c)

		// a * (b * c)
		bc := new(i256.Int).Mul(b, c)
		right := new(i256.Int).Mul(a, bc)

		if !left.Eq(right) {
			panic("Multiplication associativity failed: (a * b) * c != a * (b * c)")
		}
	})
}

// TestFuzzInt256Arithmetic_MultiplicationCommutativity tests a * b == b * a
func TestFuzzInt256Arithmetic_MultiplicationCommutativity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		b := i256.MustFromDecimal(params.b)

		ab := new(i256.Int).Mul(a, b)
		ba := new(i256.Int).Mul(b, a)

		if !ab.Eq(ba) {
			panic("Multiplication commutativity failed: a * b != b * a")
		}
	})
}

// TestFuzzInt256Arithmetic_DistributiveLaw tests a * (b + c) == a*b + a*c
func TestFuzzInt256Arithmetic_DistributiveLaw(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - use small values to avoid overflow
		params := NewValidInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		b := i256.MustFromDecimal(params.b)
		c := i256.MustFromDecimal(params.c)

		// a * (b + c)
		bPlusC := new(i256.Int).Add(b, c)
		left := new(i256.Int).Mul(a, bPlusC)

		// a*b + a*c
		ab := new(i256.Int).Mul(a, b)
		ac := new(i256.Int).Mul(a, c)
		right := new(i256.Int).Add(ab, ac)

		if !left.Eq(right) {
			panic("Distributive law failed: a * (b + c) != a*b + a*c")
		}
	})
}

// TestFuzzInt256Arithmetic_AdditionIdentity tests a + 0 == a
func TestFuzzInt256Arithmetic_AdditionIdentity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		zero := i256.Zero()

		result := new(i256.Int).Add(a, zero)
		if !result.Eq(a) {
			panic("Addition identity failed: a + 0 != a")
		}
	})
}

// TestFuzzInt256Arithmetic_MultiplicationIdentity tests a * 1 == a
func TestFuzzInt256Arithmetic_MultiplicationIdentity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		one := i256.One()

		result := new(i256.Int).Mul(a, one)
		if !result.Eq(a) {
			panic("Multiplication identity failed: a * 1 != a")
		}
	})
}

// TestFuzzInt256Arithmetic_MultiplicationZero tests a * 0 == 0
func TestFuzzInt256Arithmetic_MultiplicationZero(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		zero := i256.Zero()

		result := new(i256.Int).Mul(a, zero)
		if !result.IsZero() {
			panic("Multiplication zero failed: a * 0 != 0")
		}
	})
}

// TestFuzzInt256Arithmetic_SubtractionInverse tests a - a == 0
func TestFuzzInt256Arithmetic_SubtractionInverse(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)

		result := new(i256.Int).Sub(a, a)
		if !result.IsZero() {
			panic("Subtraction inverse failed: a - a != 0")
		}
	})
}

// TestFuzzInt256Arithmetic_AdditionInverse tests a + (-a) == 0
func TestFuzzInt256Arithmetic_AdditionInverse(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		negA := new(i256.Int).Neg(a)

		result := new(i256.Int).Add(a, negA)
		if !result.IsZero() {
			panic("Addition inverse failed: a + (-a) != 0")
		}
	})
}

// TestFuzzInt256Arithmetic_DoubleNegation tests -(-a) == a
func TestFuzzInt256Arithmetic_DoubleNegation(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		negA := new(i256.Int).Neg(a)
		result := new(i256.Int).Neg(negA)

		if !result.Eq(a) {
			panic("Double negation failed: -(-a) != a")
		}
	})
}

// TestFuzzInt256Arithmetic_NegationMultiplication tests -a == a * (-1)
func TestFuzzInt256Arithmetic_NegationMultiplication(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		negOne := i256.NewInt(-1)

		negA := new(i256.Int).Neg(a)
		mulResult := new(i256.Int).Mul(a, negOne)

		if !negA.Eq(mulResult) {
			panic("Negation multiplication failed: -a != a * (-1)")
		}
	})
}

// TestFuzzInt256Cmp_Antisymmetry tests if a.Cmp(b) == 1 then b.Cmp(a) == -1
func TestFuzzInt256Cmp_Antisymmetry(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256CmpParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		cmpXY := x.Cmp(y)
		cmpYX := y.Cmp(x)

		if cmpXY != -cmpYX {
			panic("Comparison antisymmetry failed: x.Cmp(y) != -y.Cmp(x)")
		}
	})
}

// TestFuzzInt256Cmp_Transitivity tests transitivity of comparison
func TestFuzzInt256Cmp_Transitivity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256IdentityLawParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		a := i256.MustFromDecimal(params.a)
		b := i256.MustFromDecimal(params.b)
		c := i256.MustFromDecimal(params.c)

		// If a <= b and b <= c, then a <= c
		if a.Lte(b) && b.Lte(c) {
			if !a.Lte(c) {
				panic("Comparison transitivity failed: a <= b and b <= c but a > c")
			}
		}
	})
}

// TestFuzzInt256Cmp_EqConsistency tests Eq consistency with Cmp
func TestFuzzInt256Cmp_EqConsistency(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256CmpParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		cmpResult := x.Cmp(y)
		eqResult := x.Eq(y)

		if (cmpResult == 0) != eqResult {
			panic("Eq/Cmp consistency failed: (Cmp == 0) != Eq")
		}
	})
}

// TestFuzzInt256Cmp_LtGtConsistency tests Lt/Gt consistency
func TestFuzzInt256Cmp_LtGtConsistency(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256CmpParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		y := i256.MustFromDecimal(params.y)

		// x < y should be same as y > x
		if x.Lt(y) != y.Gt(x) {
			panic("Lt/Gt consistency failed: (x < y) != (y > x)")
		}

		// x <= y should be same as y >= x
		if x.Lte(y) != y.Gte(x) {
			panic("Lte/Gte consistency failed: (x <= y) != (y >= x)")
		}
	})
}

// Sign Tests

// TestFuzzInt256Sign_Consistency tests sign consistency
func TestFuzzInt256Sign_Consistency(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256SignParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		sign := x.Sign()

		// Sign should be -1, 0, or 1
		if sign != -1 && sign != 0 && sign != 1 {
			panic("Sign is not -1, 0, or 1")
		}

		// Sign consistency with comparison to zero
		zero := i256.Zero()
		if sign == 0 && !x.Eq(zero) {
			panic("Sign is 0 but x != 0")
		}
		if sign > 0 && !x.Gt(zero) {
			panic("Sign > 0 but x <= 0")
		}
		if sign < 0 && !x.Lt(zero) {
			panic("Sign < 0 but x >= 0")
		}
	})
}

// TestFuzzInt256Sign_NegConsistency tests sign consistency with negation
func TestFuzzInt256Sign_NegConsistency(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256SignParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		negX := new(i256.Int).Neg(x)

		signX := x.Sign()
		signNegX := negX.Sign()

		// Sign of -x should be opposite of x (unless x is zero)
		if !x.IsZero() && signX != -signNegX {
			panic("Sign of -x is not opposite of sign of x")
		}
	})
}

// Clone Tests

// TestFuzzInt256Clone_Equality tests clone produces equal value
func TestFuzzInt256Clone_Equality(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256CloneParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		clone := x.Clone()

		if !x.Eq(clone) {
			panic("Clone not equal to original")
		}
	})
}

// TestFuzzInt256Clone_Independence tests clone is independent
func TestFuzzInt256Clone_Independence(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256CloneParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		x := i256.MustFromDecimal(params.x)
		clone := x.Clone()

		// Modify clone
		clone.Add(clone, i256.One())

		// Original should not change (unless it was max which would wrap)
		// Compare string representations to check independence
		if x.ToString() == clone.ToString() && !x.Eq(i256.MaxInt256()) {
			panic("Clone modification affected original")
		}
	})
}

// Conversion Tests

// TestFuzzInt256Conversion_Int64RoundTrip tests Int64 round-trip for small values
func TestFuzzInt256Conversion_Int64RoundTrip(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		x := fuzz.Int64().Draw(ft, "x").(int64)
		params := &int256ConversionParams{x: i256.NewInt(x).ToString()}

		// when
		fuzzResult.AddParams(index, params)

		// then
		val := i256.NewInt(x)
		roundTrip := val.Int64()

		if roundTrip != x {
			panic("Int64 round-trip failed")
		}
	})
}

// TestFuzzInt256Conversion_SetStringRoundTrip tests SetString/ToString round-trip
func TestFuzzInt256Conversion_SetStringRoundTrip(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256SetStringParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		val, err := i256.FromDecimal(params.s)
		if err != nil {
			panic("FromDecimal failed: " + err.Error())
		}

		roundTrip := val.ToString()

		// Parse again and compare
		val2, err := i256.FromDecimal(roundTrip)
		if err != nil {
			panic("Second FromDecimal failed: " + err.Error())
		}

		if !val.Eq(val2) {
			panic("SetString round-trip failed")
		}
	})
}

// Boundary Tests

// TestFuzzInt256Boundary_MaxMinRelation tests MaxInt256 > MinInt256
func TestFuzzInt256Boundary_MaxMinRelation(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256BoundaryParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		max := i256.MaxInt256()
		min := i256.MinInt256()

		if !max.Gt(min) {
			panic("MaxInt256 is not greater than MinInt256")
		}

		if !max.Gt(i256.Zero()) {
			panic("MaxInt256 is not greater than zero")
		}

		if !min.Lt(i256.Zero()) {
			panic("MinInt256 is not less than zero")
		}
	})
}

// TestFuzzInt256Boundary_ZeroIdentity tests zero boundary behavior
func TestFuzzInt256Boundary_ZeroIdentity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256BoundaryParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		zero := i256.Zero()

		if zero.Sign() != 0 {
			panic("Zero sign is not 0")
		}

		if !zero.IsZero() {
			panic("Zero.IsZero() is false")
		}

		if zero.IsNeg() {
			panic("Zero is negative")
		}
	})
}

// TestFuzzInt256Boundary_OneIdentity tests one boundary behavior
func TestFuzzInt256Boundary_OneIdentity(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidInt256BoundaryParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		one := i256.One()

		if one.Sign() != 1 {
			panic("One sign is not 1")
		}

		if one.IsZero() {
			panic("One.IsZero() is true")
		}

		if one.IsNeg() {
			panic("One is negative")
		}
	})
}
