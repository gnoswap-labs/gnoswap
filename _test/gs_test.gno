package tc

import (
	"std"
	"testing"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"

	"gno.land/r/demo/users"

	// swap contract
	gov "gno.land/r/gov"
	pl "gno.land/r/pool"
	pos "gno.land/r/position"
	stk "gno.land/r/staker"

	// token
	bar "gno.land/r/bar"   // token1
	foo "gno.land/r/foo"   // token0
	gnft "gno.land/r/gnft" // LP Token ( Gnoswap NFT )
	gnos "gno.land/r/gnos" // Shares ( Gnoswap Shares ) & INTERNAL Reward Token
	obl "gno.land/r/obl"   // EXTERNAL Reward Token
)

var (
	// Common
	pToken0        = "foo"
	pToken1        = "bar"
	pFee    bigint = 500

	test_tickLower bigint = 9000
	test_tickUpper bigint = 11000

	tMaxIncentiveStartLeadTime bigint = 1000000
	tMaxIncentiveDuration      bigint = 1000000

	tStartTime bigint = GetTimestamp()
	tEndTime   bigint = tStartTime + 301 // staker.gno #140 ( lockDuration is limited to 100, 200, 300 seconds)

	// test address
	pc01 = testutils.TestAddress("pc01") // Pool Creator
	ci01 = testutils.TestAddress("ci01") // Create Incentive Caller 01
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	lp02 = testutils.TestAddress("lp02") // Liquidity Provider 02
	tr01 = testutils.TestAddress("tr01") // Trader 01

	// contract address
	poolAddr   = pl.GetOrigPkgAddr()  // Pool Contract
	posAddr    = pos.GetOrigPkgAddr() // Position Contract
	stakerAddr = stk.GetOrigPkgAddr() // Staker Contract
	govAddr    = gov.GetOrigPkgAddr() // Gov Contract

	MIN_TICK bigint = -887272
	MAX_TICK bigint = 887272

	MIN_SQRT_RATIO bigint = 4295128739                                        // same as TickMathGetSqrtRatioAtTick(MIN_TICK)
	MAX_SQRT_RATIO bigint = 1461446703485210103287273052203988822378723970342 // same as TickMathGetSqrtRatioAtTick(MAX_TICK)
)

func init() {
	// debug addr
	// println(pc01, "// pc01")
	// println(ci01, "// ci01")
	// println(lp01, "// lp01")
	// println(lp02, "// lp02")
	// println(tr01, "// tr01")
	// println(poolAddr, "// pool")
	// println(posAddr, "// pos")
	// println(stakerAddr, "// staker")
	// println(govAddr, "// gov")
}

// 1. [POOL] Init
func TestPoolInitManual(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	pl.InitManual()

	shouldPanicWithMsg(t, func() { pl.InitManual() }, "[POOl] pool_manager.gno__initManual() || contract must not be initialized")
}

// 2. [POOL] CreatePool
func TestPoolCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	pl.CreatePool(
		pToken0,                        // tokenA
		pToken1,                        // tokenB
		pFee,                           // fee
		130621891405341611593710811006, // sqrtPriceX96 ( for tick 10_000 )
	)
	std.TestSkipHeights(10)

	tmpPool := pl.GetPool(pToken0, pToken1, pFee)
	shouldEQ(t, tmpPool.GetTickSpacing(), bigint(10))
}

