// change block avg time from 2s to 2.5s

// PKGPATH: gno.land/r/gnoswap/v1/gns_test
package gns_test

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gns"
)

var t *testing.T

var (
	user01Addr  = testutils.TestAddress("user01Addr")
	user01Realm = std.NewUserRealm(user01Addr)
)

func init() {
}

func main() {
	skip50Blocks()
	blockTime2500ms()
	reachAlmostFirstHalving()
	reachExactFirstHalving()
	startSecondHalving()
}

func skip50Blocks() {
	std.TestSkipHeights(50)
	uassert.Equal(t, std.GetHeight(), int64(173))

	std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	gns.Mint(a2u(user01Addr)) // 14269406 * 50 = 713470300
	uassert.Equal(t, uint64(713470300), gns.TotalMinted())
}

func blockTime2500ms() {
	std.TestSetRealm(std.NewUserRealm(consts.ADMIN))
	gns.SetAvgBlockTimeInMsByAdmin(2500)
	std.TestSkipHeights(1)

	// for block time 2.5s
	// amount per block is 17836757

	std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	gns.Mint(a2u(user01Addr))                                       // 17836757
	uassert.Equal(t, uint64(713470300+17836757), gns.TotalMinted()) // 731307057
}

func reachAlmostFirstHalving() {
	// current height = 174
	// next halving = 12614533
	// 12614533 - 174 = 12614359

	std.TestSkipHeights(12614358)
	std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	gns.Mint(a2u(user01Addr))

	uassert.Equal(t, uint64(224999969664063), gns.TotalMinted())
	// 224999969664063 - 731307057 = 224999238357006
	// 224999238357006 / 12614358 = 17836757
}

func reachExactFirstHalving() {
	std.TestSkipHeights(1)
	std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	gns.Mint(a2u(user01Addr))

	// minted all amount for first halving year
	uassert.Equal(t, uint64(225000000000000), gns.TotalMinted())

	year := gns.GetHalvingYearByHeight(std.GetHeight())
	uassert.Equal(t, int64(1), year)
}

func startSecondHalving() {
	std.TestSkipHeights(1)

	year := gns.GetHalvingYearByHeight(std.GetHeight())
	uassert.Equal(t, int64(2), year)

	amount := gns.GetAmountByHeight(std.GetHeight())
	uassert.Equal(t, uint64(14269406), amount)

	std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	gns.Mint(a2u(user01Addr))
	uassert.Equal(t, uint64(225000000000000+14269406), gns.TotalMinted())
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}
