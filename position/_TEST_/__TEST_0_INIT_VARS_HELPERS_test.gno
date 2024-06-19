package position

import (
	"std"
	"testing"

	"gno.land/r/demo/gnoswap/consts"

	"gno.land/r/demo/gnft"

	pl "gno.land/r/demo/pool"
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

// Realms to mock frames
var (
	gsaRealm = std.NewUserRealm(gsa)
	posRealm = std.NewCodeRealm(consts.POSITION_PATH)
	rouRealm = std.NewCodeRealm(consts.ROUTER_PATH)
	stkRealm = std.NewCodeRealm(consts.STAKER_PATH)
)

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

	return uint64(coins.AmountOf("ugnot"))
}

func isOwner(t *testing.T, tokenId uint64, addr std.Address) bool {
	owner := gnft.OwnerOf(tid(tokenId))

	if owner == addr {
		return true
	}

	t.Errorf("expected owner %v, got %v", addr, owner)
	return false
}

func getPoolFromLpTokenId(lpTokenId uint64) *pl.Pool {
	position := positions[lpTokenId]

	return pl.GetPoolFromPoolPath(position.poolKey)
}
