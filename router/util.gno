package router

import (
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
)

/* UTIL */
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

	if len(poolPathSplit) != 3 {
		panic(ufmt.Sprintf("[POOL] pool_router.gno__poolPathWithFeeDivide() || len(poolPathSplit) != 3, poolPath: %s", poolPath))
	}

	feeInt, err := strconv.Atoi(poolPathSplit[2])
	if err != nil {
		panic(ufmt.Sprintf("[POOL] pool_router.gno__poolPathWithFeeDivide() || cannot convert fee(%s) to int", poolPathSplit[2]))
	}

	return poolPathSplit[0], poolPathSplit[1], feeInt
}

func singlePoolPathWithFeeDivide(poolPath string) (string, string) {
	singlePoolPathSplit := strings.Split(poolPath, ":")

	if len(singlePoolPathSplit) != 2 {
		panic(ufmt.Sprintf("[POOL] pool_router.gno__singlePoolPathWithFeeDivide || len(singlePoolPathSplit) != 2, poolPath: %s", poolPath))
	}
	return singlePoolPathSplit[0], singlePoolPathSplit[1]
}

func getNumPoolInPath(path string) int {
	count := strings.Count(path, ",")
	return count / 2
}

func getPoolKey(path string, poolIdx int) string {
	datas := strings.Split(path, ",")

	switch poolIdx {
	case 0:
		return sortItems(datas[0], datas[2], datas[1])
	case 1:
		return sortItems(datas[2], datas[4], datas[3])
	case 2:
		return sortItems(datas[4], datas[6], datas[5])
	default:
		panic("NOT SUPPORTED #1")
	}
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
