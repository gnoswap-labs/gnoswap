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
	baz "gno.land/r/baz"
	foo "gno.land/r/foo"
	gns "gno.land/r/gns"
	obl "gno.land/r/obl" // external reward
	qux "gno.land/r/qux"

	wugnot "gno.land/r/wugnot"

	gnft "gno.land/r/gnft" // GRC721 LP Token
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

	shouldPanicWithMsg(t, func() { pl.InitManual() }, "[POOl] pool_manager.gno__InitManual() || contract must not be initialized")
}

// 2. [TC - POOL] Create(Multi)Pool
func TestPoolCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	gsaOldGnsBalance := gns.BalanceOf(a2u(gsa))

	pl.CreatePool(wugnotPath, barPath, uint16(100), 101729702841318637793976746270) // tick =  5_000, ratio = 1.648680055931176
	pl.CreatePool(barPath, bazPath, uint16(100), 101729702841318637793976746270)    // tick =  5_000, ratio = 1.648680055931176
	pl.CreatePool(bazPath, quxPath, uint16(100), 101729702841318637793976746270)    // tick =  5_000, ratio = 1.648680055931176

	pl.CreatePool(wugnotPath, barPath, uint16(500), 101729702841318637793976746270) // tick =  5_000, ratio = 1.648680055931176
	pl.CreatePool(barPath, bazPath, uint16(500), 101729702841318637793976746270)    // tick =  5_000, ratio = 1.648680055931176
	pl.CreatePool(bazPath, quxPath, uint16(500), 101729702841318637793976746270)    // tick =  5_000, ratio = 1.648680055931176
	std.TestSkipHeights(7)

	gsaNewGnsBalance := gns.BalanceOf(a2u(gsa))

	shouldEQ(t, len(pl.PoolGetPoolList()), 6)
	shouldEQ(t, gsaNewGnsBalance-gsaOldGnsBalance, 3000)
}

