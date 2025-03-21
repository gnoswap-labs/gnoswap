package uint256

import (
	"testing"
)

var Q128 *Uint

func init() {
	Q128 = MustFromDecimal("340282366920938463463374607431768211456") // 2**128
}

func TestFullMathMulDiv(t *testing.T) {
	t.Run("reverts if denominator is 0", func(t *testing.T) {
		x := NewUint(5)
		y := Zero()

		shouldPanic(
			t,
			func() {
				MulDiv(Q128, x, y)
			},
		)
	})

	t.Run("reverts if denominator is 0 and numerator overflows", func(t *testing.T) {
		y := Zero()

		shouldPanic(
			t,
			func() {
				MulDiv(Q128, Q128, y)
			},
		)
	})

	t.Run("reverts if output overflows uint256", func(t *testing.T) {
		y := One()

		shouldPanic(
			t,
			func() {
				MulDiv(Q128, Q128, y)
			},
		)
	})

	t.Run("reverts on overflow with all max inputs", func(t *testing.T) {
		MaxUint256 := MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935")
		MaxUint256Sub1 := MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639934")

		shouldPanic(
			t,
			func() {
				MulDiv(MaxUint256, MaxUint256, MaxUint256Sub1)
			},
		)
	})

	t.Run("all max inputs", func(t *testing.T) {
		MaxUint256 := MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935")

		got := MulDiv(MaxUint256, MaxUint256, MaxUint256)

		rst := got.Eq(MaxUint256)
		if !rst {
			t.Errorf("MaxUin256*MaxUint256/MaxUint256 is not same to MaxUint256")
		}
	})

	t.Run("accurate without phantom overflow", func(t *testing.T) {
		result := new(Uint).Div(Q128, NewUint(3))

		x := NewUint(50)
		x = x.Mul(x, Q128)
		x = x.Div(x, NewUint(100)) /*0.5=*/

		y := NewUint(150)
		y = y.Mul(y, Q128)
		y = y.Div(y, NewUint(100)) /*1.5=*/

		got := MulDiv(Q128, x, y)
		if !got.Eq(result) {
			t.Errorf("Q128/3 is not same to Q128 * (50*Q128/100) / (150*Q128/100)")
		}
	})

	t.Run("accurate with phantom overflow", func(t *testing.T) {
		x := NewUint(4375)
		expected := MulDiv(x, Q128, NewUint(1000))

		y := NewUint(35)
		y = y.Mul(y, Q128)

		denom := NewUint(8)
		denom = denom.Mul(denom, Q128)

		got := MulDiv(Q128, y, denom)
		if !got.Eq(expected) {
			t.Errorf("4375*Q128/1000 is not same to Q128 * 35*Q128 / 8*Q128")
		}
	})

	t.Run("accurate with phantom overflow and repeating decimal", func(t *testing.T) {
		expected := MulDiv(One(), Q128, NewUint(3))

		y := NewUint(1000)
		y = y.Mul(y, Q128)

		denom := NewUint(3000)
		denom = denom.Mul(denom, Q128)

		got := MulDiv(Q128, y, denom)
		if !got.Eq(expected) {
			t.Errorf("1*Q128/3 is not same to Q128 * 1000*Q128 / 3000*Q128")
		}
	})
}

