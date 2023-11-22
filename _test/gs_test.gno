package tc

import (
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
	// external reward
	// GRC721 LP Token
)

const (
	TIMESTAMP_90DAYS int64  = 7776000
	Q96              bigint = 79228162514264337593543950336           // 2 ** 96
	Q128             bigint = 340282366920938463463374607431768211456 // 2 ** 128
)

var (
	// test address
	gsa  = testutils.TestAddress("gsa")  // Gnswap Admin
	pc01 = testutils.TestAddress("pc01") // Pool Creator 01
	ci01 = testutils.TestAddress("ci01") // Create Incentive Caller 01
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	lp02 = testutils.TestAddress("lp02") // Liquidity Provider 02
	lp03 = testutils.TestAddress("lp03") // Liquidity Provider 03
	tr01 = testutils.TestAddress("tr01") // Trader 01

	// contract address
	poolAddr   = pl.GetOrigPkgAddr()  // Pool Contract
	posAddr    = pos.GetOrigPkgAddr() // Position Contract
	stakerAddr = stk.GetOrigPkgAddr() // Staker Contract
	govAddr    = gov.GetOrigPkgAddr() // Gov Contract
	rouAddr    = rou.GetOrigPkgAddr() // Router Contract

	// token path
	fooPath    = "gno.land/r/foo"
	barPath    = "gno.land/r/bar"
	bazPath    = "gno.land/r/baz"
	quxPath    = "gno.land/r/qux"
	wugnotPath = "gno.land/r/wugnot"
	gnsPath    = "gno.land/r/gns"
	oblPath    = "gno.land/r/obl"

	MIN_TICK bigint = -887272
	MAX_TICK bigint = 887272

	MIN_SQRT_RATIO bigint = 4295128739                                        // same as TickMathGetSqrtRatioAtTick(MIN_TICK)
	MAX_SQRT_RATIO bigint = 1461446703485210103287273052203988822378723970342 // same as TickMathGetSqrtRatioAtTick(MAX_TICK)

	MAX_TIMEOUT bigint = 9999999999
)

func init() {
	// debug addr
	println(gsa, "// gsa")
	println(pc01, "// pc01")
	println(ci01, "// ci01")
	println(lp01, "// lp01")
	println(lp02, "// lp02")
	println(tr01, "// tr01")
	println(poolAddr, "// pool")
	println(posAddr, "// pos")
	println(rouAddr, "// router")
	println(stakerAddr, "// staker")
	println(govAddr, "// gov")
}

// 1. [TC - POOL] Init
func TestPoolInitManual(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	pl.InitManual()
	std.TestSkipHeights(1)
}

// 2. [TC - POOL] Create Multi Pool
func TestPoolCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	pl.CreatePool(barPath, bazPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, tick_spacing = 2, ratio = 7181459268252253
	std.TestSkipHeights(1)
}

// 3. [TC - POSITION] Mint LP
func TestPositionMintLP01(t *testing.T) {
	// bar_baz_100 by lp01
	std.TestSetOrigCaller(lp01)

	tokenId, liquidity, amount0, amount1 := pos.Mint(barPath, bazPath, uint16(100), int32(9000), int32(11000), bigint(10000000), bigint(10000000), 0, 0, MAX_TIMEOUT)
	std.TestSkipHeights(1)

	println("LP01 tokenId:\t", tokenId)
	println("LP01 liquidity:\t", liquidity)
	println("LP01 amount0:\t", amount0)
	println("LP01 amount1:\t", amount1)
	println()
}

func TestPositionMintLP02Lower(t *testing.T) {
	// bar_baz_100 by lp02
	std.TestSetOrigCaller(lp02)

	tokenId, liquidity, amount0, amount1 := pos.Mint(barPath, bazPath, uint16(100), int32(9000), int32(9998), bigint(10000000), bigint(10000000), 0, 0, MAX_TIMEOUT)
	std.TestSkipHeights(1)

	println("LP02 tokenId:\t", tokenId)
	println("LP02 liquidity:\t", liquidity)
	println("LP02 amount0:\t", amount0)
	println("LP02 amount1:\t", amount1)
	println()
}

func TestPositionMintLP03Higher(t *testing.T) {
	// bar_baz_100 by lp02
	std.TestSetOrigCaller(lp03)

	tokenId, liquidity, amount0, amount1 := pos.Mint(barPath, bazPath, uint16(100), int32(10002), int32(11000), bigint(10000000), bigint(10000000), 0, 0, MAX_TIMEOUT)
	std.TestSkipHeights(1)

	println("LP03 tokenId:\t", tokenId)
	println("LP03 liquidity:\t", liquidity)
	println("LP03 amount0:\t", amount0)
	println("LP03 amount1:\t", amount1)
	println()
}

