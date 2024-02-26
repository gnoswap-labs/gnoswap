package swap_scenario

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/grc/grc721"
	"gno.land/r/demo/users"

	"gno.land/r/demo/consts"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/obl"
	"gno.land/r/demo/qux"

	"gno.land/r/demo/wugnot"
)

const (
	MAX_TIMEOUT bigint = 9999999999
)

var (
	test1 std.Address

	barPath = "gno.land/r/demo/bar"
	barObj  = bar.GetGRC20()

	bazPath = "gno.land/r/demo/baz"
	bazObj  = baz.GetGRC20()

	fooPath = "gno.land/r/demo/foo"
	fooObj  = foo.GetGRC20()

	quxPath = "gno.land/r/demo/qux"
	quxObj  = qux.GetGRC20()

	wugnotPath = "gno.land/r/demo/wugnot"
	// wugnotObj  = wugnot.GetGRC20()

	gnsPath = "gno.land/r/demo/gns"
	gnsObj  = gns.GetGRC20()

	oblPath = "gno.land/r/demo/obl"
	oblObj  = obl.GetGRC20()

	fee100  = uint16(100)
	fee500  = uint16(500)
	fee3000 = uint16(3000)
)

func init() {
	test1 = std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5")
	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(test1, "ugnot", 500_000_000_000_000)

	std.TestSetPrevAddr(test1)

	gns.Approve(a2u(consts.POOL_ADDR), 500_000_000_000_000)

	bar.Approve(a2u(consts.POOL_ADDR), 500_000_000_000_000)
	baz.Approve(a2u(consts.POOL_ADDR), 500_000_000_000_000)
	foo.Approve(a2u(consts.POOL_ADDR), 500_000_000_000_000)

	wugnot.Approve(a2u(consts.POOL_ADDR), 500_000_000_000_000)

}

/* HELPER */
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

func balanceOf(token *grc20.AdminToken, addr std.Address) uint64 {
	balance, err := token.BalanceOf(addr)
	if err != nil {
		panic(err)
	}

	return balance
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic("tid() || tokenId is nil")
	}

	switch tokenId.(type) {
	case bigint:
		return grc721.TokenID(string(tokenId.(bigint)))
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

func ugnotBalanceOf(addr std.Address) uint64 {
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)

	coins := testBanker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(testBanker.GetCoins(addr)[0].Amount)
}

func wugnotBalanceOf(addr std.Address) uint64 {
	return wugnot.BalanceOf(a2u(addr))
}
