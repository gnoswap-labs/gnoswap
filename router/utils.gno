package router

import (
	"std"
	"strconv"
	"strings"

	pusers "gno.land/p/demo/users"

	"gno.land/p/demo/ufmt"
)

func poolPathWithFeeDivide(poolPath string) (string, string, int) {
	poolPathSplit := strings.Split(poolPath, ":")
	if len(poolPathSplit) != 3 {
		panic(ufmt.Sprintf("[ROUTER] _RPC_api.gno__poolPathWithFeeDivide() || len(poolPathSplit) != 3, poolPath: %s", poolPath))
	}

	feeInt, err := strconv.Atoi(poolPathSplit[2])
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] _RPC_api.gno__poolPathWithFeeDivide() || cannot convert fee(%s) to int", poolPathSplit[2]))
	}

	return poolPathSplit[0], poolPathSplit[1], feeInt
}

func getDataForSinglePath(poolPath string) (string, string, uint32) {
	datas := strings.Split(poolPath, ":")
	if len(datas) != 3 {
		panic(ufmt.Sprintf("[ROUTER] _util.gno__getDataForSinglePath() || len(datas) != 3 (poolPath:%s)", poolPath))
	}

	token0 := datas[0]
	token1 := datas[1]
	fee, _ := strconv.Atoi(datas[2])

	return token0, token1, uint32(fee)
}

func getDataForMultiPath(possiblePath string, poolIdx int) (string, string, uint32) {
	pools := strings.Split(possiblePath, "*POOL*")

	var token0, token1 string
	var fee uint32

	switch poolIdx {
	case 0:
		token0, token1, fee = getDataForSinglePath(pools[0])
	case 1:
		token0, token1, fee = getDataForSinglePath(pools[1])
	case 2:
		token0, token1, fee = getDataForSinglePath(pools[2])
	default:
		return "", "", uint32(0)
	}

	return token0, token1, fee
}

func isStringInStringArr(arr []string, str string) bool {
	for _, a := range arr {
		if a == str {
			return true
		}
	}
	return false
}

func removeStringFromStringArr(arr []string, str string) []string {
	for i, a := range arr {
		if a == str {
			return append(arr[:i], arr[i+1:]...)
		}
	}
	return arr
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
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

func uint64ToStr(i uint64) string {
	return strconv.FormatInt(int64(i), 10)
}
