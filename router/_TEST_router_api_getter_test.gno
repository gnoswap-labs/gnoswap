package router

import (
	"encoding/gjson"
	"std"
	"testing"

	_ "gno.land/r/demo/grc20_wrapper"
	p "gno.land/r/demo/pool"
	pos "gno.land/r/demo/position"

	wugnot "gno.land/r/demo/wugnot"
)

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(test1)
	p.InitManual()
	std.TestSkipHeights(1)
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(test1)

	p.CreatePool(wgnotPath, barPath, fee100, 130621891405341611593710811006) // tick > -9999,  ratio = x0.3679346241605614   ( 1 bar = 0.37 wugnot )
	p.CreatePool(barPath, quxPath, fee100, 130621891405341611593710811006)   // tick = 10_000, ratio = x2.7181459268252253   ( 1 bar = 2.7 qux )
	p.CreatePool(quxPath, bazPath, fee100, 215353707227994575755767921544)   // tick > -20000, ratio =  x0.13534881653937755 ( 1 qux = 0.13 baz )

	jsonOutput := p.ApiGetPools()
	jsonStr := gjson.Parse(jsonOutput)
	shouldEQ(t, len(jsonStr.Get("response.data").Array()), 3)
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// simulate transfer & decrase
	std.TestSetOrigSend(std.Coins{{"ugnot", 10_000_000}}, nil)
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 10_000_000)

	// Deposit(wrap)
	std.TestSetPrevAddr(test1)
	wugnot.Deposit()

	pos.Mint(wgnotPath, barPath, fee100, int32(9000), int32(11000), bigint(10_000_000), bigint(10_000_000), 0, 0, max_timeout)

	pos.Mint(barPath, quxPath, fee100, int32(9000), int32(11000), bigint(10_000_000), bigint(10_000_000), 0, 0, max_timeout)
	pos.Mint(quxPath, bazPath, fee100, int32(18000), int32(22000), bigint(10_000_000), bigint(10_000_000), 0, 0, max_timeout)
}

func TestApiGetRatiosFromBase(t *testing.T) {
	jsonOutput := ApiGetRatiosFromBase()
	jsonStr := gjson.Parse(jsonOutput)
	jsonArr := jsonStr.Get("response").Array()
	shouldEQ(t, len(jsonArr), 4)

	shouldEQ(t, jsonArr[0].String(), "{\"gno.land/r/demo/wugnot\":79228162514264337593543950336}") // 1
	shouldEQ(t, jsonArr[1].String(), "{\"gno.land/r/demo/bar\":215332174010593516404127508794}")   // 2.7178741394
	shouldEQ(t, jsonArr[2].String(), "{\"gno.land/r/demo/qux\":585304271701315311476720143083}")   // 7.3875785217
	shouldEQ(t, jsonArr[3].String(), "{\"gno.land/r/demo/baz\":4323981266259057910270272221253}")  // 54.5763164138
}
