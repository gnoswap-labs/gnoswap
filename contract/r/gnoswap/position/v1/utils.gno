package v1

import (
	"strconv"
	"strings"

	"gno.land/p/demo/tokens/grc721"
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
)

const MAX_UINT256 string = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

func mustGetStakerAddress() address {
	return access.MustGetAddress(prabc.ROLE_STAKER.String())
}

// positionIdFrom converts positionId to grc721.TokenID type
// input: positionId uint64
// output: grc721.TokenID
func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(positionId, 10))
}

// exists checks whether positionId exists
// If positionId doesn't exist, return false, otherwise return true
// input: positionId uint64
// output: bool
func (p *positionV1) exists(positionId uint64) bool {
	return p.nftAccessor.Exists(positionIdFrom(positionId))
}

// isOwner checks whether the caller is the owner of the positionId
// If the caller is the owner of the positionId, return true, otherwise return false
// input: positionId uint64, addr std.Address
// output: bool
func (p *positionV1) isOwner(positionId uint64, addr address) bool {
	owner, err := p.nftAccessor.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		return false
	}
	return owner == addr
}

// isOperator checks whether the caller is the approved operator of the positionId
// If the caller is the approved operator of the positionId, return true, otherwise return false
// input: positionId uint64, addr std.Address
// output: bool
func (p *positionV1) isOperator(positionId uint64, addr address) bool {
	return p.GetPositionOperator(positionId) == addr
}

// isStaked checks whether positionId is staked
// If positionId is staked, owner of positionId is staker contract
// If positionId is staked, return true, otherwise return false
// input: positionId grc721.TokenID
// output: bool
func (p *positionV1) isStaked(positionId grc721.TokenID) bool {
	exist := p.nftAccessor.Exists(positionId)
	if !exist {
		return false
	}
	owner, err := p.nftAccessor.OwnerOf(positionId)
	if err == nil && owner == mustGetStakerAddress() {
		return true
	}
	return false
}

// isOwnerOrOperator checks whether the caller is the owner or approved operator of the positionId
// If the caller is the owner or approved operator of the positionId, return true, otherwise return false
// input: addr std.Address, positionId uint64
// output: bool
func (p *positionV1) isOwnerOrOperator(positionId uint64, addr address) bool {
	if !addr.IsValid() || !p.exists(positionId) {
		return false
	}

	if p.isStaked(positionIdFrom(positionId)) {
		return p.isOperator(positionId, addr)
	}

	return p.isOwner(positionId, addr)
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

func isSlippageExceeded(amount0, amount1, amount0Min, amount1Min *u256.Uint) bool {
	return !(amount0.Gte(amount0Min) && amount1.Gte(amount1Min))
}
