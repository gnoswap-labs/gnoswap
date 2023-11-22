package router

import (
	"encoding/gjson"
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"
	p "gno.land/r/pool"
	pos "gno.land/r/position"
)

var (
	pc01 = testutils.TestAddress("pc01") // Pool Creator 01
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	tr01 = testutils.TestAddress("tr01") // Trader 01

	poolAddr   = std.DerivePkgAddr("gno.land/r/pool")
	posAddr    = std.DerivePkgAddr("gno.land/r/position")
	routerAddr = std.DerivePkgAddr("gno.land/r/router")
)

var (
	// Common
	wugnotPath = "gno.land/r/wugnot" // token1
	barPath    = "gno.land/r/bar"    // token2
	bazPath    = "gno.land/r/baz"    // token3
	quxPath    = "gno.land/r/qux"    // token4

	test_fee100 = uint16(100)

	max_timeout = bigint(9999999999)
)

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(pc01)
	p.InitManual()
	std.TestSkipHeights(1)
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	p.CreatePool(wugnotPath, barPath, test_fee100, 130621891405341611593710811006) // tick > -9999,  ratio = x0.3679346241605614   ( 1 bar = 0.37 wugnot )
	p.CreatePool(barPath, quxPath, test_fee100, 130621891405341611593710811006)    // tick = 10_000, ratio = x2.7181459268252253   ( 1 bar = 2.7 qux )
	p.CreatePool(quxPath, bazPath, test_fee100, 215353707227994575755767921544)    // tick > -20000, ratio =  x0.13534881653937755 ( 1 qux = 0.13 baz )

	jsonOutput := p.ApiGetPools()
	jsonStr := gjson.Parse(jsonOutput)
	shouldEQ(t, len(jsonStr.Get("response.data").Array()), 3)
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(std.GetOrigCaller(), "ugnot", 50000000)

	// simulate transfer & decrase
	std.TestSetOrigSend(std.Coins{{"ugnot", 10000000}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 10000000)
	pos.Mint(wugnotPath, barPath, test_fee100, int32(9000), int32(11000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)

	pos.Mint(barPath, quxPath, test_fee100, int32(9000), int32(11000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)
	pos.Mint(quxPath, bazPath, test_fee100, int32(18000), int32(22000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)
}

func TestApiGetRatiosFromBase(t *testing.T) {
	jsonOutput := ApiGetRatiosFromBase()
	jsonStr := gjson.Parse(jsonOutput)
	jsonArr := jsonStr.Get("response.data").Array()
	shouldEQ(t, len(jsonArr), 4)

	shouldEQ(t, jsonArr[0].String(), "{\"gno.land/r/wugnot\":79228162514264337593543950336}") // 1
	shouldEQ(t, jsonArr[1].String(), "{\"gno.land/r/bar\":215332174010593516404127508794}")   // 2.7178741394
	shouldEQ(t, jsonArr[2].String(), "{\"gno.land/r/qux\":585304271701315311476720143083}")   // 7.3875785217
	shouldEQ(t, jsonArr[3].String(), "{\"gno.land/r/baz\":4323981266259057910270272221253}")  // 54.5763164138
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}
