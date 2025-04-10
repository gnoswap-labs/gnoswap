package router

import (
	"bytes"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/emission"

	i256 "gno.land/p/gnoswap/int256"

	phalt "gno.land/p/gnoswap/halt"
	"gno.land/r/gnoswap/v1/halt"
)

var (
	errRouterHalted = "router contract operations are currently disabled"
	errTxExpired    = "transaction too old, now(%d) > deadline(%d)"
)

// assertHopsInRange panics if the number of hops is not in the range 1~3.
func assertHopsInRange(hops int) {
	switch hops {
	case 1, 2, 3:
		return
	default:
		panic(errHopsOutOfRange)
	}
}

// getDataForSinglePath extracts token0, token1, and fee from a single path.
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

// getDataForMultiPath extracts token0, token1, and fee from a multi path.
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

// i256Min returns the smaller of two i256.Int.
func i256Min(x, y *i256.Int) *i256.Int {
	if x.Lt(y) {
		return x
	}
	return y
}

// i256Max returns the larger of two i256.Int.
func i256Max(x, y *i256.Int) *i256.Int {
	if x.Gt(y) {
		return x
	}
	return y
}

// getPrevAddr returns the address of the previous realm.
func getPrevAddr() std.Address {
	return std.PreviousRealm().Address()
}

// getPrev returns the address and package path of the previous realm.
func getPrev() (string, string) {
	prev := std.PreviousRealm()
	return prev.Address().String(), prev.PkgPath()
}

// haltCheck performs security validations before any swap operation
func haltCheck() error {
	currentLevel := halt.GetCurrentHaltLevel()

	if currentLevel != halt.LvMainnetSafeMode {
		// check for withdraw operation halt
		if err := halt.IsHalted(phalt.OpTypeWithdraw); err != nil {
			return err
		}

		// check for router contract halt
		if halt.IsContractHalted(phalt.OpTypeRouter) {
			return ufmt.Errorf(errRouterHalted)
		}
	}

	return nil
}

// commonSwapSetup performs all necessary validations and setup for a swap operation
func commonSwapSetup() error {
	if err := haltCheck(); err != nil {
		return err
	}

	if common.GetLimitCaller() && std.PreviousRealm().PkgPath() != "" {
		return ufmt.Errorf(errNoPermission.Error(), "only user can call this function")
	}

	emission.MintAndDistributeGns()
	return nil
}

// checkDeadline checks if the deadline is expired.
// If the deadline is expired, it panics.
// The deadline is expired if the current time is greater than the deadline.
// Input:
//   - deadline: the deadline to check
func checkDeadline(deadline int64) error {
	now := time.Now().Unix()
	if now <= deadline {
		return nil
	}

	return ufmt.Errorf(errTxExpired, now, deadline)
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
