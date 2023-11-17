package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/r/demo/users"

	"gno.land/p/demo/ufmt"
)

// func removeItemFromStringArray(s []string, r string) []string {
// 	for i, v := range s {
// 		if v == r {
// 			return append(s[:i], s[i+1:]...)
// 		}
// 	}
// 	return s
// }

// func poolPathWithFeeDivide(poolPath string) (string, string, int) {
// 	poolPathSplit := strings.Split(poolPath, ":")
// 	require(len(poolPathSplit) == 3, ufmt.Sprintf("[ROUTER] util.gno__poolPathWithFeeDivide() || len(poolPathSplit) != 3, poolPath: %s", poolPath))

// 	feeInt, err := strconv.Atoi(poolPathSplit[2])
// 	if err != nil {
// 		panic(ufmt.Sprintf("[ROUTER] util.gno__poolPathWithFeeDivide() || cannot convert fee(%s) to int", poolPathSplit[2]))
// 	}

// 	return poolPathSplit[0], poolPathSplit[1], feeInt
// }

// func singlePoolPathWithFeeDivide(poolPath string) (string, string) {
// 	singlePoolPathSplit := strings.Split(poolPath, ":")
// 	require(len(singlePoolPathSplit) == 2, ufmt.Sprintf("[ROUTER] util.gno__singlePoolPathWithFeeDivide || len(singlePoolPathSplit) != 2, poolPath: %s", poolPath))

// 	return singlePoolPathSplit[0], singlePoolPathSplit[1]
// }

func getDataForSinglePath(poolPath string) (token0, token1 string, fee uint16) {
	datas := strings.Split(poolPath, ":")
	require(len(datas) == 3, ufmt.Sprintf("[ROUTER] _util.gno__getDataForSinglePath() || len(datas) != 3 (poolPath:%s)", poolPath))

	token0 = datas[0]
	token1 = datas[1]
	_fee, _ := strconv.Atoi(datas[2])

	return token0, token1, uint16(_fee)
}

func getDataForMultiPath(possiblePath string, poolIdx int) (token0, token1 string, fee uint16) {
	pools := strings.Split(possiblePath, "*POOL*")

	switch poolIdx {
	case 0:
		token0, token1, fee = getDataForSinglePath(pools[0])
	case 1:
		token0, token1, fee = getDataForSinglePath(pools[1])
	case 2:
		token0, token1, fee = getDataForSinglePath(pools[2])
	default:
		return "", "", 0
	}

	return token0, token1, fee
}

// func sortItems(tokenAPath, tokenBPath, fee string) string {
// 	if tokenAPath < tokenBPath {
// 		return tokenAPath + ":" + tokenBPath + ":" + fee
// 	} else {
// 		return tokenBPath + ":" + tokenAPath + ":" + fee
// 	}
// }

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func require(cond bool, msg string) {
	if !cond {
		panic(msg)
	}
}
