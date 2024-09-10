package int256

import (
	"std"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

/*
This test demonstrates a issue(Gnoswap-17) in int256 implementation. The key steps are:

· Perform various arithmetic operations that result in zero
· Compare the results of these operations with regular zero
· Perform bitwise operations on the resulting zero values
· Compare the results of these operations with expected outcomes
*/
func TestInt256MinusZero(t *testing.T) {
	minusThree := i256.MustFromDecimal("-3")
	three := i256.MustFromDecimal("3")
	zero := i256.Zero()
	res := i256.Zero().Add(minusThree, three)
	println("-3 + 3 =",res.ToString())
	res2 := i256.Zero().Sub(minusThree, i256.MustFromDecimal("-3"))
	println("-3 - (-3) =", res2.ToString())
	res_tmp := i256.Zero().Mul(zero, minusThree)
	println("0 * -3 =", res_tmp.ToString())
	res_tmp2 := i256.Zero().Div(zero, minusThree)
	println("0 / -3 =", res_tmp2.ToString())
	
	res3 := i256.Zero().Sub(res, minusThree)
	res4 := i256.Zero().Sub(minusThree, res)
	res5 := i256.Zero().Sub(three, res)
	res6 := i256.Zero().Sub(res, three)

	res7 := i256.Zero().Add(res, minusThree)
	res8 := i256.Zero().Add(minusThree, res)
	res9 := i256.Zero().Add(three, res)
	res10 := i256.Zero().Add(res, three)

	res11 := i256.Zero().AddUint256(res, u256.MustFromDecimal("3"))
	res12 := u256.MustFromDecimal("0")
	i256.AddDelta(res12, u256.MustFromDecimal("3"), res)
	res13 := u256.MustFromDecimal("0")
	i256.AddDelta(res13, u256.MustFromDecimal("0"), res)
	res14 := i256.Zero().Mod(res, three)
	res15 := i256.Zero().Mod(res, minusThree)

	res16 := res.Eq(zero)
	res17 := res.Neq(zero)
	res18 := res.Cmp(zero)
	res19 := res.Lt(zero)
	res20 := res.Lt(three)
	res21 := res.Lt(minusThree)
	res22 := res.Gt(zero)
	res23 := res.Gt(three)
	res24 := res.Gt(minusThree)
	res25 := res.Cmp(three)
	res26 := res.Cmp(minusThree)

	res27 := i256.Zero().And(res, minusThree)
	res27_cmp := i256.Zero().And(zero, minusThree)
	res28 := i256.Zero().And(minusThree, res)
	res28_cmp := i256.Zero().And(minusThree, zero)
	res29 := i256.Zero().And(res, three)
	res29_cmp := i256.Zero().And(zero, three)
	res30 := i256.Zero().And(three,res)
	res30_cmp := i256.Zero().And(three,zero)

	res31 := i256.Zero().Or(res, minusThree)
	res31_cmp := i256.Zero().Or(zero, minusThree)
	res32 := i256.Zero().Or(minusThree, res)
	res32_cmp := i256.Zero().Or(minusThree, zero)
	res33 := i256.Zero().Or(res, three)
	res33_cmp := i256.Zero().Or(zero, three)
	res34 := i256.Zero().Or(three, res)
	res34_cmp := i256.Zero().Or(three, zero)

	res35 := i256.Zero().Rsh(res, 1234)
	res35_cmp := i256.Zero().Rsh(zero, 1234)
	res36 := i256.Zero().Lsh(res, 1234)
	res36_cmp := i256.Zero().Lsh(zero, 1234)

	shouldEQ(t, res3.ToString(), "3")
	shouldEQ(t, res4.ToString(), "-3")
	shouldEQ(t, res5.ToString(), "3")
	shouldEQ(t, res6.ToString(), "-3")
	shouldEQ(t, res7.ToString(), "-3")
	shouldEQ(t, res8.ToString(), "-3")
	shouldEQ(t, res9.ToString(), "3")
	shouldEQ(t, res10.ToString(), "3")
	shouldEQ(t, res11.ToString(), "3")
	shouldEQ(t, res12.ToString(), "3")
	shouldEQ(t, res13.ToString(), "0")
	shouldEQ(t, res14.ToString(), "0")
	shouldEQ(t, res15.ToString(), "0")

	shouldEQ(t, res16, true) // got false, expected true 
	shouldEQ(t, res17, false) // got true, expected false 
	shouldEQ(t, res18, 0) // got -1, expected 0 
	shouldEQ(t, res19, false) // got true, expected false 
	shouldEQ(t, res20, true)
	shouldEQ(t, res21, false) 
	shouldEQ(t, res22, false)
	shouldEQ(t, res23, false)
	shouldEQ(t, res24, true) 
	shouldEQ(t, res25, -1)
	shouldEQ(t, res26, 1)
	shouldEQ(t, res27.ToString(), res27_cmp.ToString()) // got -0, expected 0
	shouldEQ(t, res28.ToString(), res28_cmp.ToString()) // got -0, expected 0
	shouldEQ(t, res29.ToString(), res29_cmp.ToString())
	shouldEQ(t, res30.ToString(), res30_cmp.ToString())
	shouldEQ(t, res31.ToString(), res31_cmp.ToString())
	shouldEQ(t, res32.ToString(), res32_cmp.ToString())
	shouldEQ(t, res33.ToString(), res33_cmp.ToString()) // got -115792089237316195423570985008687907853269984665640564039457584007913129639933, expected 3
	shouldEQ(t, res34.ToString(), res34_cmp.ToString()) // got -115792089237316195423570985008687907853269984665640564039457584007913129639933, expected 3
	shouldEQ(t, res35.ToString(), res35_cmp.ToString()) // got -0, expected 0
	shouldEQ(t, res36.ToString(), res36_cmp.ToString()) // got -0, expected 0

	print("Done")	
}

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}