// 3. [POSITION] Mint LP
func TestPositionMint(t *testing.T) {
	tmpPool := pl.GetPool(pToken0, pToken1, pFee)

	poolOldLiquidity := tmpPool.GetLiquidity()
	poolOldToken0Balance := token0Balance(poolAddr)
	poolOldToken1Balance := token1Balance(poolAddr)

	shouldEQ(t, tmpPool.GetLiquidity(), bigint(0))
	shouldEQ(t, poolOldToken0Balance, bigint(0))
	shouldEQ(t, poolOldToken1Balance, bigint(0))

	{
		// 'lp01' mints some liquidity => will get LP Token(tokenId '1')
		std.TestSetOrigCaller(lp01)

		mTokenId, mLiquidity, mAmount0, mAmount1 := pos.Mint(
			pToken0,    // token0
			pToken1,    // token1
			pFee,       // fee
			9000,       // tickLower
			11000,      // tickUpper
			1000000,    // amount0Desired
			1000000,    // amount1Desired
			1,          // amount0Min
			1,          // amount1Min
			2345678901, // deadline
		)
		std.TestSkipHeights(10)

		poolNewLiquidity := tmpPool.GetLiquidity()
		poolNewToken0Balance := token0Balance(poolAddr)
		poolNewToken1Balance := token1Balance(poolAddr)

		shouldEQ(t, gnft.OwnerOf(bigint(1)), lp01)
		shouldEQ(t, mTokenId, bigint(1))
		shouldEQ(t, poolNewToken0Balance, poolOldToken0Balance+mAmount0)
		shouldEQ(t, poolNewToken1Balance, poolOldToken1Balance+mAmount1)
		shouldEQ(t, poolNewLiquidity, poolOldLiquidity+mLiquidity)
	}

	{
		// 'lp02' mints some liquidity => will get LP Token(tokenId '2')
		std.TestSetOrigCaller(lp02)

		poolOldToken0Balance = token0Balance(poolAddr)
		poolOldToken1Balance = token1Balance(poolAddr)

		mTokenId, mLiquidity, mAmount0, mAmount1 := pos.Mint(
			pToken0,    // token0
			pToken1,    // token1
			pFee,       // fee
			9500,       // tickLower
			10500,      // tickUpper
			2000000,    // amount0Desired
			2000000,    // amount1Desired
			1,          // amount0Min
			1,          // amount1Min
			2345678901, // deadline
		)
		std.TestSkipHeights(10)

		poolNewToken0Balance := token0Balance(poolAddr)
		poolNewToken1Balance := token1Balance(poolAddr)

		shouldEQ(t, gnft.OwnerOf(bigint(2)), lp02)
		shouldEQ(t, mTokenId, bigint(2))
		shouldEQ(t, poolNewToken0Balance, poolOldToken0Balance+mAmount0)
		shouldEQ(t, poolNewToken1Balance, poolOldToken1Balance+mAmount1)
	}
}

// 4. [STAKER] CreateExternalIncentive
// Internal incentive will automatcially created via init()
func TestStakerCreateExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(ci01)

	stk.CreateExternalIncentive(
		"bar_foo_500",                       // targetPoolPath
		"OBL",                               // rewardToken
		10_000_000_000,                      // rewardAmount
		GetTimestamp(),                      // startTimestamp
		GetTimestamp()+(TIMESTAMP_30DAYS*2), // endTimestamp
	)
	std.TestSkipHeights(1)

	shouldPanicWithMsg(
		t,
		func() {
			stk.CreateExternalIncentive("bar_foo_500", "OBL", 10_000_000_000, GetTimestamp(), GetTimestamp()+(TIMESTAMP_30DAYS*2))
		},
		"[STAKER] staker.gno__CreateExternalIncentive() || incentive(YmFyX2Zvb181MDBfT0JM) already exists",
	)
}

// 5. [STAKER] StakeToken
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

// 6. [POOL] SetFeeProtocol
func TestPoolSetFeeProtocol(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	pl.SetFeeProtocol(6, 8)
	std.TestSkipHeights(1)

	tmpPool := pl.GetPool(pToken0, pToken1, pFee)
	shouldEQ(t, tmpPool.GetFeeProtocol(), bigint(134))
}

// 7. [POOL] Swap ( token0 -> token1 )
func TestPoolSwap01(t *testing.T) {
	tmpPool := pl.GetPool(pToken0, pToken1, pFee)
	testPrice01 := bigint(MIN_SQRT_RATIO + 1)

	poolOldToken0Bal := token0Balance(poolAddr)
	poolOldToken1Bal := token1Balance(poolAddr)
	poolOldPrice := tmpPool.GetSqrtPriceX96()

	userOldToken0Bal := token0Balance(tr01)
	userOldToken1Bal := token1Balance(tr01)

	std.TestSetOrigCaller(tr01)
	sAmount0, sAmount1 := pl.Swap(
		pToken0,     // pToken0 // tokenIn
		pToken1,     // pToken1 // tokenOut
		pFee,        // pFee
		tr01,        // recipient
		true,        // zeroForOne // token0 > token1
		200000,      // amountSpecified
		testPrice01, // sqrtPriceLimitX96
	)
	std.TestSkipHeights(1)

	poolNewToken0Bal := token0Balance(poolAddr)
	poolNewToken1Bal := token1Balance(poolAddr)
	poolNewPrice := tmpPool.GetSqrtPriceX96()

	userNewToken0Bal := token0Balance(tr01)
	userNewToken1Bal := token1Balance(tr01)

	shouldEQ(t, poolNewToken0Bal, poolOldToken0Bal+sAmount0)
	shouldEQ(t, poolNewToken1Bal, poolOldToken1Bal+sAmount1)

	shouldEQ(t, userNewToken0Bal, userOldToken0Bal-sAmount0)
	shouldEQ(t, userNewToken1Bal, userOldToken1Bal-sAmount1)

	shouldLT(t, poolNewPrice, poolOldPrice)

	std.TestSetOrigCaller(pc01)
	cAmount0, cAmount1 := pl.CollectProtocol(
		pToken0, // token0
		pToken1, // token1
		pFee,    // fee
		pc01,    // recipient
		100000,  // amount0Requested
		100000,  // amount1Requested
	)
	std.TestSkipHeights(1)

	shouldGT(t, cAmount0, bigint(0))
	shouldEQ(t, token0Balance(pc01), cAmount0)

	shouldEQ(t, cAmount1, bigint(0)) // since swap is token0 -> token1, there is no fee for token1
	shouldEQ(t, token1Balance(pc01), cAmount1)
}

