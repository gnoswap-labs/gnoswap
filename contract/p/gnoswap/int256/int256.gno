package int256

import (
	"encoding/binary"
	"math"
	"math/bits"

	u256 "gno.land/p/gnoswap/uint256"
)

type Int [4]uint64

// Zero returns a fresh Int whose 256 bits are all zero.
//
// Returns:
//   - zero: A mutable *Int representing the signed value 0.
func Zero() *Int {
	return &Int{}
}

// One returns a fresh Int representing the signed value 1.
//
// Returns:
//   - one: A mutable *Int with only its least-significant bit set.
func One() *Int {
	return &Int{1, 0, 0, 0}
}

// MinInt256 returns the minimum signed 256-bit integer, -2^255.
//
// Returns:
//   - minimum: A fresh *Int containing the two's-complement minimum value.
func MinInt256() *Int {
	return &Int{0, 0, 0, 0x8000000000000000}
}

// MaxInt256 returns the maximum signed 256-bit integer, 2^255 - 1.
//
// Returns:
//   - maximum: A fresh *Int containing the largest positive int256 value.
func MaxInt256() *Int {
	return &Int{0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0x7fffffffffffffff}
}

// NewInt constructs a signed 256-bit integer from an int64.
//
// Parameters:
//   - val: Signed 64-bit value to sign-extend into 256 bits.
//
// Returns:
//   - value: A fresh *Int representing val.
func NewInt(val int64) *Int {
	z := &Int{}
	z.SetInt64(val)
	return z
}

// Set copies the complete 256-bit value from x into z.
//
// Parameters:
//   - x: Source Int whose four limbs are copied.
//
// Returns:
//   - z: The receiver after copying x.
func (z *Int) Set(x *Int) *Int {
	z[0], z[1], z[2], z[3] = x[0], x[1], x[2], x[3]
	return z
}

// SetInt64 assigns x to z with two's-complement sign extension.
//
// Parameters:
//   - x: Signed 64-bit value to store.
//
// Returns:
//   - z: The receiver representing x as an Int.
func (z *Int) SetInt64(x int64) *Int {
	if x >= 0 {
		z[3], z[2], z[1], z[0] = 0, 0, 0, uint64(x)
		return z
	}

	z[3], z[2], z[1], z[0] = 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, uint64(x)
	return z
}

// IsInt64 reports whether z can be represented exactly as a signed int64.
//
// Returns:
//   - fits: True when z is in [math.MinInt64, math.MaxInt64], false otherwise.
func (z *Int) IsInt64() bool {
	return ((z[1]|z[2]|z[3]) == 0 && z[0] <= 0x7fffffffffffffff) || // zero or positive int64
		((z[1]&z[2]&z[3]) == 0xffffffffffffffff && z[0] >= 0x8000000000000000) // negative int64
}

// Int64 converts z to int64 after checking its signed range.
//
// Returns:
//   - value: z's exact signed 64-bit value.
//
// Panics if z is outside the signed int64 range.
func (z *Int) Int64() int64 {
	if !z.IsInt64() {
		panic("int256: int64 overflow")
	}
	s := z.Sign()
	if s == 0 {
		return 0
	}
	if s > 0 {
		// overflow when z[0] > math.MaxInt64
		return int64(z[0])
	}
	// -(2^64 - z[0])
	return -int64(math.MaxUint64 - z[0] + 1)
}

// SetUint64 assigns the non-negative uint64 x to z, clearing its upper limbs.
//
// Parameters:
//   - x: Unsigned 64-bit value to store.
//
// Returns:
//   - z: The receiver representing x as a non-negative Int.
func (z *Int) SetUint64(x uint64) *Int {
	z[3], z[2], z[1], z[0] = 0, 0, 0, x
	return z
}

// IsUint64 reports whether z fits in an unsigned 64-bit word.
//
// Returns:
//   - fits: True when all three upper 64-bit limbs of z are zero.
func (z *Int) IsUint64() bool {
	return (z[1] | z[2] | z[3]) == 0
}

