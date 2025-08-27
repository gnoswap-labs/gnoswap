// conversions contains methods for converting Uint instances to other types and vice versa.
// This includes conversions to and from basic types such as uint64 and int32, as well as string representations
// and byte slices. Additionally, it covers marshaling and unmarshaling for JSON and other text formats.
package uint256

import (
	"encoding/binary"
	"errors"
	"strconv"
	"strings"
)

// Uint64 returns the lower 64 bits of z as a uint64.
func (z *Uint) Uint64() uint64 {
	return z.arr[0]
}

// Int64 returns the lower 64 bits of z as an int64.
func (z *Uint) Int64() int64 {
	return int64(z.Uint64())
}

// Uint64WithOverflow returns the lower 64 bits of z and true if overflow occurred.
func (z *Uint) Uint64WithOverflow() (uint64, bool) {
	return z.arr[0], (z.arr[1] | z.arr[2] | z.arr[3]) != 0
}

// SetUint64 sets z to the value of x and returns z.
func (z *Uint) SetUint64(x uint64) *Uint {
	z.arr[3], z.arr[2], z.arr[1], z.arr[0] = 0, 0, 0, x
	return z
}

// IsUint64 reports whether z can be represented as a uint64.
func (z *Uint) IsUint64() bool {
	return (z.arr[1] | z.arr[2] | z.arr[3]) == 0
}

