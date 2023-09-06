package position

import (
	"std"
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
	require(GetTimestamp() <= deadline, ufmt.Sprintf("[POSITION] util.gno__checkDeadline() || transaction too old__GetTimestamp()(%s) <= deadline(%s)", GetTimestamp(), deadline))
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func poolKeyDivide(poolKey string) (string, string, bigint) {
	res := strings.Split(poolKey, "_")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[POSITION] util.gno__poolKeyDivide() || invalid poolKey(%s)", poolKey))
	}

	pToken0, pToken1, pFee := res[0], res[1], res[2]

	return pToken0, pToken1, bigint(pFee)
}