// Uint64 converts z to uint64 when its upper 192 bits are zero.
//
// Returns:
//   - value: z's exact unsigned 64-bit value.
//
// Panics if any upper limb of z is non-zero.
func (z *Int) Uint64() uint64 {
	if !z.IsUint64() {
		panic("int256: uint64 overflow")
	}
	return z[0]
}

// Abs returns the unsigned magnitude of z.
//
// Returns:
//   - magnitude: A *u256.Uint containing |z|; negative values are negated before conversion.
//
// Panics for MinInt256 because NegOverflow cannot represent its positive magnitude as Int.
func (z *Int) Abs() *u256.Uint {
	if z.IsNeg() {
		neg := new(Int).NegOverflow(z)
		return &u256.Uint{neg[0], neg[1], neg[2], neg[3]}
	}
	return &u256.Uint{z[0], z[1], z[2], z[3]}
}

// Sign reports the signed sign of z.
//
// Returns:
//   - sign: -1 for negative z, 0 for zero z, or 1 for positive z.
func (z *Int) Sign() int {
	if z.IsZero() {
		return 0
	}
	if z[3]&0x8000000000000000 == 0 {
		return 1
	}
	return -1
}

// IsZero reports whether every limb of z is zero.
//
// Returns:
//   - isZero: True exactly when z represents the signed value 0.
func (z *Int) IsZero() bool {
	return (z[0] | z[1] | z[2] | z[3]) == 0
}

// IsOne reports whether z represents the signed value 1.
//
// Returns:
//   - isOne: True exactly when the low limb is 1 and all upper limbs are zero.
func (z *Int) IsOne() bool {
	return (z[0] == 1) && (z[1]|z[2]|z[3]) == 0
}

// IsNeg reports whether z has its signed two's-complement sign bit set.
//
// Returns:
//   - isNegative: True when z is negative, including MinInt256.
func (z *Int) IsNeg() bool {
	return z[3]&0x8000000000000000 != 0
}

// IsPositive reports whether z is strictly greater than zero.
//
// Returns:
//   - isPositive: True when the sign bit is clear and at least one value bit is set.
func (z *Int) IsPositive() bool {
	return (z[3]&0x8000000000000000) == 0 && (z[3]|z[2]|z[1]|z[0]) != 0
}

// IsMinI256 reports whether z equals MinInt256.
//
// Returns:
//   - isMinimum: True only for the bit pattern 0x8000...0000.
func (z *Int) IsMinI256() bool {
	return (z[3] == 0x8000000000000000) && ((z[2] | z[1] | z[0]) == 0)
}

// NegOverflow computes the two's-complement negation of x and rejects the
// one value whose positive magnitude is outside signed int256.
//
// Parameters:
//   - x: Signed 256-bit value to negate.
//
// Returns:
//   - z: The receiver containing -x.
//
// Panics when x is MinInt256.
func (z *Int) NegOverflow(x *Int) *Int {
	if x[3] == 0x8000000000000000 && x[2] == 0 && x[1] == 0 && x[0] == 0 {
		panic("int256: overflow")
	}

	return z.Neg(x)
}

// Neg computes the two's-complement negation of x modulo 2^256.
//
// Parameters:
//   - x: 256-bit value whose bits are complemented and incremented.
//
// Returns:
//   - z: The receiver containing the wrapped negation of x.
func (z *Int) Neg(x *Int) *Int {
	var carry uint64
	z[0], z[1], z[2], z[3] = ^x[0], ^x[1], ^x[2], ^x[3]
	z[0], carry = bits.Add64(z[0], 1, 0)
	z[1], carry = bits.Add64(z[1], 0, carry)
	z[2], carry = bits.Add64(z[2], 0, carry)
	z[3] += carry
	return z
}

// Eq reports whether z and x have identical 256-bit representations.
//
// Parameters:
//   - x: Int to compare with z.
//
// Returns:
//   - equal: True when all four limbs match.
func (z *Int) Eq(x *Int) bool {
	return (z[0] == x[0]) && (z[1] == x[1]) && (z[2] == x[2]) && (z[3] == x[3])
}

