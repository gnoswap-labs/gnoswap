package router

import (
	"encoding/gjson"
	"std"
	"testing"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"

	"gno.land/p/demo/common"

	"gno.land/r/demo/wugnot"
)

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(test1)
	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestPoolCreatePool(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// 1 HOPS
	pl.CreatePool(barPath, wgnotPath, fee100, common.TickMathGetSqrtRatioAtTick(10_000))
	pl.CreatePool(barPath, wgnotPath, fee500, common.TickMathGetSqrtRatioAtTick(20_000))
	pl.CreatePool(barPath, wgnotPath, fee3000, common.TickMathGetSqrtRatioAtTick(60_000)) // NOT USED BY SMALL LIQ
	// -10_000 0.367897
	// -20_000 0.135348
	// 0.367897 + 0.135348 = 0.503245
	// 0.503245 / 2 = 0.2516225
	// 1 WGNOT = 0.2516225 BAR

	// 2 HOPS
	pl.CreatePool(wgnotPath, quxPath, fee100, common.TickMathGetSqrtRatioAtTick(0)) // 1:1
	pl.CreatePool(quxPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(50_000))
	pl.CreatePool(quxPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(60_000))
	pl.CreatePool(quxPath, fooPath, fee3000, common.TickMathGetSqrtRatioAtTick(100_000)) // NOT USED BY SMALL LIQ
	// 50_000 148.376062
	// 60_000 403.307791
	// 148.376062 + 403.307791 = 551.683853
	// 551.683853 / 2 = 275.8419265
	// 1 WGNOT = 275.8419265 BAR

	// 3 HOPS
	pl.CreatePool(wgnotPath, bazPath, fee100, common.TickMathGetSqrtRatioAtTick(6932)) // 1:2
	pl.CreatePool(bazPath, oblPath, fee100, common.TickMathGetSqrtRatioAtTick(6932))   // 1:2
	pl.CreatePool(oblPath, gnsPath, fee100, common.TickMathGetSqrtRatioAtTick(6932))   // 1:2
	// 1 GNOT = 8 GNS
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// wugnot prepare
	std.TestSetOrigSend(std.Coins{{"ugnot", 100_000_000_000}}, nil)
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 100_000_000_000)

	// Deposit(wrap)
	std.TestSetPrevAddr(test1)
	wugnot.Deposit()

	pn.Mint(barPath, wgnotPath, fee100, 8000, 12000, 100_000_000, 100_000_000, 0, 0, max_timeout)
	pn.Mint(barPath, wgnotPath, fee500, 18000, 22000, 80_000_000, 80_000_000, 0, 0, max_timeout)
	pn.Mint(barPath, wgnotPath, fee3000, 58020, 62040, 10_000_000, 10_000_000, 0, 0, max_timeout)

	pn.Mint(quxPath, fooPath, fee100, 48000, 52000, 100_000_000, 100_000_000, 0, 0, max_timeout)
	pn.Mint(quxPath, fooPath, fee500, 58000, 62000, 80_000_000, 80_000_000, 0, 0, max_timeout)
	pn.Mint(quxPath, fooPath, fee3000, 98040, 10020, 10_000_000, 10_000_000, 0, 0, max_timeout)

	// pn.Mint(fooPath, gnsPath, fee100, 48000, 52000, 100_000_000, 100_000_000, 0, 0, max_timeout)
}

func TestApiGetRatiosFromBase(t *testing.T) {
	std.TestSetOrigCaller(test1)

	ratios := ApiGetRatiosFromBase()
	jsonStr := gjson.Parse(ratios)

	responseArr := gjson.Get(jsonStr.String(), "response").Array()
	shouldEQ(t, len(responseArr), 7)
	/*
		{"token":"gno.land/r/demo/wugnot","ratio":79228162514264337593543950336}
		{"token":"gno.land/r/demo/bar","ratio":19935653721785907863909200771}
		{"token":"gno.land/r/demo/qux","ratio":79228162514264337593543950338}
		{"token":"gno.land/r/demo/foo","ratio":21854449020437189859372345675086}
		{"token":"gno.land/r/demo/baz","ratio":158459202898910110285447649633}
		{"token":"gno.land/r/demo/obl","ratio":316924161643118367991168631863}
		{"token":"gno.land/r/demo/gns","ratio":633859835185907382391729498087}
	*/

	shouldEQ(t, responseArr[0].Get("token").String(), "gno.land/r/demo/wugnot")
	shouldEQ(t, responseArr[0].Get("ratio").String(), "79228162514264337593543950336")

	shouldEQ(t, responseArr[1].Get("token").String(), "gno.land/r/demo/bar")
	shouldEQ(t, responseArr[1].Get("ratio").String(), "19935653721785907863909200771")

	shouldEQ(t, responseArr[2].Get("token").String(), "gno.land/r/demo/qux")
	shouldEQ(t, responseArr[2].Get("ratio").String(), "79228162514264337593543950338")

	shouldEQ(t, responseArr[3].Get("token").String(), "gno.land/r/demo/foo")
	shouldEQ(t, responseArr[3].Get("ratio").String(), "21854449020437189859372345675086")

	shouldEQ(t, responseArr[4].Get("token").String(), "gno.land/r/demo/baz")
	shouldEQ(t, responseArr[4].Get("ratio").String(), "158459202898910110285447649633")

	shouldEQ(t, responseArr[5].Get("token").String(), "gno.land/r/demo/obl")
	shouldEQ(t, responseArr[5].Get("ratio").String(), "316924161643118367991168631863")

	shouldEQ(t, responseArr[6].Get("token").String(), "gno.land/r/demo/gns")
	shouldEQ(t, responseArr[6].Get("ratio").String(), "633859835185907382391729498087")
}
