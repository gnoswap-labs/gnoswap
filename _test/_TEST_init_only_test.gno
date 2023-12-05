package tc

import (
	"encoding/gjson"
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"

	"gno.land/r/demo/users"

	// swap contract
	gov "gno.land/r/gov"
	pl "gno.land/r/pool"
	pos "gno.land/r/position"
	rou "gno.land/r/router"
	stk "gno.land/r/staker"

	// token
	_ "gno.land/r/grc20_wrapper"

	bar "gno.land/r/bar"
	foo "gno.land/r/foo"
	gns "gno.land/r/gns" // external reward
	// GRC721 LP Token
)

const (
	TIMESTAMP_90DAYS int64 = 7776000
)

var (
	// test address
	gsa  = testutils.TestAddress("gsa")  // Gnswap Admin
	pc01 = testutils.TestAddress("pc01") // Pool Creator 01
	ci01 = testutils.TestAddress("ci01") // Create Incentive Caller 01
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	lp02 = testutils.TestAddress("lp02") // Liquidity Provider 02
	tr01 = testutils.TestAddress("tr01") // Trader 01

	// contract address
	poolAddr   = pl.GetOrigPkgAddr()  // Pool Contract
	posAddr    = pos.GetOrigPkgAddr() // Position Contract
	stakerAddr = stk.GetOrigPkgAddr() // Staker Contract
	govAddr    = gov.GetOrigPkgAddr() // Gov Contract
	rouAddr    = rou.GetOrigPkgAddr() // Router Contract

	// token path
	fooPath = "gno.land/r/foo"
	barPath = "gno.land/r/bar"
	bazPath = "gno.land/r/baz"
	quxPath = "gno.land/r/qux"
	gnsPath = "gno.land/r/gns"
	oblPath = "gno.land/r/obl"

	gnotPath = "gnot"

	MIN_TICK bigint = -887272
	MAX_TICK bigint = 887272

	MIN_SQRT_RATIO bigint = 4295128739                                        // same as TickMathGetSqrtRatioAtTick(MIN_TICK)
	MAX_SQRT_RATIO bigint = 1461446703485210103287273052203988822378723970342 // same as TickMathGetSqrtRatioAtTick(MAX_TICK)

	MAX_TIMEOUT bigint = 9999999999
)

// func init() {
// 	// debug addr
// 	println(gsa, "// gsa")
// 	println(pc01, "// pc01")
// 	println(ci01, "// ci01")
// 	println(lp01, "// lp01")
// 	println(lp02, "// lp02")
// 	println(tr01, "// tr01")
// 	println(poolAddr, "// pool")
// 	println(posAddr, "// pos")
// 	println(rouAddr, "// router")
// 	println(stakerAddr, "// staker")
// 	println(govAddr, "// gov")
// }

func TestPoolInitManual(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	pl.InitManual()
	std.TestSkipHeights(1)

	shouldPanicWithMsg(t, func() { pl.InitManual() }, "[POOl] pool_manager.gno__InitManual() || contract must not be initialized")
}

func TestPoolCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	gsaOldGnsBalance := gns.BalanceOf(a2u(gsa))

	pl.CreatePool(gnotPath, barPath, uint16(100), 112040957517951813098925484553) // tick =  6_931, ratio = x1.99983634019692790850797337043331936001777648925781
	pl.CreatePool(barPath, bazPath, uint16(100), 112040957517951813098925484553)  // tick =  6_931, ratio = x1.99983634019692790850797337043331936001777648925781
	pl.CreatePool(bazPath, fooPath, uint16(100), 177157928842132501967358423881)  // tick =  16_095, ratio = x4.99990809049723150536692628520540893077850341796875
	pl.CreatePool(gnsPath, gnotPath, uint16(100), 79228162514264337593543950337)  // tick =  0, ratio = x1.00000000000000000000000000000000000000000000000000
	pl.CreatePool(gnsPath, quxPath, uint16(100), 250541420775534450580036817218)  // tick =  23_027, ratio = x9.99999779681069611569910193793475627899169921875000

	gsaNewGnsBalance := gns.BalanceOf(a2u(gsa))

	shouldEQ(t, len(pl.PoolGetPoolList()), 5)
	shouldEQ(t, gsaNewGnsBalance-gsaOldGnsBalance, 2500)
}

