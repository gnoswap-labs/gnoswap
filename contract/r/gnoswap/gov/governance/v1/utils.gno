package v1

import (
	"encoding/base64"
	"math"
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"
)

// b64Encode encodes a string to base64.
func b64Encode(data string) string {
	return base64.StdEncoding.EncodeToString([]byte(data))
}

// formatInt formats an integer to a string.
func formatInt(v any) string {
	switch v := v.(type) {
	case int8:
		return strconv.FormatInt(int64(v), 10)
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}

// formatBool formats a boolean to a string.
func formatBool(v bool) string {
	return strconv.FormatBool(v)
}

// numberKind represents the type of number to parse.
type numberKind int

const (
	kindInt numberKind = iota
	kindInt64
	kindUint64
)

// parseNumber parses a string to a number (int, int64, or uint64) with proper validation.
func parseNumber(s string, kind numberKind) any {
	if len(strings.TrimSpace(s)) == 0 {
		panic(ufmt.Sprint("invalid number value: empty or whitespace string"))
	}

	switch kind {
	case kindInt:
		num, err := strconv.ParseInt(s, 10, 64)
		if err != nil {
			panic(ufmt.Sprintf("invalid int value: %s", s))
		}
		return int(num)
	case kindInt64:
		num, err := strconv.ParseInt(s, 10, 64)
		if err != nil {
			panic(ufmt.Sprintf("invalid int64 value: %s", s))
		}
		return num
	case kindUint64:
		num, err := strconv.ParseUint(s, 10, 64)
		if err != nil {
			panic(ufmt.Sprintf("invalid uint64 value: %s", s))
		}
		return num
	default:
		panic(ufmt.Sprintf("unsupported number kind: %v", kind))
	}
}

// parseBool parses a string to a boolean.
func parseBool(s string) bool {
	if len(strings.TrimSpace(s)) == 0 {
		panic(ufmt.Sprint("invalid bool value: empty or whitespace string"))
	}

	switch s {
	case "true":
		return true
	case "false":
		return false
	default:
		panic(ufmt.Sprintf("invalid bool value: %s", s))
	}
}

// parseInt parses a string to int with proper validation and overflow checking.
func parseInt(s string) int {
	if len(strings.TrimSpace(s)) == 0 {
		panic(ufmt.Sprint("invalid int value: empty or whitespace string"))
	}

	num, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		panic(ufmt.Sprintf("invalid int value: %s", s))
	}

	const maxInt = int(^uint(0) >> 1)
	const minInt = -maxInt - 1

	if num > int64(maxInt) || num < int64(minInt) {
		panic(ufmt.Sprintf("int overflow: value %d exceeds int range [%d, %d]", num, minInt, maxInt))
	}

	return int(num)
}

// parseInt64 parses a string to int64 with proper validation.
func parseInt64(s string) int64 {
	if len(strings.TrimSpace(s)) == 0 {
		panic(ufmt.Sprint("invalid int64 value: empty or whitespace string"))
	}

	num, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		panic(ufmt.Sprintf("invalid int64 value: %s", s))
	}

	return num
}

// parseUint64 parses a string to uint64 with proper validation.
func parseUint64(s string) uint64 {
	if len(strings.TrimSpace(s)) == 0 {
		panic(ufmt.Sprint("invalid uint64 value: empty or whitespace string"))
	}

	num, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(ufmt.Sprintf("invalid uint64 value: %s", s))
	}

	return num
}

// safeAddInt64 performs safe addition of int64 values, panicking on overflow or underflow
func safeAddInt64(a, b int64) int64 {
	if a > 0 && b > math.MaxInt64-a {
		panic("int64 addition overflow")
	}
	if a < 0 && b < math.MinInt64-a {
		panic("int64 addition underflow")
	}
	return a + b
}

// safeSubInt64 performs safe subtraction of int64 values, panicking on overflow or underflow
func safeSubInt64(a, b int64) int64 {
	if b > 0 && a < math.MinInt64+b {
		panic("int64 subtraction underflow")
	}
	if b < 0 && a > math.MaxInt64+b {
		panic("int64 subtraction overflow")
	}
	return a - b
}
