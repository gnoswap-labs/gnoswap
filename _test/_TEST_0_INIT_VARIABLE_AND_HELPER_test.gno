package swap_scenario

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"

	"gno.land/r/demo/consts"

	"gno.land/r/demo/users"
)

var (
	gsa   std.Address = consts.GNOSWAP_ADMIN
	test1 std.Address = std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5")

	fooPath string = "gno.land/r/demo/foo"
	barPath string = "gno.land/r/demo/bar"
	bazPath string = "gno.land/r/demo/baz"
	quxPath string = "gno.land/r/demo/qux"

	oblPath string = "gno.land/r/demo/obl"
	// wugnotPath string = "gno.land/r/demo/wugnot" // from consts
	// gnsPath string = "gno.land/r/demo/gns" // from consts

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999
)

/* UTIL */
func ugnotBalanceOf(addr std.Address) uint64 {
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)

	coins := testBanker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(testBanker.GetCoins(addr)[0].Amount)
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic("tid() || tokenId is nil")
	}

	switch tokenId.(type) {
	case string:
		return grc721.TokenID(tokenId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(tokenId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(tokenId.(uint64))))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic("[STAKER] utils.gno__tid() || unsupported tokenId type")
	}
}

/* TEST HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, didn't expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
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
			t.Errorf("expected panic")
		} else {
			if r != msg {
				t.Errorf("excepted panic(%v), got(%v)", msg, r)
			}
		}
	}()
	f()
}
