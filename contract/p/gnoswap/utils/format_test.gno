package utils

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestFormatInt(t *testing.T) {
	uassert.Equal(t, "127", FormatInt(int8(127)))
	uassert.Equal(t, "-32768", FormatInt(int16(-32768)))
	uassert.Equal(t, "2147483647", FormatInt(int32(2147483647)))
	uassert.Equal(t, "-9223372036854775808", FormatInt(int64(-9223372036854775808)))
	uassert.Equal(t, "42", FormatInt(int(42)))
}

func TestFormatInt_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, "invalid type for FormatInt: uint64", func() {
		FormatInt(uint64(1))
	})
}

func TestFormatUint(t *testing.T) {
	uassert.Equal(t, "255", FormatUint(uint8(255)))
	uassert.Equal(t, "65535", FormatUint(uint16(65535)))
	uassert.Equal(t, "4294967295", FormatUint(uint32(4294967295)))
	uassert.Equal(t, "18446744073709551615", FormatUint(uint64(18446744073709551615)))
	uassert.Equal(t, "7", FormatUint(uint(7)))
}

func TestFormatUint_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, "invalid type for FormatUint: int64", func() {
		FormatUint(int64(1))
	})
}

func TestFormatBool(t *testing.T) {
	uassert.Equal(t, "true", FormatBool(true))
	uassert.Equal(t, "false", FormatBool(false))
}

func TestUint64ToString(t *testing.T) {
	uassert.Equal(t, "0", Uint64ToString(0))
	uassert.Equal(t, "18446744073709551615", Uint64ToString(18446744073709551615))
}

func TestInt64ToString(t *testing.T) {
	uassert.Equal(t, "-9223372036854775808", Int64ToString(-9223372036854775808))
	uassert.Equal(t, "9223372036854775807", Int64ToString(9223372036854775807))
}

func TestSafeParseInt64(t *testing.T) {
	uassert.Equal(t, int64(123), SafeParseInt64("123"))
	uassert.Equal(t, int64(-456), SafeParseInt64("-456"))
	uassert.Equal(t, int64(9223372036854775807), SafeParseInt64("9223372036854775807"))
}

func TestSafeParseInt64_Panics(cur realm, t *testing.T) {
	uassert.PanicsContains(t, cur, `parsing "abc": invalid syntax`, func() {
		SafeParseInt64("abc")
	})
	uassert.PanicsContains(t, cur, `parsing "99999999999999999999": value out of range`, func() {
		SafeParseInt64("99999999999999999999")
	})
}
