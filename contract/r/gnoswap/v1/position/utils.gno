package position

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/gnft"
)

// GetOrigPkgAddr returns the original package address.
// In position contract, original package address is the position address.
func GetOrigPkgAddr() std.Address {
	return std.CurrentRealm().Address()
}

// positionIdFrom converts positionId to grc721.TokenID type
// NOTE: input parameter positionId can be string, int, uint64, or grc721.TokenID
// if positionId is nil or not supported, it will panic
// if positionId is not found, it will panic
// input: positionId any
// output: grc721.TokenID
func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic(newErrorWithDetail(errInvalidInput, "positionId is nil"))
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
		panic(newErrorWithDetail(errInvalidInput, "unsupported positionId type"))
	}
}

// exists checks whether positionId exists
// If positionId doesn't exist, return false, otherwise return true
// input: positionId uint64
// output: bool
func exists(positionId uint64) bool {
	return gnft.Exists(positionIdFrom(positionId))
}

// isOwner checks whether the caller is the owner of the positionId
// If the caller is the owner of the positionId, return true, otherwise return false
// input: positionId uint64, addr std.Address
// output: bool
func isOwner(positionId uint64, addr std.Address) bool {
	owner, err := gnft.OwnerOf(positionIdFrom(positionId))
	if err == nil {
		if owner == addr {
			return true
		}
	}

	return false
}

// isOperator checks whether the caller is the approved operator of the positionId
// If the caller is the approved operator of the positionId, return true, otherwise return false
// input: positionId uint64, addr std.Address
// output: bool
func isOperator(positionId uint64, addr std.Address) bool {
	return PositionGetPositionOperator(positionId) == addr
}

// isStaked checks whether positionId is staked
// If positionId is staked, owner of positionId is staker contract
// If positionId is staked, return true, otherwise return false
// input: positionId grc721.TokenID
// output: bool
func isStaked(positionId grc721.TokenID) bool {
	exist := gnft.Exists(positionId)
	if exist {
		owner, err := gnft.OwnerOf(positionId)
		if err == nil && owner == stakerAddr {
			return true
		}
	}
	return false
}

// isOwnerOrOperator checks whether the caller is the owner or approved operator of the positionId
// If the caller is the owner or approved operator of the positionId, return true, otherwise return false
// input: addr std.Address, positionId uint64
// output: bool
func isOwnerOrOperator(positionId uint64, addr std.Address) bool {
	if !addr.IsValid() || !exists(positionId) {
		return false
	}

	if isStaked(positionIdFrom(positionId)) {
		return isOperator(positionId, addr)
	}

	return isOwner(positionId, addr)
}

// splitOf divides poolKey into pToken0, pToken1, and pFee
// If poolKey is invalid, it will panic
//
// input: poolKey string
// output:
// - token0Path string
// - token1Path string
// - fee uint32
func splitOf(poolKey string) (string, string, uint32) {
	res := strings.Split(poolKey, ":")
	if len(res) != 3 {
		panic(newErrorWithDetail(errInvalidInput, ufmt.Sprintf("invalid poolKey(%s)", poolKey)))
	}

	pToken0, pToken1, pFeeStr := res[0], res[1], res[2]

	pFee, err := strconv.Atoi(pFeeStr)
	if err != nil {
		panic(newErrorWithDetail(errInvalidInput, ufmt.Sprintf("invalid fee(%s)", pFeeStr)))
	}

	return pToken0, pToken1, uint32(pFee)
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

func formatInt(v any) string {
	switch v := v.(type) {
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	case int:
		return strconv.Itoa(v)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}

func formatBool(v bool) string {
	return strconv.FormatBool(v)
}

func mustParseInt64(v string) int64 {
	amountInt, err := strconv.ParseInt(v, 10, 64)
	if err != nil {
		panic(err)
	}

	return amountInt
}

func isTokenOwner(positionId uint64, caller std.Address) bool {
	owner, err := gnft.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		return false
	}

	return owner == caller
}

func isSlippageExceeded(amount0, amount1, amount0Min, amount1Min *u256.Uint) bool {
	return !(amount0.Gte(amount0Min) && amount1.Gte(amount1Min))
}

func subUint256(x, y *u256.Uint) *u256.Uint {
	if x.Cmp(y) < 0 {
		q256 := u256.MustFromDecimal(MAX_UINT256)
		diff := u256.Zero().Sub(q256, y)
		result := u256.Zero().Add(diff, x)

		// Add 1 to the result since MAX_UINT256 is 2^256 - 1
		return u256.Zero().Add(result, u256.One())
	}

	return u256.Zero().Sub(x, y)
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
