package gnoswap

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/r/demo/users"

	bar "gno.land/r/bar"
	foo "gno.land/r/foo"

	g "gno.land/r/gov"
)

var (
	gsa = testutils.TestAddress("gsa") // Gnoswap Admin

	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01

	tr01 = testutils.TestAddress("tr01") // Trader 01
)

func init() {
	// debug - print addr
	println(lp01, "// lp01")
	println(tr01, "// tr01")
	println(GetOrigPkgAddr(), "// pool")
}

var (
	// Common
	pToken0 = "foo"
	pToken1 = "bar"
	pFee    = uint16(500)

	test_tickLower       = int32(9000)
	test_tickUpper       = int32(11000)
	test_liquidityExpect = bigint(1000)
)

// 1. Init & Create Pool by gsa
func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	InitManual()
	std.TestSkipHeights(1)

	println("> Init")
	println(ApiGetPools())
	println(ApiGetPool("bar_foo_500"))
	println()

	println("> CreatePool")
	CreatePool("foo", "bar", pFee, 130622891405341611593710811006)
	std.TestSkipHeights(1)
	// 130621891405341611593710811006 // 9999
	// 130622891405341611593710811006 // 10000
	// fee
	// 500		= 0.05% // USv3 default
	// 3000		= 0.3% // USv3 default
	// 10000	= 1% // USv3 default
	println(ApiGetPools())
	println(ApiGetPool("bar_foo_500"))
	println()

	// sqrtPrice
	// 130621891405341611593710811006 // tick = 10000
	shouldPanic(t, func() { CreatePool("foo", "bar", 500, 130621891405341611593710811006) })
	std.TestSkipHeights(1)

	// Approve
	println("> Approve")
	std.TestSetOrigCaller(lp01)
	foo.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	bar.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	foo.Approve(users.AddressOrName(lp01), 50000000)
	bar.Approve(users.AddressOrName(lp01), 50000000)
	std.TestSkipHeights(4)

	std.TestSetOrigCaller(tr01)
	foo.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	bar.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	foo.Approve(users.AddressOrName(tr01), 50000000)
	bar.Approve(users.AddressOrName(tr01), 50000000)
	std.TestSkipHeights(4)

	println(ApiGetPools())
	println(ApiGetPool("bar_foo_500"))
	println()
}

// Swap by tr01, Mint by lp01 ~ 02
func TestSwap(t *testing.T) {
	pool := GetPool(pToken0, pToken1, pFee)

	// lp01 mint 9000 ~ 11000 tick range
	std.TestSetOrigCaller(lp01)
	println("> Mint foo, bar, 500, lp01, 9000, 11000, 10000000")
	m11, m12 := Mint(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, test_liquidityExpect*100000)

	std.TestSkipHeights(1)
	println(ApiGetPools())
	println(ApiGetPool("bar_foo_500"))
	println()

	test_price_01 := bigint(MIN_SQRT_RATIO + 1) // maximum price // swap 0 -> 1
	test_price_10 := bigint(MAX_SQRT_RATIO - 1) // minimum price // swap 1 -> 0

	{
		println("> Swap")

		// SWAP
		std.TestSetOrigCaller(tr01)

		Swap(pToken0, pToken1, pFee, tr01, true, bigint(150000), test_price_01)
		Swap(pToken0, pToken1, pFee, tr01, false, bigint(601851), test_price_10)
		// Swap(pToken0, pToken1, pFee, tr01, true, bigint(1500000), test_price_01) // two iteration // s0: 1_500_000 // s1: -3_626_984 // currentTick: 7668
		std.TestSkipHeights(1)
		println(ApiGetPools())
		println(ApiGetPool("bar_foo_500"))
		println()

		// To collect fee without removing liquidity
		// burn 0 => collect

		std.TestSetOrigCaller(lp01)
		println("> Burn foo, bar, 500, 9000, 11000, 0")
		Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, 0)
		std.TestSkipHeights(1)
		println(ApiGetPools())
		println(ApiGetPool("bar_foo_500"))
		println()

		println("> Collect foo, bar, 500, lp01, 9000, 11000, 100000000, 100000000")
		Collect(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, 100000000, 100000000)
		std.TestSkipHeights(1)
		println(ApiGetPools())
		println(ApiGetPool("bar_foo_500"))
		println()
	}
}

// GOV
func TestSubmitProposalParameterProtocolFees(t *testing.T) {
	// Init GOV Contract
	g.Init()

	id := SubmitProposalParameterProtocolFees(
		"protocol fee change",  // title
		"change protocol fees", // summary
		"",                     // metadata
		0,                      // initialDeposit

		8,  // newFee0
		10, // newFee1
	)
	shouldEQ(t, id, uint64(1))
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

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}
