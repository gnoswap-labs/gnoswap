package position

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"
	"gno.land/r/gnoswap/v1/common"
)

func checkDeadline(deadline int64) {
	now := time.Now().Unix()
	if now > deadline {
		panic(addDetailToError(
			errExpired,
			ufmt.Sprintf("utils.gno__checkDeadline() || transaction too old, now(%d) > deadline(%d)", now, deadline),
		))
	}
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func poolKeyDivide(poolKey string) (string, string, uint32) {
	res, err := common.Split(poolKey, ":", 3)
	if err != nil {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("utils.gno__poolKeyDivide() || invalid poolKey(%s)", poolKey),
		))
	}

	pToken0, pToken1, pFeeStr := res[0], res[1], res[2]

	pFee, _ := strconv.Atoi(pFeeStr)
	return pToken0, pToken1, uint32(pFee)
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}
