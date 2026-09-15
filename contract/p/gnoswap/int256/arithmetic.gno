package int256

import "math/bits"

// udivrem divides an unsigned multi-word dividend by a four-word divisor.
//
// Parameters:
//   - quot: Destination word slice that receives the quotient in little-endian limb order.
//   - u: Unsigned dividend words in little-endian limb order; the slice may be normalized in place.
//   - d: Non-zero *Int whose limbs are treated as an unsigned divisor.
//
// Returns:
//   - rem: Non-negative remainder represented in the Int's low limbs.
//
// The quotient destination must be large enough for the computed quotient.
func udivrem(quot, u []uint64, d *Int) (rem Int) {
	var dLen int
	for i := len(d) - 1; i >= 0; i-- {
		if d[i] != 0 {
			dLen = i + 1
			break
		}
	}

	shift := uint(bits.LeadingZeros64(d[dLen-1]))

	var dnStorage Int
	dn := dnStorage[:dLen]
	for i := dLen - 1; i > 0; i-- {
		dn[i] = (d[i] << shift) | (d[i-1] >> (64 - shift))
	}
	dn[0] = d[0] << shift

	var uLen int
	for i := len(u) - 1; i >= 0; i-- {
		if u[i] != 0 {
			uLen = i + 1
			break
		}
	}

	if uLen < dLen {
		copy(rem[:], u)
		return rem
	}

	var unStorage [9]uint64
	un := unStorage[:uLen+1]
	un[uLen] = u[uLen-1] >> (64 - shift)
	for i := uLen - 1; i > 0; i-- {
		un[i] = (u[i] << shift) | (u[i-1] >> (64 - shift))
	}
	un[0] = u[0] << shift

	if dLen == 1 {
		r := udivremBy1(quot, un, dn[0])
		rem.SetUint64(r >> shift)
		return rem
	}

	udivremKnuth(quot, un, dn)

	for i := 0; i < dLen-1; i++ {
		rem[i] = (un[i] >> shift) | (un[i+1] << (64 - shift))
	}
	rem[dLen-1] = un[dLen-1] >> shift

	return rem
}

// udivremBy1 divides a multi-word unsigned dividend by a single uint64 word.
//
// Parameters:
//   - quot: Destination word slice receiving quotient limbs in little-endian order.
//   - u: Unsigned dividend words in little-endian order; its top word is processed first.
//   - d: Non-zero single-word divisor.
//
// Returns:
//   - rem: Unsigned remainder in the range [0, d).
func udivremBy1(quot, u []uint64, d uint64) (rem uint64) {
	reciprocal := reciprocal2by1(d)
	rem = u[len(u)-1]
	for j := len(u) - 2; j >= 0; j-- {
		quot[j], rem = udivrem2by1(rem, u[j], d, reciprocal)
	}
	return rem
}

// udivremKnuth performs the normalized multi-word division step used by udivrem.
// It updates the dividend workspace while estimating and correcting each quotient word.
//
// Parameters:
//   - quot: Destination for quotient words in little-endian order.
//   - u: Normalized dividend workspace, modified during subtraction and correction.
//   - d: Normalized multi-word divisor with at least two words.
func udivremKnuth(quot, u, d []uint64) {
	dLen := len(d)
	dh := d[dLen-1]
	dl := d[dLen-2]
	reciprocal := reciprocal2by1(dh)

	for j := len(u) - dLen - 1; j >= 0; j-- {
		u2 := u[j+dLen]
		u1 := u[j+dLen-1]
		u0 := u[j+dLen-2]

		var qhat, rhat uint64
		if u2 >= dh {
			qhat = ^uint64(0)
		} else {
			qhat, rhat = udivrem2by1(u2, u1, dh, reciprocal)
			ph, pl := bits.Mul64(qhat, dl)
			if ph > rhat || (ph == rhat && pl > u0) {
				qhat--
			}
		}

		borrow := subMulTo(u[j:], d, qhat)
		u[j+dLen] = u2 - borrow
		if u2 < borrow {
			qhat--
			u[j+dLen] += addTo(u[j:], d)
		}

		quot[j] = qhat
	}
}

// reciprocal2by1 computes the reciprocal estimate used by two-word division.
//
// Parameters:
//   - d: Non-zero high divisor word used to form the reciprocal estimate.
//
// Returns:
//   - reciprocal: Reciprocal estimate for the 128-by-64-bit division step.
func reciprocal2by1(d uint64) uint64 {
	reciprocal, _ := bits.Div64(^d, ^uint64(0), d)
	return reciprocal
}

// udivrem2by1 divides a two-word unsigned numerator by one uint64 word.
//
// Parameters:
//   - uh: High 64-bit word of the unsigned numerator.
//   - ul: Low 64-bit word of the unsigned numerator.
//   - d: Non-zero uint64 divisor.
//   - reciprocal: Reciprocal estimate for d returned by reciprocal2by1.
//
// Returns:
//   - quot: Quotient word for (uh<<64 | ul) / d.
//   - rem: Remainder word in the range [0, d).
func udivrem2by1(uh, ul, d, reciprocal uint64) (quot, rem uint64) {
	qh, ql := bits.Mul64(reciprocal, uh)
	ql, carry := bits.Add64(ql, ul, 0)
	qh += uh + carry
	qh++

	r := ul - qh*d

	if r > ql {
		qh--
		r += d
	}

	if r >= d {
		qh++
		r -= d
	}

	return qh, r
}

// subMulTo subtracts multiplier*y from x in place, one little-endian word at a time.
//
// Parameters:
//   - x: Destination word slice whose low words are reduced in place.
//   - y: Little-endian multiplicand words; x must have at least len(y) words.
//   - multiplier: Unsigned word multiplier applied to every y word.
//
// Returns:
//   - borrow: Carry-out borrow remaining after subtracting the product.
func subMulTo(x, y []uint64, multiplier uint64) uint64 {
	var borrow uint64
	for i := 0; i < len(y); i++ {
		s, carry1 := bits.Sub64(x[i], borrow, 0)
		ph, pl := bits.Mul64(y[i], multiplier)
		t, carry2 := bits.Sub64(s, pl, 0)
		x[i] = t
		borrow = ph + carry1 + carry2
	}
	return borrow
}

// addTo adds y to x in place using little-endian words.
//
// Parameters:
//   - x: Destination word slice updated with the low-word sum.
//   - y: Addend words in little-endian order; x must have at least len(y) words.
//
// Returns:
//   - carry: Final carry word, zero when the addition fits in x's supplied words.
func addTo(x, y []uint64) uint64 {
	var carry uint64
	for i := 0; i < len(y); i++ {
		x[i], carry = bits.Add64(x[i], y[i], carry)
	}
	return carry
}