// Neq reports whether z and x have different 256-bit representations.
//
// Parameters:
//   - x: Int to compare with z.
//
// Returns:
//   - different: True when at least one limb differs.
func (z *Int) Neq(x *Int) bool {
	return !z.Eq(x)
}

// Add adds x and y modulo 2^256.
//
// Parameters:
//   - x: First signed 256-bit addend.
//   - y: Second signed 256-bit addend.
//
// Returns:
//   - z: The receiver containing the low 256 bits of x + y.
func (z *Int) Add(x, y *Int) *Int {
	var carry uint64
	z[0], carry = bits.Add64(x[0], y[0], 0)
	z[1], carry = bits.Add64(x[1], y[1], carry)
	z[2], carry = bits.Add64(x[2], y[2], carry)
	z[3] = x[3] + y[3] + carry
	return z
}

// AddOverflow adds x and y modulo 2^256 and reports signed overflow.
//
// Parameters:
//   - x: First signed 256-bit addend.
//   - y: Second signed 256-bit addend.
//
// Returns:
//   - z: The wrapped 256-bit sum.
//   - overflow: True when x and y have the same sign but the wrapped sum has the opposite sign.
func (z *Int) AddOverflow(x, y *Int) (*Int, bool) {
	var carry uint64
	z[0], carry = bits.Add64(x[0], y[0], 0)
	z[1], carry = bits.Add64(x[1], y[1], carry)
	z[2], carry = bits.Add64(x[2], y[2], carry)
	z[3] = x[3] + y[3] + carry
	var overflow bool
	signX, signY, signZ := x.Sign(), y.Sign(), z.Sign()
	if (signX == signY) && (signX != signZ) {
		overflow = true
	}
	return z, overflow
}

// Sub subtracts y from x modulo 2^256.
//
// Parameters:
//   - x: Signed 256-bit minuend.
//   - y: Signed 256-bit subtrahend.
//
// Returns:
//   - z: The receiver containing the low 256 bits of x - y.
func (z *Int) Sub(x, y *Int) *Int {
	var carry uint64
	z[0], carry = bits.Sub64(x[0], y[0], 0)
	z[1], carry = bits.Sub64(x[1], y[1], carry)
	z[2], carry = bits.Sub64(x[2], y[2], carry)
	z[3] = x[3] - y[3] - carry
	return z
}

// SubOverflow subtracts y from x modulo 2^256 and reports signed overflow.
//
// Parameters:
//   - x: Signed 256-bit minuend.
//   - y: Signed 256-bit subtrahend.
//
// Returns:
//   - z: The wrapped 256-bit difference.
//   - overflow: True when the mathematical signed difference is outside the int256 range.
func (z *Int) SubOverflow(x, y *Int) (*Int, bool) {
	var carry uint64
	z[0], carry = bits.Sub64(x[0], y[0], 0)
	z[1], carry = bits.Sub64(x[1], y[1], carry)
	z[2], carry = bits.Sub64(x[2], y[2], carry)
	z[3] = x[3] - y[3] - carry
	var overflow bool
	signX, signY, signZ := x.Sign(), y.Sign(), z.Sign()
	if (signX == 0 && y.IsMinI256()) || ((signX != 0) && (signX != signY) && (signX != signZ)) {
		overflow = true
	}
	return z, overflow
}

// Mul multiplies x and y modulo 2^256.
//
// Parameters:
//   - x: First signed 256-bit factor.
//   - y: Second signed 256-bit factor.
//
// Returns:
//   - z: The receiver containing the low 256 bits of x * y.
func (z *Int) Mul(x, y *Int) *Int {
	var (
		res              Int
		carry            uint64
		res1, res2, res3 uint64
	)

	carry, res[0] = bits.Mul64(x[0], y[0])
	carry, res1 = umulHop(carry, x[1], y[0])
	carry, res2 = umulHop(carry, x[2], y[0])
	res3 = x[3]*y[0] + carry

	carry, res[1] = umulHop(res1, x[0], y[1])
	carry, res2 = umulStep(res2, x[1], y[1], carry)
	res3 = res3 + x[2]*y[1] + carry

	carry, res[2] = umulHop(res2, x[0], y[2])
	res3 = res3 + x[1]*y[2] + carry

	res[3] = res3 + x[0]*y[3]

	return z.Set(&res)
}