// 8. [POSITION] Collect
// * collect fee from (swap token0 > token1)
func TestPositionCollect01(t *testing.T) {
	{
		// lp01 collects fee from tokenId '1'
		std.TestSetOrigCaller(lp01)

		lp01OldToken0Bal := token0Balance(lp01)
		lp01OldToken1Bal := token1Balance(lp01)

		cAmount0, cAmount1 := pos.Collect(
			1,      // tokenId
			lp01,   // recipient
			100000, // amount0Max
			100000, // amount1Max
		)
		std.TestSkipHeights(1)

		lp01NewToken0Bal := token0Balance(lp01)
		lp01NewToken1Bal := token1Balance(lp01)

		shouldGT(t, cAmount0, bigint(0))
		shouldEQ(t, cAmount1, bigint(0))

		shouldEQ(t, lp01NewToken0Bal, lp01OldToken0Bal+cAmount0)
		shouldEQ(t, lp01NewToken1Bal, lp01OldToken1Bal+cAmount1)
	}

	{
		// lp02 collects fee from tokenId '1'
		std.TestSetOrigCaller(lp02)

		lp02OldToken0Bal := token0Balance(lp02)
		lp02OldToken1Bal := token1Balance(lp02)

		cAmount0, cAmount1 := pos.Collect(
			2,      // tokenId
			lp02,   // recipient
			100000, // amount0Max
			100000, // amount1Max
		)
		std.TestSkipHeights(1)

		lp02NewToken0Bal := token0Balance(lp02)
		lp02NewToken1Bal := token1Balance(lp02)

		shouldGT(t, cAmount0, bigint(0))
		shouldEQ(t, cAmount1, bigint(0))

		shouldEQ(t, lp02NewToken0Bal, lp02OldToken0Bal+cAmount0)
		shouldEQ(t, lp02NewToken1Bal, lp02OldToken1Bal+cAmount1)
	}
}

// 9. [POOL] Swap ( token1 -> token0 )
func TestPoolSwap10(t *testing.T) {
	tmpPool := pl.GetPool(pToken0, pToken1, pFee)
	testPrice10 := bigint(MAX_SQRT_RATIO - 1)

	poolOldToken0Bal := token0Balance(poolAddr)
	poolOldToken1Bal := token1Balance(poolAddr)
	poolOldPrice := tmpPool.GetSqrtPriceX96()

	userOldToken0Bal := token0Balance(tr01)
	userOldToken1Bal := token1Balance(tr01)

	std.TestSetOrigCaller(tr01)
	sAmount0, sAmount1 := pl.Swap(
		pToken0,     // pToken0 // tokenIn
		pToken1,     // pToken1 // tokenOut
		pFee,        // pFee
		tr01,        // recipient
		false,       // zeroForOne // token1 > token0
		200000,      // amountSpecified
		testPrice10, // sqrtPriceLimitX96
	)
	std.TestSkipHeights(1)

	poolNewToken0Bal := token0Balance(poolAddr)
	poolNewToken1Bal := token1Balance(poolAddr)
	poolNewPrice := tmpPool.GetSqrtPriceX96()

	userNewToken0Bal := token0Balance(tr01)
	userNewToken1Bal := token1Balance(tr01)

	shouldEQ(t, poolNewToken0Bal, poolOldToken0Bal+sAmount0)
	shouldEQ(t, poolNewToken1Bal, poolOldToken1Bal+sAmount1)

	shouldEQ(t, userNewToken0Bal, userOldToken0Bal-sAmount0)
	shouldEQ(t, userNewToken1Bal, userOldToken1Bal-sAmount1)

	shouldGT(t, poolNewPrice, poolOldPrice)

	std.TestSetOrigCaller(pc01)
	cAmount0, cAmount1 := pl.CollectProtocol(
		pToken0, // token0
		pToken1, // token1
		pFee,    // fee
		pc01,    // recipient
		100000,  // amount0Requested
		100000,  // amount1Requested
	)
	std.TestSkipHeights(1)

	shouldEQ(t, cAmount0, bigint(0)) // since swap is token1 -> token0, there is no fee for token0

	shouldGT(t, cAmount1, bigint(0))
	shouldEQ(t, token1Balance(pc01), cAmount1)
}

