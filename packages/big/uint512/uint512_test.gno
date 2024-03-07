package uint512

import (
	i256 "gno.land/p/big/int256"
	u256 "gno.land/p/big/uint256"

	"testing"
)

func init() {
	var _1 = i256.Zero()
	var _2 = u256.Zero()
}

// func TestFunc(*testing.T) {
// 	x := u256.UnsafeFromDecimal("792281625142643375935439503360000000")
// 	y := u256.UnsafeFromDecimal("1461446703485210103208044889689724484785180020005")
// 	d := u256.One()

// 	z := MulDiv(x, y, d)
// 	println(z.ToString())
// }

func TestFunc2(t *testing.T) {
	x := u256.UnsafeFromDecimal("792281625142643375935439503360000000")              // num1
	y := u256.UnsafeFromDecimal("1461446703485210103208044889689724484785180020005") // num2
	// d := u256.One()

	sqrtB := u256.UnsafeFromDecimal("1461446703485210103287273052203988822378723970342")
	sqrtA := u256.UnsafeFromDecimal("79228162514264337593543950337")

	z := MulDiv(x, y, sqrtB)
	// println("num1 * num2 / sqrtB:", z.ToString())

	r := DivRoundingUp(z, sqrtA)
	println("num1 * num2 / sqrtB / sqrtA:", r.ToString())
}