// 3. [TC - POSITION] Mint LP
func TestPositionMint(t *testing.T) {
	// bar_wugnot_100 by lp01
	{
		std.TestSetOrigCaller(lp01)

		// prepare ugnot
		testBanker := std.GetBanker(std.BankerTypeRealmIssue)
		testBanker.IssueCoin(std.GetOrigCaller(), "ugnot", 500_000_000)

		poolOldBarBalance := bar.BalanceOf(a2u(poolAddr))
		poolOldWugnotBalance := wugnot.BalanceOf(a2u(poolAddr))
		shouldEQ(t, poolOldBarBalance, 0)
		shouldEQ(t, poolOldWugnotBalance, 0)

		lp01OldBarBalance := bar.BalanceOf(a2u(lp01))
		lp01OldWugnotBalance := wugnot.BalanceOf(a2u(lp01))

		// simulate transfer & decrase
		std.TestSetOrigSend(std.Coins{{"ugnot", 10000000}}, nil)
		testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 10000000)

		// Mint
		tokenId, liquidity, amount0, amount1 := pos.Mint(wugnotPath, barPath, uint16(100), int32(4000), int32(6000), bigint(10000000), bigint(10000000), 0, 0, MAX_TIMEOUT)
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(tid(1)), lp01)
		shouldEQ(t, tokenId, 1)
		shouldEQ(t, amount0 > 0, true)
		shouldEQ(t, amount1 > 0, true)

		poolNewBarBalance := bar.BalanceOf(a2u(poolAddr))
		poolNewWugnotBalance := wugnot.BalanceOf(a2u(poolAddr))
		lp01NewBarBalance := bar.BalanceOf(a2u(lp01))
		lp01NewWugnotBalance := wugnot.BalanceOf(a2u(lp01))

		shouldEQ(t, poolOldBarBalance+uint64(amount0), poolNewBarBalance)
		shouldEQ(t, poolOldWugnotBalance+uint64(amount1), poolNewWugnotBalance)
		shouldEQ(t, lp01OldBarBalance-uint64(amount0), lp01NewBarBalance)
	}

	// bar_baz_100 by lp02
	{
		std.TestSetOrigCaller(lp02)

		poolOldBarBalance := bar.BalanceOf(a2u(poolAddr))
		poolOldBazBalance := baz.BalanceOf(a2u(poolAddr))
		shouldEQ(t, poolOldBarBalance, 9999999)
		shouldEQ(t, poolOldBazBalance, 0)

		lp02OldBarBalance := bar.BalanceOf(a2u(lp02))
		lp02OldBazBalance := baz.BalanceOf(a2u(lp02))

		// Mint
		tokenId, liquidity, amount0, amount1 := pos.Mint(barPath, bazPath, uint16(100), int32(4000), int32(6000), bigint(10000000), bigint(10000000), 0, 0, MAX_TIMEOUT)
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(tid(2)), lp02)
		shouldEQ(t, tokenId, 2)
		shouldEQ(t, amount0 > 0, true)
		shouldEQ(t, amount1 > 0, true)

		poolNewBarBalance := bar.BalanceOf(a2u(poolAddr))
		poolNewBazBalance := baz.BalanceOf(a2u(poolAddr))
		lp02NewBarBalance := bar.BalanceOf(a2u(lp02))
		lp02NewBazBalance := baz.BalanceOf(a2u(lp02))

		shouldEQ(t, poolOldBarBalance+uint64(amount0), poolNewBarBalance)
		shouldEQ(t, poolOldBazBalance+uint64(amount1), poolNewBazBalance)
		shouldEQ(t, lp02OldBarBalance-uint64(amount0), lp02NewBarBalance)
		shouldEQ(t, lp02OldBazBalance-uint64(amount1), lp02NewBazBalance)
	}

	// baz_qux_100 by lp02
	{
		std.TestSetOrigCaller(lp02)

		poolOldBazBalance := baz.BalanceOf(a2u(poolAddr))
		poolOldQuxBalance := qux.BalanceOf(a2u(poolAddr))
		shouldEQ(t, poolOldBazBalance, 9999999)
		shouldEQ(t, poolOldQuxBalance, 0)

		lp02OldBazBalance := baz.BalanceOf(a2u(lp02))
		lp02OldQuxBalance := qux.BalanceOf(a2u(lp02))

		// Mint
		tokenId, liquidity, amount0, amount1 := pos.Mint(bazPath, quxPath, uint16(100), int32(4000), int32(6000), bigint(10000000), bigint(10000000), 0, 0, MAX_TIMEOUT)
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(tid(3)), lp02)
		shouldEQ(t, tokenId, 3)
		shouldEQ(t, amount0 > 0, true)
		shouldEQ(t, amount1 > 0, true)

		poolNewBazBalance := baz.BalanceOf(a2u(poolAddr))
		poolNewQuxBalance := qux.BalanceOf(a2u(poolAddr))
		lp02NewBazBalance := baz.BalanceOf(a2u(lp02))
		lp02NewQuxBalance := qux.BalanceOf(a2u(lp02))

		shouldEQ(t, poolOldBazBalance+uint64(amount0), poolNewBazBalance)
		shouldEQ(t, poolOldQuxBalance+uint64(amount1), poolNewQuxBalance)
		shouldEQ(t, lp02OldBazBalance-uint64(amount0), lp02NewBazBalance)
		shouldEQ(t, lp02OldQuxBalance-uint64(amount1), lp02NewQuxBalance)
	}

	{
		// bar_wugnot_500 by lp01
		// simulate transfer & decrase
		std.TestSetOrigCaller(lp01)
		std.TestSetOrigSend(std.Coins{{"ugnot", 10000000}}, nil)
		testBanker := std.GetBanker(std.BankerTypeRealmIssue)
		testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 10000000)
		pos.Mint(barPath, wugnotPath, uint16(500), int32(4000), int32(6000), bigint(10000000), bigint(10000000), 0, 0, MAX_TIMEOUT)

		// bar_baz_500 by lp02
		std.TestSetOrigCaller(lp02)
		pos.Mint(barPath, bazPath, uint16(100), int32(4000), int32(6000), bigint(10000000), bigint(10000000), 0, 0, MAX_TIMEOUT)

		// baz_qux_500 by lp02
		std.TestSetOrigCaller(lp02)
		pos.Mint(bazPath, quxPath, uint16(100), int32(4000), int32(6000), bigint(10000000), bigint(10000000), 0, 0, MAX_TIMEOUT)

		std.TestSkipHeights(3)

	}
}

