package faucet

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	"gno.land/r/demo/users"

	"gno.land/r/demo/gns"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/qux"
)

func TestFaucet(t *testing.T) {
	user1 := testutils.TestAddress("user1")

	oldNative := ugnotBalanceOf(user1)
	shouldEQ(t, oldNative, uint64(0))

	oldGns := gns.BalanceOf(a2u(user1))
	shouldEQ(t, oldGns, uint64(0))

	oldBar := bar.BalanceOf(a2u(user1))
	shouldEQ(t, oldBar, uint64(0))

	oldBaz := baz.BalanceOf(a2u(user1))
	shouldEQ(t, oldBaz, uint64(0))

	oldFoo := foo.BalanceOf(a2u(user1))
	shouldEQ(t, oldFoo, uint64(0))

	oldQux := qux.BalanceOf(a2u(user1))
	shouldEQ(t, oldQux, uint64(0))

	Faucet(user1)

	newNative := ugnotBalanceOf(user1)
	shouldEQ(t, newNative-oldNative, uint64(100_000_000))

	newGns := gns.BalanceOf(a2u(user1))
	shouldEQ(t, newGns-oldGns, uint64(100_000_000))

	newBar := bar.BalanceOf(a2u(user1))
	shouldEQ(t, newBar-oldBar, uint64(100_000_000))

	newBaz := baz.BalanceOf(a2u(user1))
	shouldEQ(t, newBaz-oldBaz, uint64(100_000_000))

	newFoo := foo.BalanceOf(a2u(user1))
	shouldEQ(t, newFoo-oldFoo, uint64(100_000_000))

	newQux := qux.BalanceOf(a2u(user1))
	shouldEQ(t, newQux-oldQux, uint64(100_000_000))
}

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

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}