func TestSwapBarToBaz(t *testing.T) {
	std.TestSetPrevRealm("gno.land/r/router")
	std.TestSetOrigCaller(tr01)

	tr01OldBarBalance := bar.BalanceOf(a2u(tr01))
	tr01OldBazBalance := baz.BalanceOf(a2u(tr01))
	poolOldBarBalance := bar.BalanceOf(a2u(poolAddr))
	poolOldBazBalance := baz.BalanceOf(a2u(poolAddr))

	swapAmount := 123_456
	rou.SwapRoute(
		barPath,
		bazPath,
		bigint(swapAmount),
		"EXACT_IN",
		"gno.land/r/bar:gno.land/r/baz:100",
		"100",
		200_000,
	)

	tr01NewBarBalance := bar.BalanceOf(a2u(tr01))
	tr01NewBazBalance := baz.BalanceOf(a2u(tr01))
	poolNewBarBalance := bar.BalanceOf(a2u(poolAddr))
	poolNewBazBalance := baz.BalanceOf(a2u(poolAddr))

	shouldEQ(t, tr01OldBarBalance-tr01NewBarBalance, bigint(123400))
	shouldEQ(t, tr01NewBazBalance > tr01OldBazBalance, true)
	shouldEQ(t, poolNewBarBalance-poolOldBarBalance, bigint(123400))
	shouldEQ(t, poolNewBazBalance < poolOldBazBalance, true)
}

