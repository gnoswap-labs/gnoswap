package governance

import (
	"std"
	"testing"

	"gno.land/r/gnoswap/v2/consts"
)

var (
	admin std.Address = consts.ADMIN

	fooPath string = "gno.land/r/onbloc/foo"
	barPath string = "gno.land/r/onbloc/bar"
	bazPath string = "gno.land/r/onbloc/baz"
	quxPath string = "gno.land/r/onbloc/qux"

	oblPath string = "gno.land/r/onbloc/obl"
	// wugnotPath string = "gno.land/r/demo/wugnot" // from consts
	// gnsPath string = "gno.land/r/gnoswap/v2/gns" // from consts

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999
)

// Realms to mock frames
var (
	adminRealm = std.NewUserRealm(admin)

	posRealm = std.NewCodeRealm(consts.POSITION_PATH)
	rouRealm = std.NewCodeRealm(consts.ROUTER_PATH)
	stkRealm = std.NewCodeRealm(consts.STAKER_PATH)
	govRealm = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
)

/* HELPER */
func ugnotBalanceOf(addr std.Address) uint64 {
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)

	coins := testBanker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(coins.AmountOf("ugnot"))
}

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got\n%v\n\nexpected\n%v\n", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, didn't expected %v", got, expected)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}

func shouldPanicWithMsg(t *testing.T, f func(), msg string) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("The code did not panic")
		} else {
			if r != msg {
				t.Errorf("excepted panic(%v), got(%v)", msg, r)
			}
		}
	}()
	f()
}
