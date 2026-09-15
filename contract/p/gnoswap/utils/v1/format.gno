package utils

import (
	"strconv"

	ufmt "gno.land/p/nt/ufmt/v0"
)

// FormatInt converts any signed integer type to its base-10 string
// representation. It accepts int8, int16, int32, int64 and int, and panics on
// any other type.
//
// Parameters:
//   - v: the value to format; it must have type int8, int16, int32, int64, or int
//
// Returns:
//   - decimal: the base-10 representation of the supported signed integer
func FormatInt(v any) string {
	switch v := v.(type) {
	case int8:
		return strconv.FormatInt(int64(v), 10)
	case int16:
		return strconv.FormatInt(int64(v), 10)
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	case int:
		return strconv.Itoa(v)
	default:
		panic(ufmt.Sprintf("invalid type for FormatInt: %T", v))
	}
}

// FormatUint converts any unsigned integer type to its base-10 string
// representation. It accepts uint8, uint16, uint32, uint64 and uint, and panics
// on any other type.
//
// Parameters:
//   - v: the value to format; it must have type uint8, uint16, uint32, uint64, or uint
//
// Returns:
//   - decimal: the base-10 representation of the supported unsigned integer
func FormatUint(v any) string {
	switch v := v.(type) {
	case uint8:
		return strconv.FormatUint(uint64(v), 10)
	case uint16:
		return strconv.FormatUint(uint64(v), 10)
	case uint32:
		return strconv.FormatUint(uint64(v), 10)
	case uint64:
		return strconv.FormatUint(v, 10)
	case uint:
		return strconv.FormatUint(uint64(v), 10)
	default:
		panic(ufmt.Sprintf("invalid type for FormatUint: %T", v))
	}
}

// FormatBool converts a boolean to "true" or "false".
//
// Parameters:
//   - v: the boolean to format
//
// Returns:
//   - text: "true" or "false" corresponding to v
func FormatBool(v bool) string {
	return strconv.FormatBool(v)
}

// Uint64ToString returns the base-10 string representation of a uint64.
//
// Parameters:
//   - v: the unsigned 64-bit integer to format
//
// Returns:
//   - decimal: the base-10 representation of v
func Uint64ToString(v uint64) string {
	return strconv.FormatUint(v, 10)
}

// Int64ToString returns the base-10 string representation of an int64.
//
// Parameters:
//   - v: the signed 64-bit integer to format
//
// Returns:
//   - decimal: the base-10 representation of v
func Int64ToString(v int64) string {
	return strconv.FormatInt(v, 10)
}

// SafeParseInt64 parses a base-10 string into an int64, panicking when the
// input is not a valid int64.
//
// Parameters:
//   - value: the base-10 text to parse as an int64
//
// Returns:
//   - value: the parsed int64; invalid or out-of-range text panics
func SafeParseInt64(value string) int64 {
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		panic(err)
	}

	return parsed
}
