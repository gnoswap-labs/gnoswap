package staker

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/rbac"
)

// GetOrigPkgAddr returns the original package address.
func GetOrigPkgAddr() std.Address {
	return stakerAddr
}

// poolPathAlign ensures pool path tokens are in lexicographical order.
func poolPathAlign(poolPath string) string {
	pToken0, pToken1, fee := poolPathDivide(poolPath)

	if pToken0 < pToken1 {
		return ufmt.Sprintf("%s:%s:%s", pToken0, pToken1, fee)
	}

	return ufmt.Sprintf("%s:%s:%s", pToken1, pToken0, fee)
}

// poolPathDivide splits a pool path into token addresses and fee tier.
func poolPathDivide(poolPath string) (string, string, string) {
	res := strings.Split(poolPath, ":")
	if len(res) != 3 {
		panic(errInvalidPoolPath)
	}

	pToken0, pToken1, fee := res[0], res[1], res[2]
	return pToken0, pToken1, fee
}

// positionIdFrom converts various types to grc721.TokenID.
func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic(makeErrorWithDetails(
			errDataNotFound,
			"positionId is nil",
		))
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("unsupported positionId type(%T)", positionId),
		))
	}
}

// max returns the larger of two int64 values.
func max(x, y int64) int64 {
	if x > y {
		return x
	}
	return y
}

// min returns the smaller of two uint64 values.
func min(x, y uint64) uint64 {
	if x < y {
		return x
	}
	return y
}

// contains checks if a string exists in a slice.
func contains(slice []string, item string) bool {
	// We can use strings.EqualFold here, but this function should be case-sensitive.
	// So, it is better to compare strings directly.
	for _, element := range slice {
		if element == item {
			return true
		}
	}
	return false
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
		panic(ufmt.Sprintf("invalid type for Unsigned: %T", v))
	}
}

// formatAnyInt formats a signed integer to string.
func formatAnyInt(v any) string {
	switch v := v.(type) {
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	case int:
		return strconv.Itoa(v)
	default:
		panic(ufmt.Sprintf("invalid type for Signed: %T", v))
	}
}

// formatBool formats a boolean to string.
func formatBool(v bool) string {
	return strconv.FormatBool(v)
}

// getRoleAddress retrieves the address for a system role.
func getRoleAddress(role prbac.SystemRole) std.Address {
	addr, exists := access.GetAddress(role.String())
	if !exists {
		return rbac.DefaultRoleAddresses[role]
	}

	return addr
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