// 10. [POSITION] Collect
// * collect fee from (swap token1 > token0)
func TestPositionCollect10(t *testing.T) {
	{
		// lp01 collects fee from tokenId '1'
		std.TestSetOrigCaller(lp01)

		lp01OldToken0Bal := token0Balance(lp01)
		lp01OldToken1Bal := token1Balance(lp01)

		cAmount0, cAmount1 := pos.Collect(
			1,      // tokenId
			lp01,   // recipient
			100000, // amount0Max
			100000, // amount1Max
		)
		std.TestSkipHeights(1)

		lp01NewToken0Bal := token0Balance(lp01)
		lp01NewToken1Bal := token1Balance(lp01)

		shouldEQ(t, cAmount0, bigint(0))
		shouldGT(t, cAmount1, bigint(0))

		shouldEQ(t, lp01NewToken0Bal, lp01OldToken0Bal+cAmount0)
		shouldEQ(t, lp01NewToken1Bal, lp01OldToken1Bal+cAmount1)
	}

	{
		// lp02 collects fee from tokenId '1'
		std.TestSetOrigCaller(lp02)

		lp02OldToken0Bal := token0Balance(lp02)
		lp02OldToken1Bal := token1Balance(lp02)

		cAmount0, cAmount1 := pos.Collect(
			2,      // tokenId
			lp02,   // recipient
			100000, // amount0Max
			100000, // amount1Max
		)
		std.TestSkipHeights(1)

		lp02NewToken0Bal := token0Balance(lp02)
		lp02NewToken1Bal := token1Balance(lp02)

		shouldEQ(t, cAmount0, bigint(0))
		shouldGT(t, cAmount1, bigint(0))

		shouldEQ(t, lp02NewToken0Bal, lp02OldToken0Bal+cAmount0)
		shouldEQ(t, lp02NewToken1Bal, lp02OldToken1Bal+cAmount1)
	}
}

// 11. [STAKER] UnstakeToken
func TestStakerUnstakeToken(t *testing.T) {
	{
		// lp01 unstakes tokenId '1'
		std.TestSetPrevAddr(lp01) // r3v4_xxx: only test code, we need to call gnft.UnstakeToken directly from user

		// skip 15 days
		std.TestSkipHeights(259200)
		stk.UnstakeToken(1)
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(bigint(1)), lp01)
		shouldEQ(t, gnos.BalanceOf(a2u(lp01)), bigint(183002966))
		shouldEQ(t, obl.BalanceOf(a2u(lp01)), bigint(353304593))
	}

	{
		// lp02 unstakes tokenId '2'
		std.TestSetPrevAddr(lp02) // r3v4_xxx: only test code, we need to call gnft.UnstakeToken directly from user

		// skip 20 days more
		std.TestSkipHeights(345600)
		stk.UnstakeToken(2)
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(bigint(2)), lp02)
		shouldEQ(t, gnos.BalanceOf(a2u(lp02)), bigint(3024055000))
		shouldEQ(t, obl.BalanceOf(a2u(lp02)), bigint(5624742300))
	}
}

// 12. [STAKER] EndExternalIncentive
func TestStakerEndExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(ci01)
	std.TestSkipHeights(1036800)

	ci01OldRewardBal := obl.BalanceOf(a2u(ci01))

	stk.EndExternalIncentive("bar_foo_500", "OBL")
	std.TestSkipHeights(1)

	ci01NewRewardBal := obl.BalanceOf(a2u(ci01))
	shouldGT(t, ci01NewRewardBal, ci01OldRewardBal)

	shouldPanicWithMsg(
		t,
		func() { stk.EndExternalIncentive("bar_foo_500", "OBL") },
		"[STAKER] staker.gno__EndIncentive() || cannot end non existent incentive(YmFyX2Zvb181MDBfT0JM)",
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

func tid(tokenId string) grc721.TokenID {
	return grc721.TokenID(tokenId)
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
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if l >= r {
		t.Errorf("expected %v > %v", l, r)
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
