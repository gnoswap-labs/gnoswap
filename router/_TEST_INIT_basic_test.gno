package router

import (
	"std"
	"testing"

	"gno.land/r/demo/gns"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/qux"

	"gno.land/r/demo/obl"

	"gno.land/r/demo/wugnot"

	"gno.land/r/demo/consts"
)

var (
	test1 std.Address

	barPath   = "gno.land/r/demo/bar"
	bazPath   = "gno.land/r/demo/baz"
	fooPath   = "gno.land/r/demo/foo"
	gnsPath   = "gno.land/r/demo/gns"
	oblPath   = "gno.land/r/demo/obl"
	quxPath   = "gno.land/r/demo/qux"
	wgnotPath = "gno.land/r/demo/wugnot"

	fee100  = uint16(100)
	fee500  = uint16(500)
	fee3000 = uint16(3000)

	max_timeout = bigint(9999999999)
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
	qux.Approve(a2u(consts.POOL_ADDR), 500_000_000_000_000)

	obl.Approve(a2u(consts.STAKER_ADDR), 500_000_000_000_000)    // to create external incentive
	wugnot.Approve(a2u(consts.STAKER_ADDR), 500_000_000_000_000) // to create (native) external incentive

	wugnot.Approve(a2u(consts.POOL_ADDR), 500_000_000_000_000)

	std.TestSetPrevAddr(consts.INTERNAL_REWARD_ACCOUNT)
	gns.Approve(a2u(consts.STAKER_ADDR), 500_000_000_000_000) // to create internal incentive
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

func ugnotBalanceOf(addr std.Address) uint64 {
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)

	coins := testBanker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(testBanker.GetCoins(addr)[0].Amount)
}