// 4. [TC - STAKER] CreateExternalIncentive
// Internal incentive will automatcially created via init()
func TestStakerCreateExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(ci01)

	stk.CreateExternalIncentive(
		"gno.land/r/bar:gno.land/r/wugnot:100", // targetPoolPath
		"gno.land/r/obl",                       // rewardToken
		10_000_000_000,                         // rewardAmount
		GetTimestamp(),                         // startTimestamp
		GetTimestamp()+TIMESTAMP_90DAYS,        // endTimestamp
	)
	std.TestSkipHeights(1)
}

// 5. [TC - STAKER] StakeToken
func TestStakerStakeToken(t *testing.T) {
	// lp01 stakes tokenId '1'
	std.TestSetPrevAddr(lp01) // r3v4_xxx: only test code, we need to call gnft.Approve directly from user
	gnft.Approve(a2u(stakerAddr), tid("1"))

	stk.StakeToken(1)
	std.TestSkipHeights(1)

	shouldEQ(t, gnft.OwnerOf(bigint(1)), stakerAddr)

	// lp02 stakes tokenId '2'
	std.TestSetPrevAddr(lp02) // r3v4_xxx: only test code, we need to call gnft.Approve directly from user
	gnft.Approve(a2u(stakerAddr), tid("2"))

	stk.StakeToken(2)
	std.TestSkipHeights(1)

	shouldEQ(t, gnft.OwnerOf(bigint(2)), stakerAddr)
}

// 6. [TC - POOL] SetFeeProtocol
func TestPoolSetFeeProtocol(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	pl.SetFeeProtocol(6, 8)
	std.TestSkipHeights(1)

	tmpPool := pl.GetPool(barPath, wugnotPath, uint16(100))
	shouldEQ(t, tmpPool.PoolGetSlot0FeeProtocol(), bigint(134))
}

// 7. [TC - ROUTER] SwapRoute ExactIn Single ( bar -> baz )
func TestRotuerSwapRouteExactInSinglePath(t *testing.T) {
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
		234_567,
	)

	tr01NewBarBalance := bar.BalanceOf(a2u(tr01))
	tr01NewBazBalance := baz.BalanceOf(a2u(tr01))
	poolNewBarBalance := bar.BalanceOf(a2u(poolAddr))
	poolNewBazBalance := baz.BalanceOf(a2u(poolAddr))

	shouldEQ(t, tr01OldBarBalance-uint64(swapAmount), tr01NewBarBalance)
	shouldEQ(t, tr01NewBazBalance > tr01OldBazBalance, true)
	shouldEQ(t, poolNewBarBalance-uint64(swapAmount), poolOldBarBalance)
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

	std.TestSetOrigSend(std.Coins{{"ugnot", 1000000}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 1000000)

	swapAmount := 987_654
	rou.SwapRoute(
		wugnotPath,
		quxPath,
		"EXACT_OUT",
		bigint(swapAmount),
		1000000,
		0,
		20,
		10,
		5,
	)

	tr01NewWugnotBalance := wugnot.BalanceOf(a2u(tr01))
	tr01NewQuxBalance := qux.BalanceOf(a2u(tr01))
	poolNewWugnotBalance := wugnot.BalanceOf(a2u(poolAddr))
	poolNewQuxBalance := qux.BalanceOf(a2u(poolAddr))

	shouldEQ(t, poolOldQuxBalance-987_654, poolNewQuxBalance)
	shouldEQ(t, poolNewWugnotBalance > poolOldWugnotBalance, true)
}