// MulOverflow multiplies x and y and reports whether the signed product exceeds int256.
// The returned value is still the wrapped low 256-bit product.
//
// Parameters:
//   - x: First signed 256-bit factor.
//   - y: Second signed 256-bit factor.
//
// Returns:
//   - z: The low 256 bits of the signed product, with its sign restored.
//   - overflow: True when the mathematical product is outside [-2^255, 2^255 - 1].
func (z *Int) MulOverflow(x, y *Int) (*Int, bool) {
	if (x.IsMinI256() && y.IsOne()) || (x.IsOne() && y.IsMinI256()) {
		return z.Set(MinInt256()), false
	}

	var flipSign bool
	xSign, ySign := x.Sign(), y.Sign()
	if xSign*ySign == -1 {
		flipSign = true
	}

	xCopy := x.Clone()
	yCopy := y.Clone()

	if xSign < 0 {
		xCopy.Neg(xCopy)
	}
	if ySign < 0 {
		yCopy.Neg(yCopy)
	}

	p := umul(xCopy, yCopy)
	z[0], z[1], z[2], z[3] = p[0], p[1], p[2], p[3]

	var overflow bool
	if (p[4] | p[5] | p[6] | p[7]) != 0 {
		overflow = true
	} else if z.IsNeg() {
		// The 256th bit is set, which means the absolute value is >= 2^255
		// This is only valid if the result should be exactly -2^255
		if !flipSign || !z.IsMinI256() {
			overflow = true
		}
	}

	if flipSign {
		z.Neg(z)
	}

	return z, overflow
}

// umul computes the full unsigned 512-bit product of the four limbs of x and y.
//
// Parameters:
//   - x: First four-limb operand, interpreted as an unsigned bit pattern.
//   - y: Second four-limb operand, interpreted as an unsigned bit pattern.
//
// Returns:
//   - product: Eight little-endian uint64 limbs containing x * y.
func umul(x, y *Int) [8]uint64 {
	var (
		res                           [8]uint64
		carry, carry4, carry5, carry6 uint64
		res1, res2, res3, res4, res5  uint64
	)

	carry, res[0] = bits.Mul64(x[0], y[0])
	carry, res1 = umulHop(carry, x[1], y[0])
	carry, res2 = umulHop(carry, x[2], y[0])
	carry4, res3 = umulHop(carry, x[3], y[0])

	carry, res[1] = umulHop(res1, x[0], y[1])
	carry, res2 = umulStep(res2, x[1], y[1], carry)
	carry, res3 = umulStep(res3, x[2], y[1], carry)
	carry5, res4 = umulStep(carry4, x[3], y[1], carry)

	carry, res[2] = umulHop(res2, x[0], y[2])
	carry, res3 = umulStep(res3, x[1], y[2], carry)
	carry, res4 = umulStep(res4, x[2], y[2], carry)
	carry6, res5 = umulStep(carry5, x[3], y[2], carry)

	carry, res[3] = umulHop(res3, x[0], y[3])
	carry, res[4] = umulStep(res4, x[1], y[3], carry)
	carry, res[5] = umulStep(res5, x[2], y[3], carry)
	res[7], res[6] = umulStep(carry6, x[3], y[3], carry)

	return res
}

// umulStep adds z and carry to the product of two uint64 words.
//
// Parameters:
//   - z: Existing low-word addend.
//   - x: First uint64 multiplicand.
//   - y: Second uint64 multiplicand.
//   - carry: Incoming carry word added to the product.
//
// Returns:
//   - hi: High uint64 word of x*y + z + carry.
//   - lo: Low uint64 word of x*y + z + carry.
func umulStep(z, x, y, carry uint64) (hi, lo uint64) {
	hi, lo = bits.Mul64(x, y)
	lo, carry = bits.Add64(lo, carry, 0)
	hi += carry
	lo, carry = bits.Add64(lo, z, 0)
	hi += carry
	return hi, lo
}

