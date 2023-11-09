// EXTERNAL API
package router

import (
	"encoding/gjson"
	"std"
	"testing"

	p "gno.land/r/pool"
	pos "gno.land/r/position"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"
)

var (
	pc01 = testutils.TestAddress("pc01") // Pool Creator 01
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01

	// Common
	wugnotPath = "gno.land/r/wugnot"
	barPath    = "gno.land/r/bar"
	bazPath    = "gno.land/r/baz"
	quxPath    = "gno.land/r/qux"

	test_fee100 = uint16(100)

	max_timeout = bigint(9999999999)
)

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(pc01)
	p.InitManual()
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	p.CreatePool(wugnotPath, barPath, test_fee100, 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253	// 1 bar == 2.7 foo
	p.CreatePool(barPath, bazPath, test_fee100, 130621891405341611593710811006)    // tick = 10_000, ratio = 2.7181459268252253	// 1 bar == 2.7 baz
	p.CreatePool(bazPath, quxPath, test_fee100, 130621891405341611593710811006)    // tick = 10_000, ratio = 2.7181459268252253	// 1 baz == 2.7 qux
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(std.GetOrigCaller(), "ugnot", 10000001)

	// simulate transfer & decrase
	std.TestSetOrigSend(std.Coins{{"ugnot", 10000000}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 10000000)

	pos.Mint(wugnotPath, barPath, test_fee100, int32(9000), int32(11000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)
	pos.Mint(barPath, bazPath, test_fee100, int32(9000), int32(11000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)
	pos.Mint(bazPath, quxPath, test_fee100, int32(9000), int32(11000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)
}

func TestApiGetRatiosFromBase(t *testing.T) {
	jsonStr := ApiGetRatiosFromBase()
	jsonOutput := gjson.Parse(jsonStr)

	shouldEQ(t, len(jsonOutput.Get("response.data").Array()), 4)
	shouldEQ(t, jsonOutput.Get("response.data.0").String(), "{\"gno.land/r/wugnot\":79228162514264337593543950336}")
	shouldEQ(t, jsonOutput.Get("response.data.1").String(), "{\"gno.land/r/bar\":29147869410676662479573841822}")
	shouldEQ(t, jsonOutput.Get("response.data.2").String(), "{\"gno.land/r/baz\":79228162514264337593543950333}")
	shouldEQ(t, jsonOutput.Get("response.data.3").String(), "{\"gno.land/r/qux\":215353707227994575755767921538}")
	/*
		len(tokenPrice): 4

		token: gno.land/r/wugnot
		price: 79228162514264337593543950336 ~= 1

		token: gno.land/r/bar
		price: 29147869410676662479573841822 ~= 0.3678978344

		token: gno.land/r/baz
		price: 79228162514264337593543950333 ~= 1

		token: gno.land/r/qux
		price: 215353707227994575755767921538 ~= 2.7181459268
	*/
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}