// 9. [TC - POSITION] Collect
func TestPositionCollect01(t *testing.T) {
	{
		// lp01 collects fee from tokenId '1'
		std.TestSetOrigCaller(lp01)

		// minted at bar_wugnot_500
		poolOldNativeBalance := ugnotBalance(poolAddr)
		poolOldWugnotBalance := wugnot.BalanceOf(a2u(poolAddr))

		std.TestSetPrevRealm("gno.land/r/position")
		std.TestSetOrigCaller(lp01)
		cAmount0, cAmount1 := pos.Collect(
			1,      // tokenId
			lp01,   // recipient
			100000, // amount0Max
			100000, // amount1Max
		)
		std.TestSkipHeights(1)

		shouldEQ(t, cAmount0, bigint(0))  // bar
		shouldEQ(t, cAmount1, bigint(52)) // wugnot

		poolNewNativeBalance := ugnotBalance(poolAddr)
		poolNewWugnotBalance := wugnot.BalanceOf(a2u(poolAddr))
	}

	{
		// lp02 collects fee from tokenId '2'
		std.TestSetOrigCaller(lp02)

		lp02OldBarBalance := bar.BalanceOf(a2u(lp02))
		lp02OldBazBalance := baz.BalanceOf(a2u(lp02))

		cAmount0, cAmount1 := pos.Collect(
			2,      // tokenId
			lp02,   // recipient
			100000, // amount0Max
			100000, // amount1Max
		)
		std.TestSkipHeights(1)

		lp02NewBarBalance := bar.BalanceOf(a2u(lp02))
		lp02NewBazBalance := baz.BalanceOf(a2u(lp02))

		shouldEQ(t, cAmount0 > 0, true)
		shouldEQ(t, cAmount1 == 0, true)

		shouldEQ(t, lp02NewBarBalance-uint64(cAmount0), lp02OldBarBalance)
		shouldEQ(t, lp02OldBazBalance, lp02OldBazBalance)
	}
}

// 10. [TC - STAKER] UnstakeToken
func TestStakerUnstakeToken(t *testing.T) {
	{
		// lp01 unstakes tokenId '1'
		std.TestSetPrevAddr(lp01) // r3v4_xxx: only test code, we need to call stk.UnstakeToken directly from user

		// skip 15 days
		std.TestSkipHeights(259200)
		stk.UnstakeToken(1)
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(bigint(1)), lp01)
		shouldEQ(t, gns.BalanceOf(a2u(lp01)), bigint(3850))
		shouldEQ(t, obl.BalanceOf(a2u(lp01)), bigint(4951))
	}

	{
		// lp02 unstakes tokenId '2'
		std.TestSetPrevAddr(lp02) // r3v4_xxx: only test code, we need to stk gnft.UnstakeToken directly from user

		// skip 20 days more
		std.TestSkipHeights(345600)
		stk.UnstakeToken(2)
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(bigint(2)), lp02)
		shouldEQ(t, gns.BalanceOf(a2u(lp02)), bigint(0)) // pool for tokenId '2' isn't reward target
		shouldEQ(t, obl.BalanceOf(a2u(lp02)), bigint(0)) // pool for tokenId '2' isn't reward target
	}
}

// 11. [TC - STAKER] EndExternalIncentive
func TestStakerEndExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(ci01)
	std.TestSkipHeights(1036800)

	ci01OldRewardBal := obl.BalanceOf(a2u(ci01))

	stk.EndExternalIncentive(ci01.String(), "gno.land/r/bar:gno.land/r/wugnot:100", "gno.land/r/obl") // use same parameter as CreateExternalIncentive
	std.TestSkipHeights(1)

	ci01NewRewardBal := obl.BalanceOf(a2u(ci01))
	shouldGT(t, ci01NewRewardBal, ci01OldRewardBal)

	shouldPanicWithMsg(
		t,
		func() {
			stk.EndExternalIncentive(ci01.String(), "gno.land/r/bar:gno.land/r/wugnot:100", "gno.land/r/obl")
		},
		"[STAKER] staker.gno__EndExternalIncentive() || cannot end non existent incentive(ZzF2ZDVucXYybHRhMDQ3aDZsdGEwNDdoNmx0YTA0N2g2bGswd2hjZDpnbm8ubGFuZC9yL2Jhcjpnbm8ubGFuZC9yL3d1Z25vdDoxMDA6Z25vLmxhbmQvci9vYmw=)",
	)
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
