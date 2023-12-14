package position

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/users"
)

func require(condition bool, message string) {
	if !condition {
		panic(message)
	}
}

func checkDeadline(deadline bigint) {
	require(bigint(GetTimestamp()) <= deadline, ufmt.Sprintf("[POSITION] util.gno__checkDeadline() || transaction too old__GetTimestamp()(%d) <= deadline(%d)", GetTimestamp(), deadline))
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func poolKeyDivide(poolKey string) (string, string, uint16) {
	res := strings.Split(poolKey, ":")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[POSITION] util.gno__poolKeyDivide() || invalid poolKey(%s)", poolKey))
	}

	pToken0, pToken1, stringFee := res[0], res[1], res[2]

	pFee, err := strconv.Atoi(stringFee)

	return pToken0, pToken1, uint16(pFee)
}