// 8. [TC - ROUTER] SwapRoute ExactOut Multi ( wugnot -> qux )
func TestRotuerSwapRouteExactOutputMultiPath(t *testing.T) {
	std.TestSetPrevRealm("gno.land/r/router")
	std.TestSetOrigCaller(tr01)

	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(std.GetOrigCaller(), "ugnot", 500_000_000)

	tr01OldWugnotBalance := wugnot.BalanceOf(a2u(tr01))
	tr01OldQuxBalance := qux.BalanceOf(a2u(tr01))
	poolOldWugnotBalance := wugnot.BalanceOf(a2u(poolAddr))
	poolOldQuxBalance := qux.BalanceOf(a2u(poolAddr))

	std.TestSetOrigSend(std.Coins{{"ugnot", 1_000_000}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 1_000_000)

	swapAmount := 987_654
	rou.SwapRoute(
		wugnotPath,
		quxPath,
		bigint(swapAmount),
		"EXACT_OUT",
		"gno.land/r/wugnot:gno.land/r/bar:100*POOL*gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100,gno.land/r/wugnot:gno.land/r/bar:500*POOL*gno.land/r/bar:gno.land/r/baz:500*POOL*gno.land/r/baz:gno.land/r/qux:500",
		"40,60",
		123456789,
	)

	tr01NewWugnotBalance := wugnot.BalanceOf(a2u(tr01))
	tr01NewQuxBalance := qux.BalanceOf(a2u(tr01))
	poolNewWugnotBalance := wugnot.BalanceOf(a2u(poolAddr))
	poolNewQuxBalance := qux.BalanceOf(a2u(poolAddr))

	shouldEQ(t, poolOldQuxBalance-poolNewQuxBalance < uint64(swapAmount), true)
	shouldEQ(t, poolNewWugnotBalance > poolOldWugnotBalance, true)
}

func TestGetUnclaimedFeeLP01(t *testing.T) {
	// lp02 collects fee from tokenId '1'
	std.TestSetOrigCaller(lp01)

	calculateUnclaimedFee(1)
	println()

	c0, c1 := pos.Collect(
		1,      // tokenId
		lp01,   // recipient
		100000, // amount0Max
		100000, // amount1Max
	)
	println("LP01 Fee Collected:", c0, c1)
	println()
}

func calculateUnclaimedFee(tokenId uint64) (bigint, bigint) {
	// POSITION DATA
	liquidity := pos.PositionGetPositionLiquidity(tokenId)

	tickLower := pos.PositionGetPositionTickLower(tokenId)
	tickUpper := pos.PositionGetPositionTickUpper(tokenId)

	// POOL DATA
	poolPath := pos.PositionGetPositionPoolKey(tokenId)
	pool := pl.GetPoolFromPoolKey(poolPath)

	currentTick := pool.PoolGetSlot0Tick()

	feeGrowthGlobal0X128 := pool.PoolGetFeeGrowthGlobal0X128()
	feeGrowthGlobal1X128 := pool.PoolGetFeeGrowthGlobal1X128()

	upperFeeGrowthOutside0X128 := pool.PoolGetTickFeeGrowthOutside0X128(tickUpper)
	upperFeeGrowthOutside1X128 := pool.PoolGetTickFeeGrowthOutside1X128(tickUpper)

	lowerFeeGrowthOutside0X128 := pool.PoolGetTickFeeGrowthOutside0X128(tickLower)
	lowerFeeGrowthOutside1X128 := pool.PoolGetTickFeeGrowthOutside1X128(tickLower)

	posFeeGrowthInside0LastX128 := pos.PositionGetPositionFeeGrowthInside0LastX128(tokenId)
	posFeeGrowthInside1LastX128 := pos.PositionGetPositionFeeGrowthInside1LastX128(tokenId)

	var tickLowerFeeGrowthBelow0, tickLowerFeeGrowthBelow1, tickUpperFeeGrowthAbove0, tickUpperFeeGrowthAbove1 bigint

	// if current tick is above range
	if currentTick >= tickUpper {
		tickUpperFeeGrowthAbove0 = feeGrowthGlobal0X128 - upperFeeGrowthOutside0X128
		tickUpperFeeGrowthAbove1 = feeGrowthGlobal1X128 - upperFeeGrowthOutside1X128
	} else { // if current tick is in range
		tickUpperFeeGrowthAbove0 = upperFeeGrowthOutside0X128
		tickUpperFeeGrowthAbove1 = upperFeeGrowthOutside1X128
	}

	// if current tick is below range
	if currentTick >= tickLower {
		tickLowerFeeGrowthBelow0 = lowerFeeGrowthOutside0X128
		tickLowerFeeGrowthBelow1 = lowerFeeGrowthOutside1X128
	} else {
		tickLowerFeeGrowthBelow0 = feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128
		tickLowerFeeGrowthBelow1 = feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128
	}

	fr_t1_0 := (feeGrowthGlobal0X128 - tickLowerFeeGrowthBelow0) - tickUpperFeeGrowthAbove0
	println("fr_t1_0:", fr_t1_0)
	println("posFeeGrowthInside0LastX128:", posFeeGrowthInside0LastX128)
	fr_t1_1 := (feeGrowthGlobal1X128 - tickLowerFeeGrowthBelow1) - tickUpperFeeGrowthAbove1
	println("fr_t1_1:", fr_t1_1)
	println("posFeeGrowthInside1LastX128:", posFeeGrowthInside1LastX128)

	uncollect_0 := (liquidity * (fr_t1_0 - posFeeGrowthInside0LastX128)) / Q128
	uncollect_1 := (liquidity * (fr_t1_1 - posFeeGrowthInside1LastX128)) / Q128

	println("uncollect_0:", uncollect_0)
	println("uncollect_1:", uncollect_1)
}

// func TestGetUnclaimedFeeLP02(t *testing.T) {
// 	// lp02 collects fee from tokenId '2'
// 	std.TestSetOrigCaller(lp02)

// 	c0, c1 := pos.Collect(
// 		2,      // tokenId
// 		lp02,   // recipient
// 		100000, // amount0Max
// 		100000, // amount1Max
// 	)
// 	println("LP02 Fee Collected:", c0, c1)
// }

// func TestGetUnclaimedFeeLP03(t *testing.T) {
// 	// lp03 collects fee from tokenId '3'
// 	std.TestSetOrigCaller(lp03)

// 	c0, c1 := pos.Collect(
// 		3,      // tokenId
// 		lp03,   // recipient
// 		100000, // amount0Max
// 		100000, // amount1Max
// 	)
// 	println("LP03 Fee Collected:", c0, c1)
// }

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

func ugnotBalance(addr std.Address) std.Coin {
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	coins := testBanker.GetCoins(tr01)

	if len(coins) == 0 {
		return nil
	}

	if len(coins) == 1 {
		coin := coins[0]
		return coin
	}
}

func getAmountsOfTokenId(tokenId uint64) (bigint, bigint) {
	// get pool
	poolPath := pos.PositionGetPositionPoolKey(tokenId)
	pool := pl.GetPoolFromPoolKey(poolPath)

	currentPriceX96 := pool.PoolGetSlot0SqrtPriceX96()

	tickLower := pos.PositionGetPositionTickLower(tokenId)
	lowerPriceX96 := pl.TickMathGetSqrtRatioAtTick(tickLower)

	tickUpper := pos.PositionGetPositionTickUpper(tokenId)
	upperPriceX96 := pl.TickMathGetSqrtRatioAtTick(tickUpper)

	return pos.PositionGetAmountsForLiquidity(currentPriceX96, lowerPriceX96, upperPriceX96, pos.PositionGetPositionLiquidity(tokenId))
}
