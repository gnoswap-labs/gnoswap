package oneclick

import (
	"std"
	"testing"

	pl "gno.land/r/demo/pool"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/wugnot"

	"gno.land/r/demo/consts"
)

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	pl.InitManual()

	std.TestSetPrevAddr(test1)
	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE)

	pl.CreatePool(barPath, consts.WRAPPED_WUGNOT, fee500, "130621891405341611593710811006") // tick = 10000
}

func TestOneClickMintInRange(t *testing.T) {
	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	wugnot.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(2)

	// send ugnot
	std.TestIssueCoins(test1, std.Coins{{"ugnot", 10000000}})
	std.TestSetOrigSend(std.Coins{{"ugnot", 10000000}}, nil)
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 10000000)

	lpTokenId, liquidity, amount0, amount1 := OneClickMint(
		barPath,      // token0
		consts.GNOT,  // token1
		uint16(500),  // fee
		int32(9000),  // tickLower
		int32(11000), // tickUpper
		"10000000",   // amount0Desired
		"10000000",   // amount1Desired
		"0",          // amount0Min
		"0",          // amount1Min
		max_timeout,  // deadline
	)
	shouldEQ(t, lpTokenId, 1)
	// println("liquidity", liquidity)
	// println("amount0", amount0)
	// println("amount1", amount1)
	shouldEQ(t, amount0, "3678979")
	shouldEQ(t, amount1, "9999999")
}

// upper range => wugnot is 0
func TestOneClickMintUpperRange(t *testing.T) { // GNOT & BAR
	std.TestSetPrevAddr(test1)
	wugnot.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX) // for pool to mint
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)    // for pool to mint

	// for position to refund left wugnot to user in NATIVE (GNOT) COIN
	// user have to approve enough amount of wugnot to position
	// or refund will panic (not fail, BUT PANIC)
	wugnot.Approve(a2u(consts.POSITION_ADDR), consts.UINT64_MAX)

	// DO NOT SEND
	// std.TestIssueCoins(test1, std.Coins{{"ugnot", 10000000}})
	// std.TestSetOrigSend(std.Coins{{"ugnot", 10000000}}, nil)
	// testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	// testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 10000000)

	lpTokenId, liquidity, amount0, amount1 := OneClickMint(
		barPath,
		consts.GNOT,
		fee500,
		12000,
		14000,
		"10000000",
		"10000000",
		"0",
		"0",
		max_timeout,
	)
	shouldEQ(t, lpTokenId, 2)
	// println("liquidity", liquidity)
	shouldEQ(t, amount1, "0")
}
