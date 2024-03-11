package staker

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/users"
)

func poolKeyDivide(poolKey string) string {

	res := strings.Split(poolKey, ":")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[STAKER] utils.gno__poolKeyDivide() || invalid poolKey(%s)", poolKey))
	}

	pToken0, pToken1, fee := res[0], res[1], res[2]

	if pToken0 < pToken1 {
		zz := ufmt.Sprintf("%s:%s:%s", pToken0, pToken1, fee)
		return ufmt.Sprintf("%s:%s:%s", pToken0, pToken1, fee)
	}

	zz := ufmt.Sprintf("%s:%s:%s", pToken1, pToken0, fee)
	return ufmt.Sprintf("%s:%s:%s", pToken1, pToken0, fee)
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic("[STAKER] utils.gno__tid() || tokenId is nil")
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
		panic("[STAKER] utils.gno__tid() || unsupported tokenId type")
	}
}

func max(x, y int64) int64 {
	if x > y {
		return x
	}
	return y
}

func min(x, y int64) int64 {
	if x < y {
		return x
	}
	return y
}

func requireUnsigned(x bigint, msg string) {
	if x < 0 {
		panic(msg)
	}
}

func require(condition bool, message string) {
	if !condition {
		panic(message)
	}
}

func requireExist(exist bool, msg string) {
	if !exist {
		panic(msg)
	}
}

func requirePrevRealmPath(prevRealmPath, msg string) {
	if std.PrevRealm().PkgPath() != prevRealmPath {
		panic(msg)
	}
}