func TestPositionMintGnotBar(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(std.GetOrigCaller(), "ugnot", 1000)

	// simulate transfer & decrase
	std.TestSetOrigSend(std.Coins{{"ugnot", 1000}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 1000)

	tokenId, liquidity, amount0, amount1 := pos.Mint(
		gnotPath,       // token0 ( will be token1 )
		barPath,        // token1 ( will be token0 )
		uint16(100),    // fee
		int32(5932),    // tickLower
		int32(7932),    // tickUpper
		bigint(1000),   // amount0Desired
		bigint(999999), // amount1Desired
		0,              // amount0Min
		0,              // amount1Min
		MAX_TIMEOUT,    // deadline
	)
	std.TestSetOrigSend(std.Coins{}, nil)
	std.TestSkipHeights(1)

	shouldEQ(t, tokenId, 1)
	println("liquidity\t", liquidity)
	println("amount0(bar)\t", amount0)
	println("amount1(gnot)\t", amount1)
}

func TestPositionMintBarBaz(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	tokenId, liquidity, amount0, amount1 := pos.Mint(
		barPath,        // token0
		bazPath,        // token1
		uint16(100),    // fee
		int32(5932),    // tickLower
		int32(7932),    // tickUpper
		bigint(1000),   // amount0Desired
		bigint(999999), // amount1Desired
		0,              // amount0Min
		0,              // amount1Min
		MAX_TIMEOUT,    // deadline
	)
	std.TestSkipHeights(1)

	shouldEQ(t, tokenId, 2)
	println("liquidity\t", liquidity)
	println("amount0(bar)\t", amount0)
	println("amount1(baz)\t", amount1)
}

func TestPositionMintBazFoo(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	tokenId, liquidity, amount0, amount1 := pos.Mint(
		bazPath,        // token0
		fooPath,        // token1
		uint16(100),    // fee
		int32(15096),   // tickLower
		int32(17096),   // tickUpper
		bigint(1000),   // amount0Desired
		bigint(999999), // amount1Desired
		0,              // amount0Min
		0,              // amount1Min
		MAX_TIMEOUT,    // deadline
	)
	std.TestSkipHeights(1)

	shouldEQ(t, tokenId, 3)
	println("liquidity\t", liquidity)
	println("amount0(baz)\t", amount0)
	println("amount1(foo)\t", amount1)
}

func TestPositionMintGnsGnot(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(std.GetOrigCaller(), "ugnot", 1000)

	// simulate transfer & decrase
	std.TestSetOrigSend(std.Coins{{"ugnot", 1000}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 1000)

	tokenId, liquidity, amount0, amount1 := pos.Mint(
		gnsPath,      // token0
		gnotPath,     // token1
		uint16(100),  // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		bigint(1000), // amount0Desired
		bigint(1000), // amount1Desired
		0,            // amount0Min
		0,            // amount1Min
		MAX_TIMEOUT,  // deadline
	)
	std.TestSetOrigSend(std.Coins{}, nil)
	std.TestSkipHeights(1)

	shouldEQ(t, tokenId, 4)
	println("liquidity\t", liquidity)
	println("amount0(gns)\t", amount0)
	println("amount1(gnot)\t", amount1)
}

func TestPositionMintGnsQux(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	tokenId, liquidity, amount0, amount1 := pos.Mint(
		gnsPath,        // token0
		quxPath,        // token1
		uint16(100),    // fee
		int32(22028),   // tickLower
		int32(24028),   // tickUpper
		bigint(1000),   // amount0Desired
		bigint(999999), // amount1Desired
		0,              // amount0Min
		0,              // amount1Min
		MAX_TIMEOUT,    // deadline
	)
	std.TestSkipHeights(1)

	shouldEQ(t, tokenId, 5)
	println("liquidity\t", liquidity)
	println("amount0(gns)\t", amount0)
	println("amount1(qux)\t", amount1)
}

// TEST RATIOS
func TestRouterApiGetRatiosFromBase(t *testing.T) {
	jsonStr := gjson.Parse(rou.ApiGetRatiosFromBase())
	jsonArr := jsonStr.Get("response.data").Array()

	shouldEQ(t, jsonArr[0].String(), "{\"gnot\":79228162514264337593543950336}")             // 1
	shouldEQ(t, jsonArr[1].String(), "{\"gno.land/r/bar\":158427515811472657639193234591}")  // 1.9996363766
	shouldEQ(t, jsonArr[2].String(), "{\"gno.land/r/baz\":316829103406906364771139440526}")  // 3.998945493
	shouldEQ(t, jsonArr[3].String(), "{\"gno.land/r/foo\":1584116397429175401616934621999}") // 19.994359924
	shouldEQ(t, jsonArr[4].String(), "{\"gno.land/r/gns\":79228162514264337593543950334}")   // 1
	shouldEQ(t, jsonArr[5].String(), "{\"gno.land/r/qux\":792281450588003167884250659067}")  // 9.9999977968
}

/* UTILS */
func token0Balance(addr std.Address) bigint {
	return bigint(foo.BalanceOf(a2u(addr)))
}

func token1Balance(addr std.Address) bigint {
	return bigint(bar.BalanceOf(a2u(addr)))
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic("[TC - POSITION] test_helper.gno__tid() || tokenId is nil")
	}

	switch tokenId.(type) {
	case bigint:
		return grc721.TokenID(string(tokenId.(bigint)))
	case string:
		return grc721.TokenID(tokenId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(tokenId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(tokenId.(uint64))))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic("[TC - STAKER] utils.gno__tid() || unsupported tokenId type")
	}
}

func BalanceOf(token *grc20.AdminToken, addr std.Address) bigint {
	balance, err := token.BalanceOf(addr)
	if err != nil {
		panic(err)
	}
	return bigint(balance)
}

/* HELPERS */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if l <= r {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if l >= r {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldPanicWithMsg(t *testing.T, f func(), msg string) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("The code did not panic")
		} else {
			if r != msg {
				t.Errorf("excepted panic(%v), got(%v)", msg, r)
			}
		}
	}()
	f()
}

func ugnotBalance(addr std.Address) uint64 {
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	return uint64(testBanker.GetCoins(addr)[0].Amount)
}
