package int256

import (
	"errors"
	"math/bits"
	"strconv"

	u256 "gno.land/p/gnoswap/uint256"
)

const (
	maxAbsI256Dec = "57896044618658097711785492504343953926634992332820282019728792003956564819968"
	maxWords      = 256 / bits.UintSize
)

var (
	ErrOverflow                    = errors.New("int256: overflow")
	ErrEmptyString                 = errors.New("int256: empty string")
	ErrInvalidCharacter            = errors.New("int256: invalid character")
	ErrInvalidSignInMiddleOfNumber = errors.New("int256: invalid sign in middle of number")

	multipliers = [5]*Int{
		nil,
		{0x8ac7230489e80000, 0, 0, 0},
		{0x98a224000000000, 0x4b3b4ca85a86c47a, 0, 0},
		{0x4a00000000000000, 0xebfdcb54864ada83, 0x28c87cb5c89a2571, 0},
		{0, 0x7775a5f171951000, 0x764b4abe8652979, 0x161bcca7119915b5},
	}
)

func FromDecimal(decimal string) (*Int, error) {
	z, err := new(Int).SetString(decimal)
	if err != nil {
		return nil, err
	}

	return z, nil
}

func MustFromDecimal(decimal string) *Int {
	z, err := FromDecimal(decimal)
	if err != nil {
		panic(err)
	}
	return z
}

func (z *Int) ToString() string {
	s := z.Sign()
	if s == 0 {
		return "0"
	}
	if z.IsInt64() {
		return strconv.FormatInt(z.Int64(), 10)
	}
	y := new(Int)
	if s > 0 {
		y.Set(z)
	} else {
		y.Neg(z)
	}
	var (
		out     = []byte("00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
		divisor = new(Int).SetUint64(10000000000000000000)
		pos     = len(out)
		buf     = make([]byte, 0, 19)
	)

	for {
		var quot Int
		rem := udivrem(quot[:], y[:], divisor)
		y.Set(&quot)
		buf = strconv.AppendUint(buf[:0], rem.Uint64(), 10)
		copy(out[pos-len(buf):], buf)
		if y.IsZero() {
			break
		}
		pos -= 19
	}

	var res string
	if s < 0 {
		res = "-"
	}
	res += string(out[pos-len(buf):])
	return res
}

func (z *Int) SetString(s string) (*Int, error) {
	if len(s) == 0 {
		return nil, ErrEmptyString
	}

	isNeg := false
	switch s[0] {
	case '+':
		s = s[1:]
	case '-':
		isNeg = true
		s = s[1:]
	}

	if len(s) == 0 {
		return nil, ErrEmptyString
	}

	// Parallel comparison technique for validation
	// Process in 8-byte chunks for optimal performance
	sLen := len(s)
	i := 0

	// Process 8 bytes at a time
	for i+7 < sLen {
		// Access up to s[i+7] is safe, then we can reduce the number of bounds checks
		_ = s[i+7]

		// Convert 8 bytes into a single uint64
		// This method processes bytes directly, so no endianness issues
		chunk := uint64(s[i]) | uint64(s[i+1])<<8
		chunk |= uint64(s[i+2])<<16 | uint64(s[i+3])<<24
		chunk |= uint64(s[i+4])<<32 | uint64(s[i+5])<<40
		chunk |= uint64(s[i+6])<<48 | uint64(s[i+7])<<56

		// Check for '+' (0x2B) using SWAR technique
		// Subtracting 0x2B from each byte makes '+' bytes become 0
		// Subtracting 0x01 makes bytes in ASCII range (0-127) have 0 in their highest bit
		// Therefore, AND with 0x80 to check for zero bytes
		plusTest := ((chunk ^ 0x2B2B2B2B2B2B2B2B) - 0x0101010101010101) & 0x8080808080808080

		// Check for '-' (0x2D) using SWAR technique
		minusTest := ((chunk ^ 0x2D2D2D2D2D2D2D2D) - 0x0101010101010101) & 0x8080808080808080

		// If either test is non-zero, a sign character exists
		if (plusTest | minusTest) != 0 {
			return nil, ErrInvalidSignInMiddleOfNumber
		}

		i += 8
	}

	// Process remaining bytes
	for ; i < sLen; i++ {
		if s[i] == '+' || s[i] == '-' {
			return nil, ErrInvalidSignInMiddleOfNumber
		}
	}

	// Strip leading zeros
	if len(s) > 0 && s[0] == '0' {
		idx := 0
		for idx < len(s) && s[idx] == '0' {
			idx++
		}
		s = s[idx:]
		// If all characters were zeros, set to "0"
		if len(s) == 0 {
			s = "0"
		}
	}

	// Check for overflow
	if len(s) > len(maxAbsI256Dec) ||
		(len(s) == len(maxAbsI256Dec) && s > maxAbsI256Dec) ||
		(s == maxAbsI256Dec && !isNeg) {
		return nil, ErrOverflow
	}

	if err := z.fromDecimal(s); err != nil {
		return nil, err
	}

	if isNeg {
		z.Neg(z)
	}

	return z, nil
}

func (z *Int) fromDecimal(bs string) error {
	z.Clear()
	var (
		num       uint64
		err       error
		remaining = len(bs)
	)

	if remaining == 0 {
		return errors.New("EOF")
	}

	for i, mult := range multipliers {
		if remaining <= 0 {
			return nil
		}
		if remaining > 19 {
			num, err = strconv.ParseUint(bs[remaining-19:remaining], 10, 64)
		} else {
			num, err = strconv.ParseUint(bs, 10, 64)
		}
		if err != nil {
			return err
		}
		if i == 0 {
			z.SetUint64(num)
		} else {
			base := new(Int).SetUint64(num)
			z.Add(z, base.Mul(base, mult))
		}
		if remaining > 19 {
			bs = bs[0 : remaining-19]
		}
		remaining -= 19
	}
	return nil
}

// FromUint256 converts a uint256 to int256.
// Panics if the uint256 value is greater than MaxInt256 (2^255 - 1).
func FromUint256(x *u256.Uint) *Int {
	// Check overflow: if MSB of x[3] is set, value > MaxInt256
	if x[3] > 0x7fffffffffffffff {
		panic("int256: overflow - uint256 value exceeds MaxInt256")
	}
	z := &Int{}
	z[0] = x[0]
	z[1] = x[1]
	z[2] = x[2]
	z[3] = x[3]
	return z
}

