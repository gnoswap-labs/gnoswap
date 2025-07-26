package position

import (
	"std"
	"strconv"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
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
	operator := PositionGetPositionOperator(positionId)
	return operator == addr
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
	if !addr.IsValid() {
		return false
	}

	if !exists(positionId) {
		return false
	}

	staked := isStaked(positionIdFrom(positionId))
	if staked {
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
	res, err := common.Split(poolKey, ":", 3)
	if err != nil {
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