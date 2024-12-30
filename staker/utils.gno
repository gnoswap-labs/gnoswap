package staker

import (
	"std"
	"strconv"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

func GetOrigPkgAddr() std.Address {
	return consts.STAKER_ADDR
}

func poolPathAlign(poolPath string) string {
	res, err := common.Split(poolPath, ":", 3)
	if err != nil {
		panic(addDetailToError(
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

func poolPathDivide(poolPath string) (string, string, string) {
	res, err := common.Split(poolPath, ":", 3)
	if err != nil {
		panic(errInvalidPoolPath)
	}

	pToken0, pToken1, fee := res[0], res[1], res[2]
	return pToken0, pToken1, fee
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic(addDetailToError(
			errDataNotFound,
			"tokenId is nil",
		))
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
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("unsupported tokenId type(%T)", tokenId),
		))
	}
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func contains(slice []string, item string) bool {
	for _, element := range slice {
		if element == item {
			return true
		}
	}
	return false
}

func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}