// Dec returns the decimal representation of z.
func (z *Uint) Dec() string {
	if z.IsZero() {
		return "0"
	}
	if z.IsUint64() {
		return strconv.FormatUint(z.Uint64(), 10)
	}

	// The max uint64 value being 18446744073709551615, the largest
	// power-of-ten below that is 10000000000000000000.
	// When we do a DivMod using that number, the remainder that we
	// get back is the lower part of the output.
	//
	// The ascii-output of remainder will never exceed 19 bytes (since it will be
	// below 10000000000000000000).
	//
	// Algorithm example using 100 as divisor
	//
	// 12345 % 100 = 45   (rem)
	// 12345 / 100 = 123  (quo)
	// -> output '45', continue iterate on 123
	var (
		// out is 98 bytes long: 78 (max size of a string without leading zeroes,
		// plus slack so we can copy 19 bytes every iteration).
		// We init it with zeroes, because when strconv appends the ascii representations,
		// it will omit leading zeroes.
		out     = []byte("00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
		divisor = NewUint(10000000000000000000) // 20 digits
		y       = new(Uint).Set(z)              // copy to avoid modifying z
		pos     = len(out)                      // position to write to
		buf     = make([]byte, 0, 19)           // buffer to write uint64:s to
	)
	for {
		// Obtain Q and R for divisor
		var quot Uint
		rem := udivrem(quot.arr[:], y.arr[:], divisor)
		y.Set(&quot) // Set Q for next loop
		// Convert the R to ascii representation
		buf = strconv.AppendUint(buf[:0], rem.Uint64(), 10)
		// Copy in the ascii digits
		copy(out[pos-len(buf):], buf)
		if y.IsZero() {
			break
		}
		// Move 19 digits left
		pos -= 19
	}
	// skip leading zeroes by only using the 'used size' of buf
	return string(out[pos-len(buf):])
}

// Scan implements the database/sql Scanner interface.
// Supports scanning from strings, byte slices, and numeric types. Sets z to 0 if src is nil.
func (z *Uint) Scan(src any) error {
	if src == nil {
		z.Clear()
		return nil
	}

	switch src := src.(type) {
	case string:
		return z.scanScientificFromString(src)
	case []byte:
		return z.scanScientificFromString(string(src))
	}
	return errors.New("default // unsupported type: can't convert to uint256.Uint")
}

func (z *Uint) scanScientificFromString(src string) error {
	if len(src) == 0 {
		z.Clear()
		return nil
	}

	idx := strings.IndexByte(src, 'e')
	if idx == -1 {
		return z.SetFromDecimal(src)
	}
	if err := z.SetFromDecimal(src[:idx]); err != nil {
		return err
	}
	if src[(idx+1):] == "0" {
		return nil
	}
	exp := new(Uint)
	if err := exp.SetFromDecimal(src[(idx + 1):]); err != nil {
		return err
	}
	if exp.GtUint64(77) { // 10**78 is larger than 2**256
		return ErrBig256Range
	}
	exp.Exp(NewUint(10), exp)
	if _, overflow := z.MulOverflow(z, exp); overflow {
		return ErrBig256Range
	}
	return nil
}

// ToString returns the decimal string representation of z.
// Returns an empty string if z is nil. This method doesn't exist in holiman's uint256.
func (z *Uint) ToString() string {
	if z == nil {
		return ""
	}

	return z.Dec()
}

// MarshalJSON implements json.Marshaler by marshaling z as a decimal string.
// This differs from big.Int which uses JSON's native numeric format.
// Uses string format to avoid JavaScript's 53-bit integer precision limitations.
func (z *Uint) MarshalJSON() ([]byte, error) {
	return []byte(`"` + z.Dec() + `"`), nil
}

// UnmarshalJSON implements json.Unmarshaler.
// Accepts quoted strings (hexadecimal or decimal) or unquoted strings (decimal only).
func (z *Uint) UnmarshalJSON(input []byte) error {
	if len(input) < 2 || input[0] != '"' || input[len(input)-1] != '"' {
		// if not quoted, it must be decimal
		return z.fromDecimal(string(input))
	}
	return z.UnmarshalText(input[1 : len(input)-1])
}

// MarshalText implements encoding.TextMarshaler by marshaling z as a decimal string.
// Compatible with big.Int's text marshaling format.
func (z *Uint) MarshalText() ([]byte, error) {
	return []byte(z.Dec()), nil
}

// UnmarshalText implements encoding.TextUnmarshaler.
// Accepts decimal strings or hexadecimal strings prefixed with 0x or 0X.
func (z *Uint) UnmarshalText(input []byte) error {
	if len(input) >= 2 && input[0] == '0' && (input[1] == 'x' || input[1] == 'X') {
		return z.fromHex(string(input))
	}
	return z.fromDecimal(string(input))
}

// SetBytes interprets buf as a big-endian unsigned integer and sets z to that value.
// If buf is larger than 32 bytes, uses only the last 32 bytes. Returns z.
func (z *Uint) SetBytes(buf []byte) *Uint {
	switch l := len(buf); l {
	case 0:
		z.Clear()
	case 1:
		z.SetBytes1(buf)
	case 2:
		z.SetBytes2(buf)
	case 3:
		z.SetBytes3(buf)
	case 4:
		z.SetBytes4(buf)
	case 5:
		z.SetBytes5(buf)
	case 6:
		z.SetBytes6(buf)
	case 7:
		z.SetBytes7(buf)
	case 8:
		z.SetBytes8(buf)
	case 9:
		z.SetBytes9(buf)
	case 10:
		z.SetBytes10(buf)
	case 11:
		z.SetBytes11(buf)
	case 12:
		z.SetBytes12(buf)
	case 13:
		z.SetBytes13(buf)
	case 14:
		z.SetBytes14(buf)
	case 15:
		z.SetBytes15(buf)
	case 16:
		z.SetBytes16(buf)
	case 17:
		z.SetBytes17(buf)
	case 18:
		z.SetBytes18(buf)
	case 19:
		z.SetBytes19(buf)
	case 20:
		z.SetBytes20(buf)
	case 21:
		z.SetBytes21(buf)
	case 22:
		z.SetBytes22(buf)
	case 23:
		z.SetBytes23(buf)
	case 24:
		z.SetBytes24(buf)
	case 25:
		z.SetBytes25(buf)
	case 26:
		z.SetBytes26(buf)
	case 27:
		z.SetBytes27(buf)
	case 28:
		z.SetBytes28(buf)
	case 29:
		z.SetBytes29(buf)
	case 30:
		z.SetBytes30(buf)
	case 31:
		z.SetBytes31(buf)
	default:
		z.SetBytes32(buf[l-32:])
	}
	return z
}

// SetBytes1 sets z from a 1-byte big-endian slice and returns z.
// Panics if input is shorter than 1 byte.
func (z *Uint) SetBytes1(in []byte) *Uint {
	z.arr[3], z.arr[2], z.arr[1] = 0, 0, 0
	z.arr[0] = uint64(in[0])
	return z
}

// SetBytes2 sets z from a 2-byte big-endian slice and returns z.
// Panics if input is shorter than 2 bytes.
func (z *Uint) SetBytes2(in []byte) *Uint {
	_ = in[1] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2], z.arr[1] = 0, 0, 0
	z.arr[0] = uint64(binary.BigEndian.Uint16(in[0:2]))
	return z
}