// umulHop adds z to the product of two uint64 words.
//
// Parameters:
//   - z: Existing low-word addend.
//   - x: First uint64 multiplicand.
//   - y: Second uint64 multiplicand.
//
// Returns:
//   - hi: High uint64 word of x*y + z.
//   - lo: Low uint64 word of x*y + z.
func umulHop(z, x, y uint64) (hi, lo uint64) {
	hi, lo = bits.Mul64(x, y)
	lo, carry := bits.Add64(lo, z, 0)
	hi += carry
	return hi, lo
}

// Clear sets every limb of z to zero.
//
// Returns:
//   - z: The receiver representing the signed value 0.
func (z *Int) Clear() *Int {
	z[0], z[1], z[2], z[3] = 0, 0, 0, 0
	return z
}

// SetOne sets z to the signed value 1.
//
// Returns:
//   - z: The receiver with only its least-significant bit set.
func (z *Int) SetOne() *Int {
	z[3], z[2], z[1], z[0] = 0, 0, 0, 1
	return z
}

// SetAllBitsOne sets every bit of z to one, the two's-complement representation of -1.
//
// Returns:
//   - z: The receiver containing the all-ones 256-bit pattern.
func (z *Int) SetAllBitsOne() *Int {
	z[0], z[1], z[2], z[3] = 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff
	return z
}

// Div divides signed 256-bit x by y, truncating the quotient toward zero.
//
// Parameters:
//   - x: Signed 256-bit dividend.
//   - y: Signed 256-bit divisor.
//
// Returns:
//   - z: The receiver containing the signed quotient x / y.
//
// Panics if y is zero.
func (z *Int) Div(x, y *Int) *Int {
	if x.Sign() > 0 {
		if y.Sign() > 0 {
			return z.uquo(x, y)
		}
		z.uquo(x, new(Int).Neg(y))
		return z.Neg(z)
	}
	if y.Sign() < 0 {
		return z.uquo(new(Int).Neg(x), new(Int).Neg(y))
	}
	z.uquo(new(Int).Neg(x), y)
	return z.Neg(z)
}

// uquo computes the unsigned quotient of x by y from their raw 256-bit limbs.
// It is the magnitude-division helper used by signed Div.
//
// Parameters:
//   - x: Unsigned dividend represented by an Int's four limbs.
//   - y: Non-zero unsigned divisor represented by an Int's four limbs.
//
// Returns:
//   - z: The receiver containing floor(x / y) as a 256-bit limb pattern.
//
// Panics if y is zero.
func (z *Int) uquo(x, y *Int) *Int {
	if y.IsZero() {
		panic("zero division")
	}
	if x.IsZero() {
		return z.Clear()
	}
	if x.Eq(y) {
		return z.SetOne()
	}
	if x.IsInt64() && y.IsInt64() {
		return z.SetInt64(x.Int64() / y.Int64())
	}
	quot := Int{}
	udivrem(quot[:], x[:], y)
	return z.Set(&quot)
}

// Rem computes the signed remainder of x divided by y, preserving x's sign.
//
// Parameters:
//   - x: Signed 256-bit dividend.
//   - y: Signed 256-bit divisor.
//
// Returns:
//   - z: The receiver containing x % y, with magnitude less than |y|.
//
// Panics if y is zero.
func (z *Int) Rem(x, y *Int) *Int {
	if x.Sign() > 0 {
		if y.Sign() > 0 {
			return z.urem(x, y)
		}
		return z.urem(x, new(Int).Neg(y))
	}
	if y.Sign() < 0 {
		z.urem(new(Int).Neg(x), new(Int).Neg(y))
		return z.Neg(z)
	}
	z.urem(new(Int).Neg(x), y)
	return z.Neg(z)
}

