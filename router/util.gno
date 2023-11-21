package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/r/demo/users"

	"gno.land/p/demo/ufmt"
)

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

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func require(cond bool, msg string) {
	if !cond {
		panic(msg)
	}
}
