package uint256

import (
	"errors"
	"math/bits"
	"strconv"
)

const (
	MaxUint64   = 1<<64 - 1
	MAX_UINT256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
)

var (
	zero  = Zero()
	one   = One()
	two   = NewUint(2)
	three = NewUint(3)
)

// Uint represents a 256-bit unsigned integer.
// It is stored as an array of 4 uint64 in little-endian order,
// where arr[0] is the least significant and arr[3] is the most significant.
type Uint struct {
	arr [4]uint64
}

// NewUint returns a new Uint initialized with the given uint64 value.
func NewUint(val uint64) *Uint {
	return &Uint{arr: [4]uint64{val, 0, 0, 0}}
}

// NewUintFromInt64 returns a new Uint initialized with the given int64 value.
// Panics if val is negative.
func NewUintFromInt64(val int64) *Uint {
	if val < 0 {
		panic("val is negative")
	}
	return NewUint(uint64(val))
}

// Zero returns a new Uint with value 0.
func Zero() *Uint {
	return NewUint(0)
}

// One returns a new Uint with value 1.
func One() *Uint {
	return NewUint(1)
}

// SetAllOne sets z to the maximum 256-bit value (all bits set to 1) and returns z.
func (z *Uint) SetAllOne() *Uint {
	z.arr[3], z.arr[2], z.arr[1], z.arr[0] = MaxUint64, MaxUint64, MaxUint64, MaxUint64
	return z
}

// Set sets z to x and returns z.
func (z *Uint) Set(x *Uint) *Uint {
	*z = *x
	return z
}

// SetOne sets z to 1 and returns z.
func (z *Uint) SetOne() *Uint {
	z.arr[3], z.arr[2], z.arr[1], z.arr[0] = 0, 0, 0, 1
	return z
}

// SetFromDecimal sets z from a decimal string and returns an error if invalid.
// Accepts an optional leading "+" sign but rejects underscores and negative values.
// Returns ErrBig256Range if the number exceeds 256 bits.
func (z *Uint) SetFromDecimal(s string) (err error) {
	// Remove max one leading +
	if len(s) > 0 && s[0] == '+' {
		s = s[1:]
	}
	// Remove any number of leading zeroes
	if len(s) > 0 && s[0] == '0' {
		var i int
		var c rune
		for i, c = range s {
			if c != '0' {
				break
			}
		}
		s = s[i:]
	}
	if len(s) < len(MAX_UINT256) {
		return z.fromDecimal(s)
	}
	if len(s) == len(MAX_UINT256) {
		if s > MAX_UINT256 {
			return ErrBig256Range
		}
		return z.fromDecimal(s)
	}
	return ErrBig256Range
}

// FromDecimal creates a new Uint from a decimal string.
// Returns an error if the number exceeds 256 bits or is invalid.
func FromDecimal(decimal string) (*Uint, error) {
	var z Uint
	if err := z.SetFromDecimal(decimal); err != nil {
		return nil, err
	}
	return &z, nil
}

// MustFromDecimal creates a new Uint from a decimal string.
// Panics if the string is invalid or the number exceeds 256 bits.
func MustFromDecimal(decimal string) *Uint {
	var z Uint
	if err := z.SetFromDecimal(decimal); err != nil {
		panic(err)
	}
	return &z
}

// multipliers holds the values that are needed for fromDecimal
var multipliers = [5]*Uint{
	nil, // represents first round, no multiplication needed
	{[4]uint64{10000000000000000000, 0, 0, 0}},                                     // 10 ^ 19
	{[4]uint64{687399551400673280, 5421010862427522170, 0, 0}},                     // 10 ^ 38
	{[4]uint64{5332261958806667264, 17004971331911604867, 2938735877055718769, 0}}, // 10 ^ 57
	{[4]uint64{0, 8607968719199866880, 532749306367912313, 1593091911132452277}},   // 10 ^ 76
}

