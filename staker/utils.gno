package staker

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	pusers "gno.land/p/demo/users"
)

func poolPathAlign(poolPath string) string {
	res := strings.Split(poolPath, ":")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[STAKER] utils.gno__poolPathAlign() || invalid poolPath(%s)", poolPath))
	}

	pToken0, pToken1, fee := res[0], res[1], res[2]

	if pToken0 < pToken1 {
		return ufmt.Sprintf("%s:%s:%s", pToken0, pToken1, fee)
	}

	return ufmt.Sprintf("%s:%s:%s", pToken1, pToken0, fee)
}

func poolPathDivide(poolPath string) (string, string, string) {
	res := strings.Split(poolPath, ":")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[STAKER] utils.gno__poolPathDivide() || invalid poolPath(%s)", poolPath))
	}

	pToken0, pToken1, fee := res[0], res[1], res[2]
	return pToken0, pToken1, fee
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
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

func min(x, y uint64) uint64 {
	if x < y {
		return x
	}
	return y
}

func uint8ToStr(i uint8) string {
	return strconv.FormatInt(int64(i), 10)
}

func int32ToStr(i int32) string {
	return strconv.FormatInt(int64(i), 10)
}

func int64ToStr(i int64) string {
	return strconv.FormatInt(i, 10)
}

func uint64ToStr(i uint64) string {
	return strconv.FormatInt(int64(i), 10)
}

func strToUint64(s string) uint64 {
	i, err := strconv.Atoi(s)

	if err != nil {
		panic(ufmt.Sprintf("[STAKER] utils.gno__strToUint64() || failed to convert string(%s) to uint64", s))
	}

	return uint64(i)
}

func boolToStr(b bool) string {
	if b {
		return "true"
	}

	return "false"
}

func origCaller() string {
	return std.GetOrigCaller().String()
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func callType() string {
	if prevRealm() == "" {
		return "DIRECT"
	}

	return "INDIRECT"
}

func contains(slice []string, item string) bool {
	for _, element := range slice {
		if element == item {
			return true
		}
	}
	return false
}
