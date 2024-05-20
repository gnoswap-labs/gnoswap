package position

import (
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"

	pusers "gno.land/p/demo/users"
)

func checkDeadline(deadline int64) {
	if time.Now().Unix() > deadline {
		panic(ufmt.Sprintf("[POSITION] utils.gno__checkDeadline() || transaction too old__time.Now().Unix()(%d) <= deadline(%d)", time.Now().Unix(), deadline))
	}
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func poolKeyDivide(poolKey string) (string, string, uint32) {
	res := strings.Split(poolKey, ":")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[POSITION] utils.gno__poolKeyDivide() || invalid poolKey(%s)", poolKey))
	}

	pToken0, pToken1, pFeeStr := res[0], res[1], res[2]

	pFee, _ := strconv.Atoi(pFeeStr)
	return pToken0, pToken1, uint32(pFee)
}

func int32ToStr(i int32) string {
	return strconv.FormatInt(int64(i), 10)
}

func uint64ToStr(i uint64) string {
	return strconv.FormatInt(int64(i), 10)
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
