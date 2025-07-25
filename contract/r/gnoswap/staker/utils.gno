package staker

import (
	"std"
	"strconv"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/rbac"
)

// GetOrigPkgAddr returns the original package address.
// In staker contract, original package address is the staker address.
func GetOrigPkgAddr() std.Address {
	return getRoleAddress(prbac.ROLE_STAKER)
}

// poolPathAlign ensures that a pool path is formatted with tokens in lexicographical order.
//
// This function takes a pool path string and splits it into three components:
// - Token0 address
// - Token1 address
// - Fee tier
// It ensures that the tokens are ordered lexicographically (Token0 < Token1) and reconstructs
// the pool path in the correct order.
//
// Parameters:
// - poolPath (string): The input pool path string in the format "Token0:Token1:Fee".
//
// Returns:
// - string: A lexicographically ordered pool path string.
//
// Panics:
// - If the input `poolPath` is invalid or cannot be split into exactly three parts.
func poolPathAlign(poolPath string) string {
	res, err := common.Split(poolPath, ":", 3)
	if err != nil {
		panic(makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("invalid poolPath(%s)", poolPath),
		))
	}

	pToken0, pToken1, fee := res[0], res[1], res[2]

	if pToken0 < pToken1 {
		return ufmt.Sprintf("%s:%s:%s", pToken0, pToken1, fee)
	}

	return ufmt.Sprintf("%s:%s:%s", pToken1, pToken0, fee)
}

// poolPathDivide splits a pool path string into its components.
//
// The function takes a pool path string in the format "Token0:Token1:Fee",
// splits it using the `:` separator, and returns the three components:
// - `pToken0`: The first token address.
// - `pToken1`: The second token address.
// - `fee`: The fee tier.
//
// Parameters:
// - poolPath (string): The input pool path string.
//
// Returns:
// - string: `pToken0` - The first token address.
// - string: `pToken1` - The second token address.
// - string: `fee` - The fee tier.
//
// Panics:
// - If the `poolPath` cannot be split into exactly three components.
func poolPathDivide(poolPath string) (string, string, string) {
	res, err := common.Split(poolPath, ":", 3)
	if err != nil {
		panic(errInvalidPoolPath)
	}

	pToken0, pToken1, fee := res[0], res[1], res[2]
	return pToken0, pToken1, fee
}

// positionIdFrom converts uint64 to grc721.TokenID.
//
// Input:
//   - id: the uint64 to convert
//
// Output:
//   - grc721.TokenID: the converted token ID
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

// max returns the larger of x or y.
func max(x, y int64) int64 {
	if x > y {
		return x
	}
	return y
}

// min returns the smaller of x or y.
func min(x, y uint64) uint64 {
	if x < y {
		return x
	}
	return y
}

// contains checks if a string is present in a slice of strings.
func contains(slice []string, item string) bool {
	// we can use strings.EqualFold here, but this function should be case-sensitive.
	// so, it is better to compare strings directly.
	for _, element := range slice {
		if element == item {
			return true
		}
	}
	return false
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
		panic(ufmt.Sprintf("invalid type for Unsigned: %T", v))
	}
}

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

func formatBool(v bool) string {
	return strconv.FormatBool(v)
}

func getRoleAddress(role prbac.SystemRole) std.Address {
	addr, exists := access.GetAddress(role.String())
	if !exists {
		return rbac.DefaultRoleAddresses[role]
	}

	return addr
}