// SetBytes3 sets z from a 3-byte big-endian slice and returns z.
// Panics if input is shorter than 3 bytes.
func (z *Uint) SetBytes3(in []byte) *Uint {
	_ = in[2] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2], z.arr[1] = 0, 0, 0
	z.arr[0] = uint64(binary.BigEndian.Uint16(in[1:3])) | uint64(in[0])<<16
	return z
}

// SetBytes4 sets z from a 4-byte big-endian slice and returns z.
// Panics if input is shorter than 4 bytes.
func (z *Uint) SetBytes4(in []byte) *Uint {
	_ = in[3] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2], z.arr[1] = 0, 0, 0
	z.arr[0] = uint64(binary.BigEndian.Uint32(in[0:4]))
	return z
}

// SetBytes5 sets z from a 5-byte big-endian slice and returns z.
// Panics if input is shorter than 5 bytes.
func (z *Uint) SetBytes5(in []byte) *Uint {
	_ = in[4] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2], z.arr[1] = 0, 0, 0
	z.arr[0] = bigEndianUint40(in[0:5])
	return z
}

// SetBytes6 sets z from a 6-byte big-endian slice and returns z.
// Panics if input is shorter than 6 bytes.
func (z *Uint) SetBytes6(in []byte) *Uint {
	_ = in[5] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2], z.arr[1] = 0, 0, 0
	z.arr[0] = bigEndianUint48(in[0:6])
	return z
}

// SetBytes7 sets z from a 7-byte big-endian slice and returns z.
// Panics if input is shorter than 7 bytes.
func (z *Uint) SetBytes7(in []byte) *Uint {
	_ = in[6] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2], z.arr[1] = 0, 0, 0
	z.arr[0] = bigEndianUint56(in[0:7])
	return z
}

// SetBytes8 sets z from an 8-byte big-endian slice and returns z.
// Panics if input is shorter than 8 bytes.
func (z *Uint) SetBytes8(in []byte) *Uint {
	_ = in[7] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2], z.arr[1] = 0, 0, 0
	z.arr[0] = binary.BigEndian.Uint64(in[0:8])
	return z
}

// SetBytes9 sets z from a 9-byte big-endian slice and returns z.
// Panics if input is shorter than 9 bytes.
func (z *Uint) SetBytes9(in []byte) *Uint {
	_ = in[8] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2] = 0, 0
	z.arr[1] = uint64(in[0])
	z.arr[0] = binary.BigEndian.Uint64(in[1:9])
	return z
}

// SetBytes10 sets z from a 10-byte big-endian slice and returns z.
// Panics if input is shorter than 10 bytes.
func (z *Uint) SetBytes10(in []byte) *Uint {
	_ = in[9] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2] = 0, 0
	z.arr[1] = uint64(binary.BigEndian.Uint16(in[0:2]))
	z.arr[0] = binary.BigEndian.Uint64(in[2:10])
	return z
}

