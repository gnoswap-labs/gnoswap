// bitwise contains bitwise operations for Uint instances.
// This file includes functions to perform bitwise AND, OR, XOR, and NOT operations, as well as bit shifting.
// These operations are crucial for manipulating individual bits within a 256-bit unsigned integer.
package uint256

// Or sets z to the bitwise OR of x and y and returns z.
//
// Parameters:
//   - x: First 256-bit operand.
//   - y: Second 256-bit operand.
//
// Returns:
//   - z: The 256-bit bitwise OR x | y, stored in the receiver.
func (z *Uint) Or(x, y *Uint) *Uint {
	z[0] = x[0] | y[0]
	z[1] = x[1] | y[1]
	z[2] = x[2] | y[2]
	z[3] = x[3] | y[3]
	return z
}

// And sets z to the bitwise AND of x and y and returns z.
//
// Parameters:
//   - x: First 256-bit operand.
//   - y: Second 256-bit operand.
//
// Returns:
//   - z: The 256-bit bitwise AND x & y, stored in the receiver.
func (z *Uint) And(x, y *Uint) *Uint {
	z[0] = x[0] & y[0]
	z[1] = x[1] & y[1]
	z[2] = x[2] & y[2]
	z[3] = x[3] & y[3]
	return z
}

// Not sets z to the bitwise complement of x and returns z.
//
// Parameters:
//   - x: 256-bit operand whose bits are complemented.
//
// Returns:
//   - z: The 256-bit bitwise complement ^x, stored in the receiver.
func (z *Uint) Not(x *Uint) *Uint {
	z[3], z[2], z[1], z[0] = ^x[3], ^x[2], ^x[1], ^x[0]
	return z
}

// AndNot sets z to x AND NOT y and returns z.
//
// Parameters:
//   - x: First 256-bit operand.
//   - y: Operand whose bits are cleared from x.
//
// Returns:
//   - z: The 256-bit bit pattern x &^ y, stored in the receiver.
func (z *Uint) AndNot(x, y *Uint) *Uint {
	z[0] = x[0] &^ y[0]
	z[1] = x[1] &^ y[1]
	z[2] = x[2] &^ y[2]
	z[3] = x[3] &^ y[3]
	return z
}

// Xor sets z to the bitwise exclusive OR of x and y and returns z.
//
// Parameters:
//   - x: First 256-bit operand.
//   - y: Second 256-bit operand.
//
// Returns:
//   - z: The 256-bit bitwise exclusive OR x ^ y, stored in the receiver.
func (z *Uint) Xor(x, y *Uint) *Uint {
	z[0] = x[0] ^ y[0]
	z[1] = x[1] ^ y[1]
	z[2] = x[2] ^ y[2]
	z[3] = x[3] ^ y[3]
	return z
}

// Lsh sets z to x left-shifted by n bits and returns z.
// Bits shifted beyond the 256-bit width are discarded; n >= 256 produces zero.
//
// Parameters:
//   - x: 256-bit operand to shift.
//   - n: Number of bit positions to shift left.
//
// Returns:
//   - z: The low 256 bits of x << n, stored in the receiver.
func (z *Uint) Lsh(x *Uint, n uint) *Uint {
	if x.IsZero() {
		return z.Clear()
	}

	if n == 0 {
		return z.Set(x)
	}

	return z.lsh(x, n)
}

// lsh performs left shift without overflow checking
func (z *Uint) lsh(x *Uint, n uint) *Uint {
	// n % 64 == 0
	if n&0x3f == 0 {
		switch n {
		case 0:
			return z.Set(x)
		case 64:
			return z.lsh64(x)
		case 128:
			return z.lsh128(x)
		case 192:
			return z.lsh192(x)
		default:
			return z.Clear()
		}
	}
	var a, b uint64
	// Big swaps first
	switch {
	case n > 192:
		z.lsh192(x)
		n -= 192
		goto sh192
	case n > 128:
		z.lsh128(x)
		n -= 128
		goto sh128
	case n > 64:
		z.lsh64(x)
		n -= 64
		goto sh64
	default:
		z.Set(x)
	}

	// remaining shifts
	a = z[0] >> (64 - n)
	z[0] = z[0] << n

sh64:
	b = z[1] >> (64 - n)
	z[1] = (z[1] << n) | a

sh128:
	a = z[2] >> (64 - n)
	z[2] = (z[2] << n) | b

sh192:
	z[3] = (z[3] << n) | a

	return z
}

