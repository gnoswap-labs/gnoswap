package pool

import (
	"std"
	"testing"

	"gno.land/r/demo/gns"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"

	"gno.land/r/demo/wugnot"
)

var (
	test1             std.Address
	poolAddr, posAddr std.Address

	barPath = "gno.land/r/demo/bar"
	bazPath = "gno.land/r/demo/baz"
	fooPath = "gno.land/r/demo/foo"

	wgnotPath = "gno.land/r/demo/wugnot"

	fee100  = uint16(100)
	fee500  = uint16(500)
	fee3000 = uint16(3000)
)

func init() {
	test1 = std.Address("g16kvq0mra3atvr07lkdwc2x6jqmna8a4kt0e85d")
	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(test1, "ugnot", 500_000_000_000_000)

	poolAddr = std.DerivePkgAddr("gno.land/r/demo/pool")
	posAddr = std.DerivePkgAddr("gno.land/r/demo/position")

	std.TestSetPrevAddr(test1)

	gns.Approve(a2u(poolAddr), 500_000_000_000_000)

	bar.Approve(a2u(poolAddr), 500_000_000_000_000)
	baz.Approve(a2u(poolAddr), 500_000_000_000_000)
	foo.Approve(a2u(poolAddr), 500_000_000_000_000)

	wugnot.Approve(a2u(poolAddr), 500_000_000_000_000)

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