// SetBytes11 sets z from an 11-byte big-endian slice and returns z.
// Panics if input is shorter than 11 bytes.
func (z *Uint) SetBytes11(in []byte) *Uint {
	_ = in[10] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2] = 0, 0
	z.arr[1] = uint64(binary.BigEndian.Uint16(in[1:3])) | uint64(in[0])<<16
	z.arr[0] = binary.BigEndian.Uint64(in[3:11])
	return z
}

// SetBytes12 sets z from a 12-byte big-endian slice and returns z.
// Panics if input is shorter than 12 bytes.
func (z *Uint) SetBytes12(in []byte) *Uint {
	_ = in[11] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2] = 0, 0
	z.arr[1] = uint64(binary.BigEndian.Uint32(in[0:4]))
	z.arr[0] = binary.BigEndian.Uint64(in[4:12])
	return z
}

// SetBytes13 sets z from a 13-byte big-endian slice and returns z.
// Panics if input is shorter than 13 bytes.
func (z *Uint) SetBytes13(in []byte) *Uint {
	_ = in[12] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2] = 0, 0
	z.arr[1] = bigEndianUint40(in[0:5])
	z.arr[0] = binary.BigEndian.Uint64(in[5:13])
	return z
}

// SetBytes14 sets z from a 14-byte big-endian slice and returns z.
// Panics if input is shorter than 14 bytes.
func (z *Uint) SetBytes14(in []byte) *Uint {
	_ = in[13] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2] = 0, 0
	z.arr[1] = bigEndianUint48(in[0:6])
	z.arr[0] = binary.BigEndian.Uint64(in[6:14])
	return z
}

// SetBytes15 sets z from a 15-byte big-endian slice and returns z.
// Panics if input is shorter than 15 bytes.
func (z *Uint) SetBytes15(in []byte) *Uint {
	_ = in[14] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2] = 0, 0
	z.arr[1] = bigEndianUint56(in[0:7])
	z.arr[0] = binary.BigEndian.Uint64(in[7:15])
	return z
}

// SetBytes16 sets z from a 16-byte big-endian slice and returns z.
// Panics if input is shorter than 16 bytes.
func (z *Uint) SetBytes16(in []byte) *Uint {
	_ = in[15] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3], z.arr[2] = 0, 0
	z.arr[1] = binary.BigEndian.Uint64(in[0:8])
	z.arr[0] = binary.BigEndian.Uint64(in[8:16])
	return z
}

// SetBytes17 sets z from a 17-byte big-endian slice and returns z.
// Panics if input is shorter than 17 bytes.
func (z *Uint) SetBytes17(in []byte) *Uint {
	_ = in[16] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = 0
	z.arr[2] = uint64(in[0])
	z.arr[1] = binary.BigEndian.Uint64(in[1:9])
	z.arr[0] = binary.BigEndian.Uint64(in[9:17])
	return z
}

// SetBytes18 sets z from an 18-byte big-endian slice and returns z.
// Panics if input is shorter than 18 bytes.
func (z *Uint) SetBytes18(in []byte) *Uint {
	_ = in[17] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = 0
	z.arr[2] = uint64(binary.BigEndian.Uint16(in[0:2]))
	z.arr[1] = binary.BigEndian.Uint64(in[2:10])
	z.arr[0] = binary.BigEndian.Uint64(in[10:18])
	return z
}

// SetBytes19 sets z from a 19-byte big-endian slice and returns z.
// Panics if input is shorter than 19 bytes.
func (z *Uint) SetBytes19(in []byte) *Uint {
	_ = in[18] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = 0
	z.arr[2] = uint64(binary.BigEndian.Uint16(in[1:3])) | uint64(in[0])<<16
	z.arr[1] = binary.BigEndian.Uint64(in[3:11])
	z.arr[0] = binary.BigEndian.Uint64(in[11:19])
	return z
}

