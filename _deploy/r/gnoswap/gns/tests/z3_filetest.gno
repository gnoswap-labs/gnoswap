// change block avg time from 2s > 4s> 3s

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
	blockTime4000ms() // 4s
	reachAboutHalfOfFirstHalving()
	blockTime3000ms() // 3s
	reachFirstHalving()
	startSecondHalving()
}

func skip50Blocks() {
	std.TestSkipHeights(50)
	uassert.Equal(t, std.GetHeight(), int64(173))

	std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	gns.Mint(a2u(user01Addr)) // 14269406 * 50 = 713470300
	uassert.Equal(t, uint64(713470300), gns.TotalMinted())
}

func blockTime4000ms() {
	std.TestSetRealm(std.NewUserRealm(consts.ADMIN))
	gns.SetAvgBlockTimeInMsByAdmin(4000)
	std.TestSkipHeights(1)

	// for block time 4s
	// amount per block is 28538812

	std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	gns.Mint(a2u(user01Addr))                                       // 28538812
	uassert.Equal(t, uint64(713470300+28538812), gns.TotalMinted()) // 742009112

	firstYearAmountPerBlock := gns.GetAmountByYear(1)
	uassert.Equal(t, uint64(28538812), firstYearAmountPerBlock)
	uassert.Equal(t, int64(7884148), gns.GetHalvingYearBlock(1))
	// FORMULA
	// orig_start = 123
	// orig_1year = 15768123 ( 123 + 1 year block(15768000) )

	// 50 block mined from L#37
	// current = 173
	// 15768123 - 173 = 15767950 // number of block left to next halving

	// 15767950 * 2 = 31535900 // number of timestamp left to next halving
	// > before change, block time was 2s (2000ms)

	// 31535900 / 4 = 7883975 // based on 4s block, number of block left to next halving
	// current(173) + above left(7883975) = 7884148
}

func reachAboutHalfOfFirstHalving() {
	// current := 174
	// nextHalving := 7884148
	// 7884148 - 174 = 7883974
	// 7883974 / 2 = 3941987

	std.TestSkipHeights(3941987)
	std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	gns.Mint(a2u(user01Addr))

	// minted about 50% amount for first halving year
	uassert.Equal(t, uint64(112500367908556), gns.TotalMinted())

	year := gns.GetHalvingYearByHeight(std.GetHeight())
	uassert.Equal(t, int64(1), year)
}

func blockTime3000ms() {
	std.TestSetRealm(std.NewUserRealm(consts.ADMIN))
	gns.SetAvgBlockTimeInMsByAdmin(3000)
	std.TestSkipHeights(1)
}

func reachFirstHalving() {
	// current := 3942162
	// nextHalving := 11826135
	// 11826135 - 3942162 = 7883973

	std.TestSkipHeights(7883973)
	std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	gns.Mint(a2u(user01Addr))

	// minted all amount for first halving year
	uassert.Equal(t, uint64(225000000000000), gns.TotalMinted())

	// we're at the end of first halving year
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