// urem computes the unsigned remainder of x divided by y from their raw limbs.
//
// Parameters:
//   - x: Unsigned dividend represented by an Int's four limbs.
//   - y: Non-zero unsigned divisor represented by an Int's four limbs.
//
// Returns:
//   - z: The receiver containing x % y, with magnitude less than y.
//
// Panics if y is zero.
func (z *Int) urem(x, y *Int) *Int {
	if y.IsZero() {
		panic("zero division")
	}
	if x.IsZero() {
		return z.Clear()
	}
	if x.Eq(y) {
		return z.Clear()
	}
	if x.IsInt64() && y.IsInt64() {
		xInt64 := x.Int64()
		yInt64 := y.Int64()
		return z.SetInt64(xInt64 % yInt64)
	}
	quot := Int{}
	rem := udivrem(quot[:], x[:], y)
	return z.Set(&rem)
}

// Lt reports whether z is less than x as signed int256 values.
//
// Parameters:
//   - x: Signed 256-bit value to compare with z.
//
// Returns:
//   - less: True when z < x.
func (z *Int) Lt(x *Int) bool {
	return z.Cmp(x) < 0
}

// Lte reports whether z is less than or equal to x as signed int256 values.
//
// Parameters:
//   - x: Signed 256-bit value to compare with z.
//
// Returns:
//   - lessOrEqual: True when z <= x.
func (z *Int) Lte(x *Int) bool {
	return z.Cmp(x) <= 0
}

// Gt reports whether z is greater than x as signed int256 values.
//
// Parameters:
//   - x: Signed 256-bit value to compare with z.
//
// Returns:
//   - greater: True when z > x.
func (z *Int) Gt(x *Int) bool {
	return z.Cmp(x) > 0
}

// Gte reports whether z is greater than or equal to x as signed int256 values.
//
// Parameters:
//   - x: Signed 256-bit value to compare with z.
//
// Returns:
//   - greaterOrEqual: True when z >= x.
func (z *Int) Gte(x *Int) bool {
	return z.Cmp(x) >= 0
}

// Cmp compares z and x as signed two's-complement int256 values.
//
// Parameters:
//   - x: Signed 256-bit value to compare with z.
//
// Returns:
//   - comparison: -1 when z < x, 0 when z == x, and 1 when z > x.
func (z *Int) Cmp(x *Int) int {
	zneg := int8(z[3] >> 63)
	xneg := int8(x[3] >> 63)
	if zneg != xneg {
		return int(xneg - zneg)
	}
	d0, carry := bits.Sub64(z[0], x[0], 0)
	d1, carry := bits.Sub64(z[1], x[1], carry)
	d2, carry := bits.Sub64(z[2], x[2], carry)
	d3, carry := bits.Sub64(z[3], x[3], carry)
	if carry == 1 {
		return -1
	}
	if d0|d1|d2|d3 == 0 {
		return 0
	}
	return 1
}

// Clone returns an independent copy of z.
//
// Returns:
//   - clone: A fresh *Int with the same four limbs as z.
func (z *Int) Clone() *Int {
	return &Int{z[0], z[1], z[2], z[3]}
}

// Or sets z to the bitwise OR of x and y.
//
// Parameters:
//   - x: First 256-bit operand.
//   - y: Second 256-bit operand.
//
// Returns:
//   - z: The receiver containing x | y.
func (z *Int) Or(x, y *Int) *Int {
	z[0] = x[0] | y[0]
	z[1] = x[1] | y[1]
	z[2] = x[2] | y[2]
	z[3] = x[3] | y[3]
	return z
}

// And sets z to the bitwise AND of x and y.
//
// Parameters:
//   - x: First 256-bit operand.
//   - y: Second 256-bit operand.
//
// Returns:
//   - z: The receiver containing x & y.
func (z *Int) And(x, y *Int) *Int {
	z[0] = x[0] & y[0]
	z[1] = x[1] & y[1]
	z[2] = x[2] & y[2]
	z[3] = x[3] & y[3]
	return z
}