// SetBytes20 sets z from a 20-byte big-endian slice and returns z.
// Panics if input is shorter than 20 bytes.
func (z *Uint) SetBytes20(in []byte) *Uint {
	_ = in[19] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = 0
	z.arr[2] = uint64(binary.BigEndian.Uint32(in[0:4]))
	z.arr[1] = binary.BigEndian.Uint64(in[4:12])
	z.arr[0] = binary.BigEndian.Uint64(in[12:20])
	return z
}

// SetBytes21 sets z from a 21-byte big-endian slice and returns z.
// Panics if input is shorter than 21 bytes.
func (z *Uint) SetBytes21(in []byte) *Uint {
	_ = in[20] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = 0
	z.arr[2] = bigEndianUint40(in[0:5])
	z.arr[1] = binary.BigEndian.Uint64(in[5:13])
	z.arr[0] = binary.BigEndian.Uint64(in[13:21])
	return z
}

// SetBytes22 sets z from a 22-byte big-endian slice and returns z.
// Panics if input is shorter than 22 bytes.
func (z *Uint) SetBytes22(in []byte) *Uint {
	_ = in[21] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = 0
	z.arr[2] = bigEndianUint48(in[0:6])
	z.arr[1] = binary.BigEndian.Uint64(in[6:14])
	z.arr[0] = binary.BigEndian.Uint64(in[14:22])
	return z
}

// SetBytes23 sets z from a 23-byte big-endian slice and returns z.
// Panics if input is shorter than 23 bytes.
func (z *Uint) SetBytes23(in []byte) *Uint {
	_ = in[22] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = 0
	z.arr[2] = bigEndianUint56(in[0:7])
	z.arr[1] = binary.BigEndian.Uint64(in[7:15])
	z.arr[0] = binary.BigEndian.Uint64(in[15:23])
	return z
}

// SetBytes24 sets z from a 24-byte big-endian slice and returns z.
// Panics if input is shorter than 24 bytes.
func (z *Uint) SetBytes24(in []byte) *Uint {
	_ = in[23] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = 0
	z.arr[2] = binary.BigEndian.Uint64(in[0:8])
	z.arr[1] = binary.BigEndian.Uint64(in[8:16])
	z.arr[0] = binary.BigEndian.Uint64(in[16:24])
	return z
}

// SetBytes25 sets z from a 25-byte big-endian slice and returns z.
// Panics if input is shorter than 25 bytes.
func (z *Uint) SetBytes25(in []byte) *Uint {
	_ = in[24] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = uint64(in[0])
	z.arr[2] = binary.BigEndian.Uint64(in[1:9])
	z.arr[1] = binary.BigEndian.Uint64(in[9:17])
	z.arr[0] = binary.BigEndian.Uint64(in[17:25])
	return z
}

// SetBytes26 sets z from a 26-byte big-endian slice and returns z.
// Panics if input is shorter than 26 bytes.
func (z *Uint) SetBytes26(in []byte) *Uint {
	_ = in[25] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = uint64(binary.BigEndian.Uint16(in[0:2]))
	z.arr[2] = binary.BigEndian.Uint64(in[2:10])
	z.arr[1] = binary.BigEndian.Uint64(in[10:18])
	z.arr[0] = binary.BigEndian.Uint64(in[18:26])
	return z
}

// SetBytes27 sets z from a 27-byte big-endian slice and returns z.
// Panics if input is shorter than 27 bytes.
func (z *Uint) SetBytes27(in []byte) *Uint {
	_ = in[26] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = uint64(binary.BigEndian.Uint16(in[1:3])) | uint64(in[0])<<16
	z.arr[2] = binary.BigEndian.Uint64(in[3:11])
	z.arr[1] = binary.BigEndian.Uint64(in[11:19])
	z.arr[0] = binary.BigEndian.Uint64(in[19:27])
	return z
}

