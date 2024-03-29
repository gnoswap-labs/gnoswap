package router

import (
	// @notJoon JSON
	"std"
	"testing"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/consts"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/qux"
	"gno.land/r/demo/wugnot"
)

func TestPoolCreatePool(t *testing.T) {
	std.TestSetPrevAddr(test1)
	for i := 0; i < (5 * 10); i++ {
		gns.Faucet()
	}

	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE*10)

	// 1 HOPS
	pl.CreatePool(barPath, consts.WRAPPED_WUGNOT, fee100, common.TickMathGetSqrtRatioAtTick(10_000).ToString())
	pl.CreatePool(barPath, consts.WRAPPED_WUGNOT, fee500, common.TickMathGetSqrtRatioAtTick(20_000).ToString())
	pl.CreatePool(barPath, consts.WRAPPED_WUGNOT, fee3000, common.TickMathGetSqrtRatioAtTick(60_000).ToString()) // NOT USED BY SMALL LIQ
	// -10_000 0.367897
	// -20_000 0.135348
	// 0.367897 + 0.135348 = 0.503245
	// 0.503245 / 2 = 0.2516225
	// 1 WGNOT = 0.2516225 BAR

	// 2 HOPS
	pl.CreatePool(consts.WRAPPED_WUGNOT, quxPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString()) // 1:1
	pl.CreatePool(quxPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(50_000).ToString())
	pl.CreatePool(quxPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(60_000).ToString())
	pl.CreatePool(quxPath, fooPath, fee3000, common.TickMathGetSqrtRatioAtTick(100_000).ToString()) // NOT USED BY SMALL LIQ
	// 50_000 148.376062
	// 60_000 403.307791
	// 148.376062 + 403.307791 = 551.683853
	// 551.683853 / 2 = 275.8419265
	// 1 WGNOT = 275.8419265 FOO

	// 3 HOPS
	pl.CreatePool(consts.WRAPPED_WUGNOT, bazPath, fee100, common.TickMathGetSqrtRatioAtTick(6932).ToString()) // 1:2
	pl.CreatePool(bazPath, oblPath, fee100, common.TickMathGetSqrtRatioAtTick(6932).ToString())               // 1:2
	pl.CreatePool(oblPath, consts.GNS_PATH, fee100, common.TickMathGetSqrtRatioAtTick(6932).ToString())       // 1:2
	// 1 GNOT = 8 GNS
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(test1, "ugnot", 100_000_000_000)
	std.TestSetOrigSend(std.Coins{{"ugnot", 100_000_000_000}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 100_000_000_000)

	// Deposit(wrap)
	std.TestSetPrevAddr(test1)
	wugnot.Deposit()

	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	wugnot.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	pn.Mint(barPath, consts.WRAPPED_WUGNOT, fee100, 8000, 12000, "100000000", "100000000", "0", "0", max_timeout, test1.String())
	pn.Mint(barPath, consts.WRAPPED_WUGNOT, fee500, 18000, 22000, "80000000", "80000000", "0", "0", max_timeout, test1.String())
	pn.Mint(barPath, consts.WRAPPED_WUGNOT, fee3000, 58020, 62040, "10000000", "10000000", "0", "0", max_timeout, test1.String())

	pn.Mint(quxPath, fooPath, fee100, 48000, 52000, "100000000", "100000000", "0", "0", max_timeout, test1.String())
	pn.Mint(quxPath, fooPath, fee500, 58000, 62000, "80000000", "80000000", "0", "0", max_timeout, test1.String())
	pn.Mint(quxPath, fooPath, fee3000, 98040, 10020, "100000", "100000", "0", "0", max_timeout, test1.String())

	// pn.Mint(fooPath, consts.GNS_PATH, fee100, 48000, 52000, "100000000", "100000000","0", "0" max_timeout, test1.String())
}

// @notJoon JSON
// func TestApiGetRatiosFromBase(t *testing.T) {
// 	std.TestSetOrigCaller(test1)

// 	ratios := ApiGetRatiosFromBase()
// 	jsonStr := gjson.Parse(ratios)

// 	responseArr := gjson.Get(jsonStr.String(), "response").Array()
// 	shouldEQ(t, len(responseArr), 7)
// 	/*
// 		{"token":"gno.land/r/demo/wugnot","ratio":79228162514264337593543950336}
// 		{"token":"gno.land/r/demo/bar","ratio":19935653721785907863909200771}
// 		{"token":"gno.land/r/demo/qux","ratio":79228162514264337593543950338}
// 		{"token":"gno.land/r/demo/foo","ratio":21827358772679825007021358318119}
// 		{"token":"gno.land/r/demo/baz","ratio":158459202898910110285447649633}
// 		{"token":"gno.land/r/demo/obl","ratio":316918405797820220570895299266}
// 		{"token":"gno.land/r/demo/gns","ratio":633836811595640441141790598532}
// 	*/

// 	shouldEQ(t, responseArr[0].Get("token").String(), "gno.land/r/demo/wugnot")
// 	shouldEQ(t, responseArr[0].Get("ratio").String(), "79228162514264337593543950336")

// 	shouldEQ(t, responseArr[1].Get("token").String(), "gno.land/r/demo/bar")
// 	shouldEQ(t, responseArr[1].Get("ratio").String(), "19935653721785907863909200771")

// 	shouldEQ(t, responseArr[2].Get("token").String(), "gno.land/r/demo/qux")
// 	shouldEQ(t, responseArr[2].Get("ratio").String(), "79228162514264337593543950338")

// 	shouldEQ(t, responseArr[3].Get("token").String(), "gno.land/r/demo/foo")
// 	shouldEQ(t, responseArr[3].Get("ratio").String(), "21827358772679825007021358318119")

// 	shouldEQ(t, responseArr[4].Get("token").String(), "gno.land/r/demo/baz")
// 	shouldEQ(t, responseArr[4].Get("ratio").String(), "158459202898910110285447649633")

// 	shouldEQ(t, responseArr[5].Get("token").String(), "gno.land/r/demo/obl")
// 	shouldEQ(t, responseArr[5].Get("ratio").String(), "316918405797820220570895299266")

// 	shouldEQ(t, responseArr[6].Get("token").String(), "gno.land/r/demo/gns")
// 	shouldEQ(t, responseArr[6].Get("ratio").String(), "633836811595640441141790598532")
// }
