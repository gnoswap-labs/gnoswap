package pool

import (
	"std"
	"testing"

	"encoding/gjson"

	"gno.land/p/demo/testutils"
	"gno.land/r/demo/users"

	bar "gno.land/r/bar"
	foo "gno.land/r/foo"

	pos "gno.land/r/position"
)

var (
	gsa  = testutils.TestAddress("gsa")  // Gnoswap Admin
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01

	poolAddr = std.DerivePkgAddr("gno.land/r/pool")
)

// 1. Init
func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	InitManual()
	std.TestSkipHeights(1)
}

func TestCreatePool(t *testing.T) {
	CreatePool("foo", "bar", uint16(500), 130621891405341611593710811006)  // 2.7181459268
	CreatePool("foo", "bar", uint16(3000), 130621891405341611593710811006) // 2.7181459268
	std.TestSkipHeights(1)
}

func TestPositionMint500(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	_, _, m0, m1 := pos.Mint(
		"foo",       // token0
		"bar",       // token1
		uint16(500), // fee 3000 ~= tickSpacing  60
		6600,        // tickLower
		10200,       // tickUpper
		100,         // amount0Desired
		100,         // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		9999999999,  // deadline
	)
	shouldEQ(t, m0, bigint(2))
	shouldEQ(t, m1, bigint(99))
}

func TestPositionMint3000(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	_, _, m0, m1 := pos.Mint(
		"foo",        // token0
		"bar",        // token1
		uint16(3000), // fee 3000 ~= tickSpacing  60
		6600,         // tickLower
		10200,        // tickUpper
		1000,         // amount0Desired
		1000,         // amount1Desired
		0,            // amount0Min
		0,            // amount1Min
		9999999999,   // deadline
	)
	shouldEQ(t, m0, bigint(23))
	shouldEQ(t, m1, bigint(999))
}

func TestFindBestPoolTruePositive(t *testing.T) {
	bestPoolPathDetail := FindBestPool(
		"foo", // tokenA
		"bar", // tokenB
		true,  // zeroForOne
		200,   // amountSpecified
	)
	jsonStr := gjson.Parse(bestPoolPathDetail)
	shouldEQ(t, jsonStr.Get("response.data.pool_path").String(), "bar_foo_3000")

	// should return empty if not enough balance
	{
		bestPoolPathDetail := FindBestPool(
			"foo", // tokenA
			"bar", // tokenB
			true,  // zeroForOne
			438,   // amountSpecified
		)

		jsonStr := gjson.Parse(bestPoolPathDetail)
		shouldEQ(t, jsonStr.Get("response.data.pool_path").String(), "")
	}
}

func TestFindBestPoolTrueNegative(t *testing.T) {
	bestPoolPathDetail := FindBestPool(
		"foo", // tokenA
		"bar", // tokenB
		true,  // zeroForOne
		-888,  // amountSpecified
	)
	jsonStr := gjson.Parse(bestPoolPathDetail)
	shouldEQ(t, jsonStr.Get("response.data.pool_path").String(), "bar_foo_3000")
}

func TestFindBestPoolFalsePositive(t *testing.T) {
	bestPoolPathDetail := FindBestPool(
		"foo", // tokenA
		"bar", // tokenB
		false, // zeroForOne
		5,     // amountSpecified
	)
	jsonStr := gjson.Parse(bestPoolPathDetail)
	shouldEQ(t, jsonStr.Get("response.data.pool_path").String(), "bar_foo_3000")
}

func TestFindBestPoolFalseNegative(t *testing.T) {
	bestPoolPathDetail := FindBestPool(
		"foo", // tokenA
		"bar", // tokenB
		false, // zeroForOne
		-11,   // amountSpecified
	)
	jsonStr := gjson.Parse(bestPoolPathDetail)
	shouldEQ(t, jsonStr.Get("response.data.pool_path").String(), "bar_foo_3000")
}

func TestFindBestPoolWrong(t *testing.T) {
	shouldPanic(t, func() { FindBestPool("foo", "bar", true, 0) })
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
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

func fooBalance(addr std.Address) uint64 {
	user := users.AddressOrName(addr)
	return foo.BalanceOf(user)
}

func barBalance(addr std.Address) uint64 {
	user := users.AddressOrName(addr)
	return bar.BalanceOf(user)
}