// fromDecimal parses a decimal string by processing it in 19-character chunks.
// Each chunk is multiplied by the appropriate power of 10 and accumulated.
func (z *Uint) fromDecimal(bs string) error {
	// first clear the input
	z.Clear()
	// the maximum value of uint64 is 18446744073709551615, which is 20 characters
	// one less means that a string of 19 9's is always within the uint64 limit
	var (
		num       uint64
		err       error
		remaining = len(bs)
	)
	if remaining == 0 {
		return errors.New("EOF")
	}
	// We proceed in steps of 19 characters (nibbles), from least significant to most significant.
	// This means that the first (up to) 19 characters do not need to be multiplied.
	// In the second iteration, our slice of 19 characters needs to be multipleied
	// by a factor of 10^19. Et cetera.
	for i, mult := range multipliers {
		if remaining <= 0 {
			return nil // Done
		}
		if remaining > 19 {
			num, err = strconv.ParseUint(bs[remaining-19:remaining], 10, 64)
		} else {
			// Final round
			num, err = strconv.ParseUint(bs, 10, 64)
		}
		if err != nil {
			return err
		}
		// add that number to our running total
		if i == 0 {
			z.SetUint64(num)
		} else {
			base := NewUint(num)
			// Check for overflow in multiplication
			mulResult, overflow := new(Uint).MulOverflow(base, mult)
			if overflow {
				return ErrBig256Range
			}
			// Check for overflow in addition
			addResult, overflow := new(Uint).AddOverflow(z, mulResult)
			if overflow {
				return ErrBig256Range
			}
			z.Set(addResult)
		}
		// Chop off another 19 characters
		if remaining > 19 {
			bs = bs[0 : remaining-19]
		}
		remaining -= 19
	}
	return nil
}

// Byte returns the value of the byte at position n as a Uint.
// Position n is counted from the right (0 = least significant byte).
// Returns 0 if n >= 32.
func (z *Uint) Byte(n *Uint) *Uint {
	// in z, z.arr[0] is the least significant
	if number, overflow := n.Uint64WithOverflow(); !overflow {
		if number < 32 {
			number := z.arr[4-1-number/8]
			offset := (n.arr[0] & 0x7) << 3 // 8*(n.d % 8)
			z.arr[0] = (number & (0xff00000000000000 >> offset)) >> (56 - offset)
			z.arr[3], z.arr[2], z.arr[1] = 0, 0, 0
			return z
		}
	}

	return z.Clear()
}

// BitLen returns the number of bits required to represent z.
// BitLen(0) returns 0.
func (z *Uint) BitLen() int {
	switch {
	case z.arr[3] != 0:
		return 192 + bits.Len64(z.arr[3])
	case z.arr[2] != 0:
		return 128 + bits.Len64(z.arr[2])
	case z.arr[1] != 0:
		return 64 + bits.Len64(z.arr[1])
	default:
		return bits.Len64(z.arr[0])
	}
}

// ByteLen returns the number of bytes required to represent z.
// ByteLen(0) returns 0.
func (z *Uint) ByteLen() int {
	return (z.BitLen() + 7) / 8
}

// Clear sets z to 0 and returns z.
func (z *Uint) Clear() *Uint {
	z.arr[3], z.arr[2], z.arr[1], z.arr[0] = 0, 0, 0, 0
	return z
}

const (
	// hextable  = "0123456789abcdef"
	bintable  = "\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x00\x01\x02\x03\x04\x05\x06\a\b\t\xff\xff\xff\xff\xff\xff\xff\n\v\f\r\x0e\x0f\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\n\v\f\r\x0e\x0f\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"
	badNibble = 0xff
)

// SetFromHex sets z from a hexadecimal string and returns an error if invalid.
// Requires "0x" or "0X" prefix and rejects leading zeros after prefix, underscores, and negative values.
// Returns ErrBig256Range if the number exceeds 256 bits.
func (z *Uint) SetFromHex(hex string) error {
	return z.fromHex(hex)
}

// fromHex parses a hex-string into z.
func (z *Uint) fromHex(hex string) error {
	if err := checkNumberS(hex); err != nil {
		return err
	}
	if len(hex) > 66 {
		return ErrBig256Range
	}
	z.Clear()
	end := len(hex)
	for i := 0; i < 4; i++ {
		start := end - 16
		if start < 2 {
			start = 2
		}
		for ri := start; ri < end; ri++ {
			nib := bintable[hex[ri]]
			if nib == badNibble {
				return ErrSyntax
			}
			z.arr[i] = z.arr[i] << 4
			z.arr[i] += uint64(nib)
		}
		end = start
	}
	return nil
}

// FromHex creates a new Uint from a hexadecimal string.
// The string must be 0x-prefixed and represent a value within 256 bits.
func FromHex(hex string) (*Uint, error) {
	var z Uint
	if err := z.fromHex(hex); err != nil {
		return nil, err
	}
	return &z, nil
}

// MustFromHex creates a new Uint from a hexadecimal string.
// Panics if the string is invalid or the number exceeds 256 bits.
func MustFromHex(hex string) *Uint {
	var z Uint
	if err := z.fromHex(hex); err != nil {
		panic(err)
	}
	return &z
}

// Clone returns a new Uint with the same value as z.
func (z *Uint) Clone() *Uint {
	var x Uint
	x.arr[0] = z.arr[0]
	x.arr[1] = z.arr[1]
	x.arr[2] = z.arr[2]
	x.arr[3] = z.arr[3]

	return &x
}