// Xor sets z to the bitwise exclusive OR of x and y.
//
// Parameters:
//   - x: First 256-bit operand.
//   - y: Second 256-bit operand.
//
// Returns:
//   - z: The receiver containing x ^ y.
func (z *Int) Xor(x, y *Int) *Int {
	z[0] = x[0] ^ y[0]
	z[1] = x[1] ^ y[1]
	z[2] = x[2] ^ y[2]
	z[3] = x[3] ^ y[3]
	return z
}

// Not sets z to the bitwise complement of x.
//
// Parameters:
//   - x: 256-bit operand whose bits are complemented.
//
// Returns:
//   - z: The receiver containing ^x.
func (z *Int) Not(x *Int) *Int {
	z[0] = ^x[0]
	z[1] = ^x[1]
	z[2] = ^x[2]
	z[3] = ^x[3]
	return z
}

// Lsh sets z to x left-shifted by n bits, truncating to 256 bits.
//
// Parameters:
//   - x: 256-bit bit pattern to shift.
//   - n: Number of bit positions to shift left; n >= 256 yields zero.
//
// Returns:
//   - z: The receiver containing (x << n) modulo 2^256.
func (z *Int) Lsh(x *Int, n uint) *Int {
	if n == 0 {
		return z.Set(x)
	}
	if n >= 256 {
		return z.Clear()
	}
	// Handle exact multiples of 64 separately to avoid 64-bit shift issues
	if n&0x3f == 0 {
		switch n {
		case 64:
			z[3], z[2], z[1], z[0] = x[2], x[1], x[0], 0
		case 128:
			z[3], z[2], z[1], z[0] = x[1], x[0], 0, 0
		case 192:
			z[3], z[2], z[1], z[0] = x[0], 0, 0, 0
		}
		return z
	}
	switch {
	case n > 192:
		n -= 192
		z[3], z[2], z[1], z[0] = x[0]<<n, 0, 0, 0
	case n > 128:
		n -= 128
		z[3] = (x[1] << n) | (x[0] >> (64 - n))
		z[2] = x[0] << n
		z[1], z[0] = 0, 0
	case n > 64:
		n -= 64
		z[3] = (x[2] << n) | (x[1] >> (64 - n))
		z[2] = (x[1] << n) | (x[0] >> (64 - n))
		z[1] = x[0] << n
		z[0] = 0
	default:
		z[3] = (x[3] << n) | (x[2] >> (64 - n))
		z[2] = (x[2] << n) | (x[1] >> (64 - n))
		z[1] = (x[1] << n) | (x[0] >> (64 - n))
		z[0] = x[0] << n
	}
	return z
}

// Rsh shifts x right by n bits using signed arithmetic semantics.
// Non-negative values receive zero-fill; negative values receive sign extension.
//
// Parameters:
//   - x: Signed 256-bit value to shift.
//   - n: Number of bit positions to shift right.
//
// Returns:
//   - z: The receiver containing the arithmetic right shift of x.
func (z *Int) Rsh(x *Int, n uint) *Int {
	if n == 0 {
		return z.Set(x)
	}
	if x.IsNeg() {
		return z.negRsh(x, n)
	}
	return z.rsh(x, n)
}

// rsh performs a logical right shift of x without sign extension.
//
// Parameters:
//   - x: 256-bit bit pattern to shift.
//   - n: Number of bit positions to shift right; n >= 256 yields zero.
//
// Returns:
//   - z: The receiver containing x >> n with zero-fill.
func (z *Int) rsh(x *Int, n uint) *Int {
	if n >= 256 {
		return z.Clear()
	}
	// Handle exact multiples of 64 separately to avoid 64-bit shift issues
	if n&0x3f == 0 {
		switch n {
		case 0:
			return z.Set(x)
		case 64:
			z[3], z[2], z[1], z[0] = 0, x[3], x[2], x[1]
		case 128:
			z[3], z[2], z[1], z[0] = 0, 0, x[3], x[2]
		case 192:
			z[3], z[2], z[1], z[0] = 0, 0, 0, x[3]
		}
		return z
	}
	switch {
	case n > 192:
		n -= 192
		z[3], z[2], z[1], z[0] = 0, 0, 0, x[3]>>n
	case n > 128:
		n -= 128
		z[3], z[2] = 0, 0
		z[1] = x[3] >> n
		z[0] = (x[3] << (64 - n)) | (x[2] >> n)
	case n > 64:
		n -= 64
		z[3] = 0
		z[2] = x[3] >> n
		z[1] = (x[3] << (64 - n)) | (x[2] >> n)
		z[0] = (x[2] << (64 - n)) | (x[1] >> n)
	default:
		z[3] = x[3] >> n
		z[2] = (x[3] << (64 - n)) | (x[2] >> n)
		z[1] = (x[2] << (64 - n)) | (x[1] >> n)
		z[0] = (x[1] << (64 - n)) | (x[0] >> n)
	}
	return z
}

