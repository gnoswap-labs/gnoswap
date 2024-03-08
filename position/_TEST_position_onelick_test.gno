package position

import (
	"std"
	"testing"

	"gno.land/r/demo/consts"

	pl "gno.land/r/demo/pool"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/wugnot"
)

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	pl.InitManual()

	std.TestSetPrevAddr(test1)
	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE)

	pl.CreatePool(consts.WRAPPED_WUGNOT, barPath, fee500, "130621891405341611593710811006") // tick = 10000
}

func TestNativeMint01InRange(t *testing.T) { // GNOT & BAR
	std.TestSetPrevAddr(test1)
	wugnot.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX) // for pool to mint
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)    // for pool to mint

	// for position to refund left wugnot to user in NATIVE (GNOT) COIN
	// user have to approve enough amount of wugnot to position
	// or refund will panic (not fail, BUT PANIC)
	wugnot.Approve(a2u(consts.POSITION_ADDR), consts.UINT64_MAX)

	// send
	std.TestIssueCoins(test1, std.Coins{{"ugnot", 10000000}})
	std.TestSetOrigSend(std.Coins{{"ugnot", 10000000}}, nil)
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 10000000)

	tokenId, liquidity, amount0, amount1 := NativeMint(
		consts.GNOT,
		barPath,
		fee500,
		8000,
		12000,
		"10000000",
		"10000000",
		"0",
		"0",
		max_timeout,
	)
	shouldEQ(t, tokenId, 1)
	// println("liquidity", liquidity)
	// println("amount0", amount0)
	// println("amount1", amount1)
	shouldEQ(t, amount0, "10000000")
	shouldEQ(t, amount1, "3678978")
}

// lower range => wugnot is 0
func TestNativeMint02LowerRange(t *testing.T) { // GNOT & BAR
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

	tokenId, liquidity, amount0, amount1 := NativeMint(
		consts.GNOT,
		barPath,
		fee500,
		12000,
		14000,
		"10000000",
		"10000000",
		"0",
		"0",
		max_timeout,
	)
	shouldEQ(t, tokenId, 2)
	shouldEQ(t, amount0, "0")
}