// Rsh sets z to x logically right-shifted by n bits and returns z.
// Zero bits are shifted in from the left, and n >= 256 produces zero.
//
// Parameters:
//   - x: 256-bit operand to shift.
//   - n: Number of bit positions to shift right.
//
// Returns:
//   - z: The 256-bit logical right shift x >> n, stored in the receiver.
func (z *Uint) Rsh(x *Uint, n uint) *Uint {
	// n % 64 == 0
	if n&0x3f == 0 {
		switch n {
		case 0:
			return z.Set(x)
		case 64:
			return z.rsh64(x)
		case 128:
			return z.rsh128(x)
		case 192:
			return z.rsh192(x)
		default:
			return z.Clear()
		}
	}
	var a, b uint64
	// Big swaps first
	switch {
	case n > 192:
		if n > 256 {
			return z.Clear()
		}
		z.rsh192(x)
		n -= 192
		goto sh192
	case n > 128:
		z.rsh128(x)
		n -= 128
		goto sh128
	case n > 64:
		z.rsh64(x)
		n -= 64
		goto sh64
	default:
		z.Set(x)
	}

	// remaining shifts
	a = z[3] << (64 - n)
	z[3] = z[3] >> n

sh64:
	b = z[2] << (64 - n)
	z[2] = (z[2] >> n) | a

sh128:
	a = z[1] << (64 - n)
	z[1] = (z[1] >> n) | b

sh192:
	z[0] = (z[0] >> n) | a

	return z
}

// SRsh sets z to x arithmetically right-shifted by n bits and returns z.
// The top bit is treated as a sign bit: negative patterns receive one-fill,
// while non-negative patterns use the logical right shift.
//
// Parameters:
//   - x: 256-bit two's-complement bit pattern to shift.
//   - n: Number of bit positions to shift right.
//
// Returns:
//   - z: The arithmetic right shift of x, stored in the receiver; n >= 256
//     yields all ones for a negative x and zero otherwise.
func (z *Uint) SRsh(x *Uint, n uint) *Uint {
	// If the MSB is 0, SRsh is same as Rsh.
	if !x.isBitSet(255) {
		return z.Rsh(x, n)
	}
	if n%64 == 0 {
		switch n {
		case 0:
			return z.Set(x)
		case 64:
			return z.srsh64(x)
		case 128:
			return z.srsh128(x)
		case 192:
			return z.srsh192(x)
		default:
			return z.SetAllOne()
		}
	}
	var a uint64 = 18446744073709551615 << (64 - n%64)
	// Big swaps first
	switch {
	case n > 192:
		if n > 256 {
			return z.SetAllOne()
		}
		z.srsh192(x)
		n -= 192
		goto sh192
	case n > 128:
		z.srsh128(x)
		n -= 128
		goto sh128
	case n > 64:
		z.srsh64(x)
		n -= 64
		goto sh64
	default:
		z.Set(x)
	}

	// remaining shifts
	z[3], a = (z[3]>>n)|a, z[3]<<(64-n)

sh64:
	z[2], a = (z[2]>>n)|a, z[2]<<(64-n)

sh128:
	z[1], a = (z[1]>>n)|a, z[1]<<(64-n)

sh192:
	z[0] = (z[0] >> n) | a

	return z
}

func (z *Uint) lsh64(x *Uint) *Uint {
	z[3], z[2], z[1], z[0] = x[2], x[1], x[0], 0
	return z
}

func (z *Uint) lsh128(x *Uint) *Uint {
	z[3], z[2], z[1], z[0] = x[1], x[0], 0, 0
	return z
}

func (z *Uint) lsh192(x *Uint) *Uint {
	z[3], z[2], z[1], z[0] = x[0], 0, 0, 0
	return z
}

func (z *Uint) rsh64(x *Uint) *Uint {
	z[3], z[2], z[1], z[0] = 0, x[3], x[2], x[1]
	return z
}

func (z *Uint) rsh128(x *Uint) *Uint {
	z[3], z[2], z[1], z[0] = 0, 0, x[3], x[2]
	return z
}

func (z *Uint) rsh192(x *Uint) *Uint {
	z[3], z[2], z[1], z[0] = 0, 0, 0, x[3]
	return z
}

func (z *Uint) srsh64(x *Uint) *Uint {
	z[3], z[2], z[1], z[0] = 18446744073709551615, x[3], x[2], x[1]
	return z
}

func (z *Uint) srsh128(x *Uint) *Uint {
	z[3], z[2], z[1], z[0] = 18446744073709551615, 18446744073709551615, x[3], x[2]
	return z
}

func (z *Uint) srsh192(x *Uint) *Uint {
	z[3], z[2], z[1], z[0] = 18446744073709551615, 18446744073709551615, 18446744073709551615, x[3]
	return z
}
