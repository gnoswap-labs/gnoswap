// Package utils provides pure, deterministic formatting and parsing helpers
// shared across GnoSwap realms. Every function here is side-effect free and
// depends only on the standard library and ufmt.
package utils

import (
	"strconv"

	ufmt "gno.land/p/nt/ufmt/v0"
)

// FormatInt converts any signed integer type to its base-10 string
// representation. It accepts int8, int16, int32, int64 and int, and panics on
// any other type.
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
func FormatBool(v bool) string {
	return strconv.FormatBool(v)
}

// Uint64ToString returns the base-10 string representation of a uint64.
func Uint64ToString(v uint64) string {
	return strconv.FormatUint(v, 10)
}

// Int64ToString returns the base-10 string representation of an int64.
func Int64ToString(v int64) string {
	return strconv.FormatInt(v, 10)
}

// SafeParseInt64 parses a base-10 string into an int64, panicking when the
// input is not a valid int64.
func SafeParseInt64(value string) int64 {
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		panic(err)
	}

	return parsed
}