// SetBytes28 sets z from a 28-byte big-endian slice and returns z.
// Panics if input is shorter than 28 bytes.
func (z *Uint) SetBytes28(in []byte) *Uint {
	_ = in[27] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = uint64(binary.BigEndian.Uint32(in[0:4]))
	z.arr[2] = binary.BigEndian.Uint64(in[4:12])
	z.arr[1] = binary.BigEndian.Uint64(in[12:20])
	z.arr[0] = binary.BigEndian.Uint64(in[20:28])
	return z
}

// SetBytes29 sets z from a 29-byte big-endian slice and returns z.
// Panics if input is shorter than 29 bytes.
func (z *Uint) SetBytes29(in []byte) *Uint {
	_ = in[28] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = bigEndianUint40(in[0:5])
	z.arr[2] = binary.BigEndian.Uint64(in[5:13])
	z.arr[1] = binary.BigEndian.Uint64(in[13:21])
	z.arr[0] = binary.BigEndian.Uint64(in[21:29])
	return z
}

// SetBytes30 sets z from a 30-byte big-endian slice and returns z.
// Panics if input is shorter than 30 bytes.
func (z *Uint) SetBytes30(in []byte) *Uint {
	_ = in[29] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = bigEndianUint48(in[0:6])
	z.arr[2] = binary.BigEndian.Uint64(in[6:14])
	z.arr[1] = binary.BigEndian.Uint64(in[14:22])
	z.arr[0] = binary.BigEndian.Uint64(in[22:30])
	return z
}

// SetBytes31 sets z from a 31-byte big-endian slice and returns z.
// Panics if input is shorter than 31 bytes.
func (z *Uint) SetBytes31(in []byte) *Uint {
	_ = in[30] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = bigEndianUint56(in[0:7])
	z.arr[2] = binary.BigEndian.Uint64(in[7:15])
	z.arr[1] = binary.BigEndian.Uint64(in[15:23])
	z.arr[0] = binary.BigEndian.Uint64(in[23:31])
	return z
}

// SetBytes32 sets z from a 32-byte big-endian slice and returns z.
// Panics if input is shorter than 32 bytes.
func (z *Uint) SetBytes32(in []byte) *Uint {
	_ = in[31] // bounds check hint to compiler; see golang.org/issue/14808
	z.arr[3] = binary.BigEndian.Uint64(in[0:8])
	z.arr[2] = binary.BigEndian.Uint64(in[8:16])
	z.arr[1] = binary.BigEndian.Uint64(in[16:24])
	z.arr[0] = binary.BigEndian.Uint64(in[24:32])
	return z
}

// Utility methods that are "missing" among the bigEndian.UintXX methods.

// bigEndianUint40 returns the uint64 value represented by the 5 bytes in big-endian order.
func bigEndianUint40(b []byte) uint64 {
	_ = b[4] // bounds check hint to compiler; see golang.org/issue/14808
	return uint64(b[4]) | uint64(b[3])<<8 | uint64(b[2])<<16 | uint64(b[1])<<24 |
		uint64(b[0])<<32
}

// bigEndianUint56 returns the uint64 value represented by the 7 bytes in big-endian order.
func bigEndianUint56(b []byte) uint64 {
	_ = b[6] // bounds check hint to compiler; see golang.org/issue/14808
	return uint64(b[6]) | uint64(b[5])<<8 | uint64(b[4])<<16 | uint64(b[3])<<24 |
		uint64(b[2])<<32 | uint64(b[1])<<40 | uint64(b[0])<<48
}

// bigEndianUint48 returns the uint64 value represented by the 6 bytes in big-endian order.
func bigEndianUint48(b []byte) uint64 {
	_ = b[5] // bounds check hint to compiler; see golang.org/issue/14808
	return uint64(b[5]) | uint64(b[4])<<8 | uint64(b[3])<<16 | uint64(b[2])<<24 |
		uint64(b[1])<<32 | uint64(b[0])<<40
}