func TestMulDivRoundingUp(t *testing.T) {
	t.Run("reverts if denominator is 0", func(t *testing.T) {
		x := NewUint(5)
		y := Zero()

		shouldPanic(
			t,
			func() {
				MulDivRoundingUp(Q128, x, y)
			},
		)
	})

	t.Run("reverts if denominator is 0 and numerator overflows", func(t *testing.T) {
		y := Zero()

		shouldPanic(
			t,
			func() {
				MulDivRoundingUp(Q128, Q128, y)
			},
		)
	})

	t.Run("reverts if output overflows uint256", func(t *testing.T) {
		y := One()

		shouldPanic(
			t,
			func() {
				MulDivRoundingUp(Q128, Q128, y)
			},
		)
	})

	t.Run("reverts on overflow with all max inputs", func(t *testing.T) {
		MaxUint256 := MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935")
		MaxUint256Sub1 := MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639934")

		shouldPanic(
			t,
			func() {
				MulDivRoundingUp(MaxUint256, MaxUint256, MaxUint256Sub1)
			},
		)
	})

	t.Run("reverts if mulDiv overflows 256 bits after rounding up", func(t *testing.T) {
		x := MustFromDecimal("535006138814359")
		y := MustFromDecimal("432862656469423142931042426214547535783388063929571229938474969")

		shouldPanic(
			t,
			func() {
				MulDivRoundingUp(x, y, NewUint(2))
			},
		)
	})

	t.Run("reverts if mulDiv overflows 256 bits after rounding up case 2", func(t *testing.T) {
		x := MustFromDecimal("115792089237316195423570985008687907853269984659341747863450311749907997002549")
		y := MustFromDecimal("115792089237316195423570985008687907853269984659341747863450311749907997002550")
		z := MustFromDecimal("115792089237316195423570985008687907853269984653042931687443039491902864365164")

		shouldPanic(
			t,
			func() {
				MulDivRoundingUp(x, y, z)
			},
		)
	})

	t.Run("all max inputs", func(t *testing.T) {
		MaxUint256 := MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935")

		got := MulDivRoundingUp(MaxUint256, MaxUint256, MaxUint256)

		rst := got.Eq(MaxUint256)
		if !rst {
			t.Errorf("MaxUin256*MaxUint256/MaxUint256 RoudingUp is not same to MaxUint256")
		}
	})

	t.Run("accurate without phantom overflow", func(t *testing.T) {
		result := new(Uint).Div(Q128, NewUint(3))
		result = result.Add(result, One())

		x := NewUint(50)
		x = x.Mul(x, Q128)
		x = x.Div(x, NewUint(100)) /*0.5=*/

		y := NewUint(150)
		y = y.Mul(y, Q128)
		y = y.Div(y, NewUint(100)) /*1.5=*/

		got := MulDivRoundingUp(Q128, x, y)
		if !got.Eq(result) {
			t.Errorf("Q128/3 is not same to Q128 * (50*Q128/100) / (150*Q128/100)")
		}
	})

	t.Run("accurate with phantom overflow", func(t *testing.T) {
		x := NewUint(4375)
		expected := MulDiv(x, Q128, NewUint(1000))

		y := NewUint(35)
		y = y.Mul(y, Q128)

		denom := NewUint(8)
		denom = denom.Mul(denom, Q128)

		got := MulDivRoundingUp(Q128, y, denom)
		if !got.Eq(expected) {
			t.Errorf("4375*Q128/1000 is not same to Q128 * 35*Q128 / 8*Q128")
		}
	})

	t.Run("accurate with phantom overflow and repeating decimal", func(t *testing.T) {
		expected := MulDiv(One(), Q128, NewUint(3))
		expected = expected.Add(expected, One())

		y := NewUint(1000)
		y = y.Mul(y, Q128)

		denom := NewUint(3000)
		denom = denom.Mul(denom, Q128)

		got := MulDivRoundingUp(Q128, y, denom)
		if !got.Eq(expected) {
			t.Errorf("1*Q128/3+1 is not same to Q128 * 1000*Q128 / 3000*Q128")
		}
	})
}

func TestMulDiv_PowerOfTwo_DivisionByFour(t *testing.T) {
	// calculated by hand
	expected := MustFromDecimal("28948022309329048855892746252171976963317496166410141009864396001978282409984")

	// (57896044618658097711785492504343953926634992332820282019728792003956564819968 * 2) / 4
	x := TwoToThe255()
	y := NewUint(2)
	z := NewUint(4)

	got := MulDiv(x, y, z)

	rst := got.Eq(expected)
	if !rst {
		t.Errorf("got: %s", got.ToString())
		t.Errorf("expected: %s", expected.ToString())
	}
}

func TwoToThe255() *Uint {
    u := &Uint{arr: [4]uint64{0, 0, 0, 1 << 63}}
    return u
}
