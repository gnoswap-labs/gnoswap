package position

import (
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/users"
)

func require(condition bool, message string) {
	if !condition {
		panic(message)
	}
}

func checkDeadline(deadline int64) {
	require(time.Now().Unix() <= deadline, ufmt.Sprintf("[POSITION] utils.gno__checkDeadline() || transaction too old__time.Now().Unix()(%d) <= deadline(%d)", time.Now().Unix(), deadline))
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func poolKeyDivide(poolKey string) (string, string, uint32) {
	res := strings.Split(poolKey, ":")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[POSITION] util.gno__poolKeyDivide() || invalid poolKey(%s)", poolKey))
	}

	pToken0, pToken1, pFeeStr := res[0], res[1], res[2]

	pFee, _ := strconv.Atoi(pFeeStr)
	return pToken0, pToken1, uint32(pFee)
}
