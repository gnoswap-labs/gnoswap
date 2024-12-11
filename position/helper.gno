package position

import (
	"std"
	"strconv"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gnft"
)

// nextId is the next tokenId to be minted
func getNextId() uint64 {
	return nextId
}

// tokenIdFrom converts tokenId to grc721.TokenID type
// NOTE: input parameter tokenId can be string, int, uint64, or grc721.TokenID
// if tokenId is nil or not supported, it will panic
// if tokenId is not found, it will panic
// input: tokenId interface{}
// output: grc721.TokenID
func tokenIdFrom(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic(newErrorWithDetail(errInvalidInput, "tokenId is nil"))
	}

	switch tokenId.(type) {
	case string:
		return grc721.TokenID(tokenId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(tokenId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(tokenId.(uint64))))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic(newErrorWithDetail(errInvalidInput, "unsupported tokenId type"))
	}
}

// exists checks whether tokenId exists
// If tokenId doesn't exist, return false, otherwise return true
// input: tokenId uint64
// output: bool
func exists(tokenId uint64) bool {
	return gnft.Exists(tokenIdFrom(tokenId))
}

// isOwner checks whether the caller is the owner of the tokenId
// If the caller is the owner of the tokenId, return true, otherwise return false
// input: tokenId uint64, addr std.Address
// output: bool
func isOwner(tokenId uint64, addr std.Address) bool {
	owner := gnft.OwnerOf(tokenIdFrom(tokenId))
	if owner == addr {
		return true
	}
	return false
}

// isOperator checks whether the caller is the approved operator of the tokenId
// If the caller is the approved operator of the tokenId, return true, otherwise return false
// input: tokenId uint64, addr std.Address
// output: bool
func isOperator(tokenId uint64, addr std.Address) bool {
	operator, ok := gnft.GetApproved(tokenIdFrom(tokenId))
	if ok && operator == addr {
		return true
	}
	return false
}

// isStaked checks whether tokenId is staked
// If tokenId is staked, owner of tokenId is staker contract
// If tokenId is staked, return true, otherwise return false
// input: tokenId grc721.TokenID
// output: bool
func isStaked(tokenId grc721.TokenID) bool {
	exist := gnft.Exists(tokenId)
	if exist {
		owner := gnft.OwnerOf(tokenId)
		if owner == consts.STAKER_ADDR {
			return true
		}
	}
	return false
}

// isOwnerOrOperator checks whether the caller is the owner or approved operator of the tokenId
// If the caller is the owner or approved operator of the tokenId, return true, otherwise return false
// input: addr std.Address, tokenId uint64
// output: bool
func isOwnerOrOperator(addr std.Address, tokenId uint64) bool {
	assertOnlyValidAddress(addr)
	if !exists(tokenId) {
		return false
	}
	if isOwner(tokenId, addr) || isOperator(tokenId, addr) {
		return true
	}
	if isStaked(tokenIdFrom(tokenId)) {
		position, exist := positions[tokenId]
		if exist && addr == position.operator {
			return true
		}
	}
	return false
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

	pFee, _ := strconv.Atoi(pFeeStr)
	return pToken0, pToken1, uint32(pFee)
}