// negRsh performs an arithmetic right shift of a negative x with sign extension.
//
// Parameters:
//   - x: Negative 256-bit two's-complement value to shift.
//   - n: Number of bit positions to shift right; n >= 256 yields all ones.
//
// Returns:
//   - z: The receiver containing x >> n with one-fill above its sign bit.
func (z *Int) negRsh(x *Int, n uint) *Int {
	if n >= 256 {
		return z.SetAllBitsOne()
	}
	var v uint64 = 0xffffffffffffffff
	// Handle exact multiples of 64 separately to avoid 64-bit shift issues
	if n&0x3f == 0 {
		switch n {
		case 0:
			return z.Set(x)
		case 64:
			z[3], z[2], z[1], z[0] = v, x[3], x[2], x[1]
		case 128:
			z[3], z[2], z[1], z[0] = v, v, x[3], x[2]
		case 192:
			z[3], z[2], z[1], z[0] = v, v, v, x[3]
		}
		return z
	}
	switch {
	case n > 192:
		n -= 192
		z[3], z[2], z[1], z[0] = v, v, v, (v<<(64-n))|(x[3]>>n)
	case n > 128:
		n -= 128
		z[3], z[2] = v, v
		z[1] = (v << (64 - n)) | (x[3] >> n)
		z[0] = (x[3] << (64 - n)) | (x[2] >> n)
	case n > 64:
		n -= 64
		z[3] = v
		z[2] = (v << (64 - n)) | (x[3] >> n)
		z[1] = (x[3] << (64 - n)) | (x[2] >> n)
		z[0] = (x[2] << (64 - n)) | (x[1] >> n)
	default:
		z[3] = (v << (64 - n)) | (x[3] >> n)
		z[2] = (x[3] << (64 - n)) | (x[2] >> n)
		z[1] = (x[2] << (64 - n)) | (x[1] >> n)
		z[0] = (x[1] << (64 - n)) | (x[0] >> n)
	}
	return z
}

// BitLen returns the number of bits needed to represent z's raw 256-bit pattern.
//
// Returns:
//   - length: Bit length of the four-limb representation; zero has length 0 and
//     a negative value may require all 256 bits.
func (z *Int) BitLen() int {
	switch {
	case z[3] != 0:
		return 192 + bits.Len64(z[3])
	case z[2] != 0:
		return 128 + bits.Len64(z[2])
	case z[1] != 0:
		return 64 + bits.Len64(z[1])
	default:
		return bits.Len64(z[0])
	}
}

// SetBytes32 loads the first 32 bytes of in as a big-endian 256-bit value.
//
// Parameters:
//   - in: Byte slice containing at least 32 bytes, with the most-significant byte first.
//     Bytes beyond the first 32 are ignored.
//
// Returns:
//   - z: The receiver populated from the 32-byte big-endian representation.
//
// Panics if in contains fewer than 32 bytes.
func (z *Int) SetBytes32(in []byte) *Int {
	_ = in[31] // bounds check hint to compiler; see golang.org/issue/14808
	z[3] = binary.BigEndian.Uint64(in[0:8])
	z[2] = binary.BigEndian.Uint64(in[8:16])
	z[1] = binary.BigEndian.Uint64(in[16:24])
	z[0] = binary.BigEndian.Uint64(in[24:32])
	return z
}
