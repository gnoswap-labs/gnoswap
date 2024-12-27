package router

import (
	"bytes"
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"
	"gno.land/r/gnoswap/v1/common"

	i256 "gno.land/p/gnoswap/int256"
)

func assertDirectCallOnly() {
	if common.GetLimitCaller() && std.PrevRealm().PkgPath() != "" {
		panic(addDetailToError(errNoPermission, "only user can call this function"))
	}
}

func assertHopsInRange(hops int) {
	if hops < 1 || hops > 3 {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("number of hops(%d) must be 1~3", hops),
		))
	}
}

func getDataForSinglePath(poolPath string) (string, string, uint32) {
	poolPathSplit, err := common.Split(poolPath, ":", 3)
	if err != nil {
		panic(addDetailToError(
			errInvalidPoolPath,
			ufmt.Sprintf("len(poolPathSplit) != 3, poolPath: %s", poolPath),
		))
	}

	token0 := poolPathSplit[0]
	token1 := poolPathSplit[1]
	fee, _ := strconv.Atoi(poolPathSplit[2])

	return token0, token1, uint32(fee)
}

func getDataForMultiPath(possiblePath string, poolIdx int) (string, string, uint32) {
	pools := strings.Split(possiblePath, "*POOL*")

	var token0, token1 string
	var fee uint32

	switch poolIdx {
	case 0:
		token0, token1, fee = getDataForSinglePath(pools[0])
	case 1:
		token0, token1, fee = getDataForSinglePath(pools[1])
	case 2:
		token0, token1, fee = getDataForSinglePath(pools[2])
	default:
		return "", "", uint32(0)
	}

	return token0, token1, fee
}

func isStringInStringArr(arr []string, str string) bool {
	for _, a := range arr {
		if a == str {
			return true
		}
	}
	return false
}

func removeStringFromStringArr(arr []string, str string) []string {
	for i, a := range arr {
		if a == str {
			return append(arr[:i], arr[i+1:]...)
		}
	}
	return arr
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func i256Min(x, y *i256.Int) *i256.Int {
	if x.Lt(y) {
		return x
	}
	return y
}

func i256Max(x, y *i256.Int) *i256.Int {
	if x.Gt(y) {
		return x
	}
	return y
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

// splitSingleChar splits a string by a single character separator.
//
// This function is optimized for splitting strings with a single-byte separator.
// Unlike `strings.Split`, it:
// 1. Performs direct byte comparison instead of substring matching
// 2. Avoids additional string allocations by using slicing
// 3. Makes only one allocation for the result slice
//
// The main differences from `strings.Split` are:
// - Only works with single-byte separators
// - More memory efficient as it doesn't need to handle multi-byte separators
// - Faster for small to medium strings due to simpler byte comparison
//
// Performance:
//   - Up to 5x faster than `strings.Split` for small strings (in Go)
//   - For gno (run test with `-print-runtime-metrics` option):
//     |     Function     |     Cycles       | Allocations
//     |------------------|------------------|--------------|
//     | strings.Split    |      1.1M        | 808.1K       |
//     | splitSingleChar  |      1.0M        | 730.4K       |
//   - Uses zero allocations except for the initial result slice
//   - Most effective for strings under 1KB with simple single-byte delimiters
//     (* This test result was measured without the `uassert` package)
//
// Parameters:
//
//	s (string): source string to split
//	sep (byte): single byte separator to split on
//
// Returns:
//
//	[]string: slice containing the split string parts
func splitSingleChar(s string, sep byte) []string {
	l := len(s)
	if l == 0 {
		return []string{""}
	}

	result := make([]string, 0, bytes.Count([]byte(s), []byte{sep})+1)
	start := 0
	for i := 0; i < l; i++ {
		if s[i] == sep {
			result = append(result, s[start:i])
			start = i + 1
		}
	}
	result = append(result, s[start:])
	return result
}
