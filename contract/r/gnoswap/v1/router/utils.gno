package router

import (
	"bytes"
	"strconv"
	"strings"
	"time"

	"gno.land/p/nt/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	errRouterHalted = "router contract operations are currently disabled"
	errTxExpired    = "transaction too old, now(%d) > deadline(%d)"
)

// assertHopsInRange ensures the number of hops is within the valid range of 1-3.
func assertHopsInRange(hops int) {
	switch hops {
	case 1, 2, 3:
		return
	default:
		panic(errHopsOutOfRange)
	}
}

// assertIsNotPassedDeadline ensures the transaction deadline has not expired.
func assertIsNotPassedDeadline(deadline int64) {
	if err := checkDeadline(deadline); err != nil {
		errMsg := addDetailToError(errExpired, err.Error())
		panic(errMsg)
	}
}

// getDataForSinglePath extracts token addresses and fee from a single pool path.
func getDataForSinglePath(poolPath string) (token0, token1 string, fee uint32) {
	poolPathSplit := strings.Split(poolPath, ":")
	if len(poolPathSplit) != 3 {
		panic(addDetailToError(
			errInvalidPoolPath,
			ufmt.Sprintf("len(poolPathSplit) != 3, poolPath: %s", poolPath),
		))
	}

	f, err := strconv.Atoi(poolPathSplit[2])
	if err != nil {
		panic(ufmt.Sprintf("invalid fee: %s", poolPathSplit[2]))
	}

	return poolPathSplit[0], poolPathSplit[1], uint32(f)
}

// getDataForMultiPath extracts token addresses and fee from a multi-hop path at specified index.
func getDataForMultiPath(possiblePath string, poolIdx int) (token0, token1 string, fee uint32) {
	pools := strings.Split(possiblePath, POOL_SEPARATOR)

	switch poolIdx {
	case 0:
		return getDataForSinglePath(pools[0])
	case 1:
		return getDataForSinglePath(pools[1])
	case 2:
		return getDataForSinglePath(pools[2])
	default:
		return "", "", uint32(0)
	}
}

// i256MinMax returns the absolute values of x and y in min-max order.
func i256MinMax(x, y *i256.Int) (min, max *u256.Uint) {
	if x.Lt(y) || x.Eq(y) {
		return x.Abs(), y.Abs()
	}
	return y.Abs(), x.Abs()
}

// checkDeadline verifies that the transaction deadline has not passed.
func checkDeadline(deadline int64) error {
	now := time.Now().Unix()
	if now <= deadline {
		return nil
	}

	return ufmt.Errorf(errTxExpired, now, deadline)
}

// splitSingleChar splits a string by a single character separator.
// This function is optimized for splitting strings with a single-byte separator
// and is more memory efficient than strings.Split for this use case.
func splitSingleChar(s string, sep byte) []string {
	if s == "" {
		return []string{""}
	}

	result := make([]string, 0, bytes.Count([]byte(s), []byte{sep})+1)
	start := 0
	for i := range s {
		if s[i] == sep {
			result = append(result, s[start:i])
			start = i + 1
		}
	}
	result = append(result, s[start:])
	return result
}

// formatUint formats an unsigned integer to string.
func formatUint(v any) string {
	switch v := v.(type) {
	case uint8:
		return strconv.FormatUint(uint64(v), 10)
	case uint32:
		return strconv.FormatUint(uint64(v), 10)
	case uint64:
		return strconv.FormatUint(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}

// formatInt64 formats a signed integer to string.
func formatInt64(v any) string {
	switch v := v.(type) {
	case int8:
		return strconv.FormatInt(int64(v), 10)
	case int16:
		return strconv.FormatInt(int64(v), 10)
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type %T", v))
	}
}

// safeConvertToInt64 safely converts a *u256.Uint value to an int64, ensuring no overflow.
//
// This function attempts to convert the given *u256.Uint value to an int64. If the value exceeds
// the maximum allowable range for int64 (`2^63 - 1`), it triggers a panic with a descriptive error message.
//
// Parameters:
// - value (*u256.Uint): The unsigned 256-bit integer to be converted.
//
// Returns:
// - int64: The converted value if it falls within the int64 range.
//
// Panics:
//   - If the `value` exceeds the range of int64, the function will panic with an error indicating
//     the overflow and the original value.
func safeConvertToInt64(value *u256.Uint) int64 {
	const INT64_MAX = 9223372036854775807
	const MAX_INT64 = "9223372036854775807"

	res, overflow := value.Uint64WithOverflow()
	if overflow || res > uint64(INT64_MAX) {
		panic(ufmt.Sprintf(
			"amount(%s) overflows int64 range (max %s)",
			value.ToString(),
			MAX_INT64,
		))
	}
	return int64(res)
}
