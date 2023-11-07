package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"
)

func removeItemFromStringArray(s []string, r string) []string {
	for i, v := range s {
		if v == r {
			return append(s[:i], s[i+1:]...)
		}
	}
	return s
}

func poolPathWithFeeDivide(poolPath string) (string, string, int) {
	poolPathSplit := strings.Split(poolPath, ":")
	require(len(poolPathSplit) == 3, ufmt.Sprintf("[ROUTER] util.gno__poolPathWithFeeDivide() || len(poolPathSplit) != 3, poolPath: %s", poolPath))

	feeInt, err := strconv.Atoi(poolPathSplit[2])
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] util.gno__poolPathWithFeeDivide() || cannot convert fee(%s) to int", poolPathSplit[2]))
	}

	return poolPathSplit[0], poolPathSplit[1], feeInt
}

func singlePoolPathWithFeeDivide(poolPath string) (string, string) {
	singlePoolPathSplit := strings.Split(poolPath, ":")
	require(len(singlePoolPathSplit) == 2, ufmt.Sprintf("[ROUTER] util.gno__singlePoolPathWithFeeDivide || len(singlePoolPathSplit) != 2, poolPath: %s", poolPath))

	return singlePoolPathSplit[0], singlePoolPathSplit[1]
}

func getSwapData(path string, poolIdx int) (string, string, uint16) {
	// inputToken, outputToken, fee
	datas := strings.Split(path, ",")

	switch poolIdx {
	case 0:
		fee, _ := strconv.Atoi(datas[1])
		return datas[0], datas[2], uint16(fee)
	case 1:
		fee, _ := strconv.Atoi(datas[3])
		return datas[2], datas[4], uint16(fee)
	case 2:
		fee, _ := strconv.Atoi(datas[5])
		return datas[4], datas[6], uint16(fee)
	default:
		return "", "", 0
	}
}

func sortItems(tokenAPath, tokenBPath, fee string) string {
	if tokenAPath < tokenBPath {
		return tokenAPath + ":" + tokenBPath + ":" + fee
	} else {
		return tokenBPath + ":" + tokenAPath + ":" + fee
	}
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func require(cond bool, msg string) {
	if !cond {
		panic(msg)
	}
}
