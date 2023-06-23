package tc

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"
	"gno.land/r/demo/users"

	bar "gno.land/r/bar"
	foo "gno.land/r/foo"

	pl "gno.land/r/pool"
	ps "gno.land/r/position"
	st "gno.land/r/staker"

	nft "gno.land/r/gnft"  // GNFT, Gnoswap NFT
	gnos "gno.land/r/gnos" // GNOS, Gnoswap Share
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

	own  = testutils.TestAddress("own")  // Owner
	ci01 = testutils.TestAddress("ci01") // Create Incentive Caller
	rf01 = testutils.TestAddress("rf01") // Refundee
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider
	tr01 = testutils.TestAddress("tr01") // Trader 01

	poolAddr   = pl.GetOrigPkgAddr() // Pool Contract
	posAddr    = ps.GetOrigPkgAddr() // Position Contract
	stakerAddr = st.GetOrigPkgAddr() // Staker Contract

	MIN_TICK bigint = -887272
	MAX_TICK bigint = 887272

	MIN_SQRT_RATIO bigint = 4295128739                                        // same as TickMathGetSqrtRatioAtTick(MIN_TICK)
	MAX_SQRT_RATIO bigint = 1461446703485210103287273052203988822378723970342 // same as TickMathGetSqrtRatioAtTick(MAX_TICK)
)

func init() {
	std.TestSetOrigCaller(lp01)
	foo.FaucetL()
	bar.FaucetL()

	std.TestSetOrigCaller(tr01)
	foo.FaucetL()
	bar.FaucetL()

	// debug - print addr
	println(ci01, "// ci01")
	println(rf01, "// rf01")
	println(lp01, "// lp01")
	println(tr01, "// tr01")

	println(poolAddr, "// pool")
	println(posAddr, "// position")
	println(stakerAddr, "// staker")
}

// Init & CreatePool using Pool Contract
func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(own)
	pl.Init()
	pl.CreatePool("foo", "bar", 500, 130621891405341611593710811006)

	// fee
	// 500		= 0.05% // USv3 default
	// 3000		= 0.3% // USv3 default
	// 10000	= 1% // USv3 default

	// Approve
	std.TestSetOrigCaller(lp01)
	foo.Approve(users.AddressOrName(poolAddr), 50000000000) // Pool Contract
	bar.Approve(users.AddressOrName(poolAddr), 50000000000) // Pool Contract
	foo.Approve(users.AddressOrName(lp01), 50000000000)
	bar.Approve(users.AddressOrName(lp01), 50000000000)

	std.TestSetOrigCaller(tr01)
	foo.Approve(users.AddressOrName(poolAddr), 50000000000) // Pool Contract
	bar.Approve(users.AddressOrName(poolAddr), 50000000000) // Pool Contract
	foo.Approve(users.AddressOrName(tr01), 50000000000)
	bar.Approve(users.AddressOrName(tr01), 50000000000)
}

func TestPositionMint(t *testing.T) {
	pool := pl.GetPool("foo", "bar", 500)
	println("before position mint\tpool.liquidity:", pool.GetLiquidity())

	poolOldToken0Bal := BalanceOf(pool.GetToken0(), poolAddr)
	poolOldToken1Bal := BalanceOf(pool.GetToken1(), poolAddr)

	userOldToken0Bal := BalanceOf(pool.GetToken0(), tr01)
	userOldToken1Bal := BalanceOf(pool.GetToken1(), tr01)

	lpOldToken0Bal := BalanceOf(pool.GetToken0(), lp01)
	lpOldToken1Bal := BalanceOf(pool.GetToken1(), lp01)

	std.TestSetOrigCaller(lp01)
	tPosTokenId, tPosLiquidity, tPosAmount0, tPosAmount1 := ps.Mint(
		std.Address("foo"),
		std.Address("bar"),
		bigint(500),
		bigint(9000),
		bigint(11000),
		bigint(1000000),
		bigint(1000000),
		bigint(1),
		bigint(1),
		bigint(1234567890),
	)

	poolNewToken0Bal := BalanceOf(pool.GetToken0(), poolAddr)
	poolNewToken1Bal := BalanceOf(pool.GetToken1(), poolAddr)

	userNewToken0Bal := BalanceOf(pool.GetToken0(), tr01)
	userNewToken1Bal := BalanceOf(pool.GetToken1(), tr01)

	lpNewToken0Bal := BalanceOf(pool.GetToken0(), lp01)
	lpNewToken1Bal := BalanceOf(pool.GetToken1(), lp01)

	shouldEQ(t, tPosTokenId, "1")
	println("after position mint\tpool.liquidity:", pool.GetLiquidity())
	println()

	println("owner of tokenId 1:", nft.OwnerOf(tid(tPosTokenId)))
	println()

	println("Liquidity Provider lp01")
	println("ㄴ token0:", lpOldToken0Bal, "->", lpNewToken0Bal, "( diff:", lpNewToken0Bal-lpOldToken0Bal, ")")
	println("ㄴ token1:", lpOldToken1Bal, "->", lpNewToken1Bal, "( diff:", lpNewToken1Bal-lpOldToken1Bal, ")")

	println("Pool")
	println("ㄴ token0:", poolOldToken0Bal, "->", poolNewToken0Bal, "( diff:", poolNewToken0Bal-poolOldToken0Bal, ")")
	println("ㄴ token1:", poolOldToken1Bal, "->", poolNewToken1Bal, "( diff:", poolNewToken1Bal-poolOldToken1Bal, ")")

	println("Trader tr01")
	println("ㄴ token0:", userOldToken0Bal, "->", userNewToken0Bal, "( diff:", userNewToken0Bal-userOldToken0Bal, ")")
	println("ㄴ token1:", userOldToken1Bal, "->", userNewToken1Bal, "( diff:", userNewToken1Bal-userOldToken1Bal, ")")
	println()
}

func TestStakerCreateIncentive(t *testing.T) {
	std.TestSetOrigCaller(ci01)
	st.CreateIncentive(
		tStartTime, // starTime
		tEndTime,   // endTime
		rf01,       // refundee
	)
}

func TestStakerStakeToken(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	st.StakeToken(
		tStartTime,
		tEndTime,
		rf01,
		"1",
		100,
	)

	println("owner of tokenId 1:", nft.OwnerOf(tid("1")))
	println()
}

func TestPoolSetFeeProtocol(t *testing.T) {
	std.TestSetOrigCaller(own)
	pl.SetFeeProtocol(pToken0, pToken1, pFee, 6, 8)
}

func TestPoolSwapFee01(t *testing.T) {
	pool := pl.GetPool("foo", "bar", 500)
	test_price := bigint(MIN_SQRT_RATIO + 1)

	println("Swap #1")
	println("ㄴ direction: token0 -> token1")
	println("ㄴ amountIn: 200000")

	poolOldToken0Bal := BalanceOf(pool.GetToken0(), poolAddr)
	poolOldToken1Bal := BalanceOf(pool.GetToken1(), poolAddr)

	userOldToken0Bal := BalanceOf(pool.GetToken0(), tr01)
	userOldToken1Bal := BalanceOf(pool.GetToken1(), tr01)

	ownerOldToken0Bal := BalanceOf(pool.GetToken0(), own)
	ownerOldToken1Bal := BalanceOf(pool.GetToken1(), own)

	std.TestSetOrigCaller(tr01)
	pl.Swap(pToken0, pToken1, pFee, tr01, true, 200000, MIN_SQRT_RATIO+1)

	std.TestSetOrigCaller(own)
	pl.CollectProtocol(pToken0, pToken1, pFee, own, 100000, 100000)

	poolNewToken0Bal := BalanceOf(pool.GetToken0(), poolAddr)
	poolNewToken1Bal := BalanceOf(pool.GetToken1(), poolAddr)

	userNewToken0Bal := BalanceOf(pool.GetToken0(), tr01)
	userNewToken1Bal := BalanceOf(pool.GetToken1(), tr01)

	ownerNewToken0Bal := BalanceOf(pool.GetToken0(), own)
	ownerNewToken1Bal := BalanceOf(pool.GetToken1(), own)

	println("Pool")
	println("ㄴ token0:", poolOldToken0Bal, "->", poolNewToken0Bal, "( diff:", poolNewToken0Bal-poolOldToken0Bal, ")")
	println("ㄴ token1:", poolOldToken1Bal, "->", poolNewToken1Bal, "( diff:", poolNewToken1Bal-poolOldToken1Bal, ")")

	println("Trader tr01")
	println("ㄴ token0:", userOldToken0Bal, "->", userNewToken0Bal, "( diff:", userNewToken0Bal-userOldToken0Bal, ")")
	println("ㄴ token1:", userOldToken1Bal, "->", userNewToken1Bal, "( diff:", userNewToken1Bal-userOldToken1Bal, ")")
	println()

	println("Owner own")
	println("ㄴ token0:", ownerOldToken0Bal, "->", ownerNewToken0Bal, "( diff:", ownerNewToken0Bal-ownerOldToken0Bal, ")")
	println("ㄴ token1:", ownerOldToken1Bal, "->", ownerNewToken1Bal, "( diff:", ownerNewToken1Bal-ownerOldToken1Bal, ")")
	println()
}

func TestPositionCollect01(t *testing.T) {
	pool := pl.GetPool("foo", "bar", 500)

	lpOldToken0Bal := BalanceOf(pool.GetToken0(), lp01)
	lpOldToken1Bal := BalanceOf(pool.GetToken1(), lp01)

	std.TestSetOrigCaller(lp01)
	ps.Collect(1, lp01, 100000, 100000)

	lpNewToken0Bal := BalanceOf(pool.GetToken0(), lp01)
	lpNewToken1Bal := BalanceOf(pool.GetToken1(), lp01)

	println("LP lp01")
	println("ㄴ token0:", lpOldToken0Bal, "->", lpNewToken0Bal, "( diff:", lpNewToken0Bal-lpOldToken0Bal, ")")
	println("ㄴ token1:", lpOldToken1Bal, "->", lpNewToken1Bal, "( diff:", lpNewToken1Bal-lpOldToken1Bal, ")")
	println()
}

func TestPoolSwapFee10(t *testing.T) {
	pool := pl.GetPool("foo", "bar", 500)
	test_price := bigint(MAX_SQRT_RATIO - 1)

	println("Swap #2")
	println("ㄴ direction: token1 -> token0")
	println("ㄴ amountIn: 200000")

	poolOldToken0Bal := BalanceOf(pool.GetToken0(), poolAddr)
	poolOldToken1Bal := BalanceOf(pool.GetToken1(), poolAddr)

	userOldToken0Bal := BalanceOf(pool.GetToken0(), tr01)
	userOldToken1Bal := BalanceOf(pool.GetToken1(), tr01)

	ownerOldToken0Bal := BalanceOf(pool.GetToken0(), own)
	ownerOldToken1Bal := BalanceOf(pool.GetToken1(), own)

	std.TestSetOrigCaller(tr01)
	pl.Swap(pToken0, pToken1, pFee, tr01, false, 200000, MAX_SQRT_RATIO-1)

	std.TestSetOrigCaller(own)
	pl.CollectProtocol(pToken0, pToken1, pFee, own, 100000, 100000)

	poolNewToken0Bal := BalanceOf(pool.GetToken0(), poolAddr)
	poolNewToken1Bal := BalanceOf(pool.GetToken1(), poolAddr)

	userNewToken0Bal := BalanceOf(pool.GetToken0(), tr01)
	userNewToken1Bal := BalanceOf(pool.GetToken1(), tr01)

	ownerNewToken0Bal := BalanceOf(pool.GetToken0(), own)
	ownerNewToken1Bal := BalanceOf(pool.GetToken1(), own)

	println("Pool")
	println("ㄴ token0:", poolOldToken0Bal, "->", poolNewToken0Bal, "( diff:", poolNewToken0Bal-poolOldToken0Bal, ")")
	println("ㄴ token1:", poolOldToken1Bal, "->", poolNewToken1Bal, "( diff:", poolNewToken1Bal-poolOldToken1Bal, ")")

	println("Trader tr01")
	println("ㄴ token0:", userOldToken0Bal, "->", userNewToken0Bal, "( diff:", userNewToken0Bal-userOldToken0Bal, ")")
	println("ㄴ token1:", userOldToken1Bal, "->", userNewToken1Bal, "( diff:", userNewToken1Bal-userOldToken1Bal, ")")
	println()

	println("Owner own")
	println("ㄴ token0:", ownerOldToken0Bal, "->", ownerNewToken0Bal, "( diff:", ownerNewToken0Bal-ownerOldToken0Bal, ")")
	println("ㄴ token1:", ownerOldToken1Bal, "->", ownerNewToken1Bal, "( diff:", ownerNewToken1Bal-ownerOldToken1Bal, ")")
	println()
}

func TestPositionCollect10(t *testing.T) {
	pool := pl.GetPool("foo", "bar", 500)

	lpOldToken0Bal := BalanceOf(pool.GetToken0(), lp01)
	lpOldToken1Bal := BalanceOf(pool.GetToken1(), lp01)

	std.TestSetOrigCaller(lp01)
	ps.Collect(1, lp01, 100000, 100000)

	lpNewToken0Bal := BalanceOf(pool.GetToken0(), lp01)
	lpNewToken1Bal := BalanceOf(pool.GetToken1(), lp01)

	println("LP lp01")
	println("ㄴ token0:", lpOldToken0Bal, "->", lpNewToken0Bal, "( diff:", lpNewToken0Bal-lpOldToken0Bal, ")")
	println("ㄴ token1:", lpOldToken1Bal, "->", lpNewToken1Bal, "( diff:", lpNewToken1Bal-lpOldToken1Bal, ")")
	println()
}

func TestStakerGetRewardInfo(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// XXX currently, amount of reward is exact same as amount of liquidity
	tReward, tSecondsInsideX128 := st.GetRewardInfo(
		tStartTime,
		tEndTime,
		rf01,
		"1",
	)
	println("reward:", tReward)
	println()
}

func TestStakerClaimReward(t *testing.T) {
	lpOldRewardBal := BalanceOf(gnos.GetGRC20(), lp01)

	std.TestSetOrigCaller(lp01)
	st.ClaimReward(tStartTime, tEndTime, rf01, "1")

	lpNewRewardBal := BalanceOf(gnos.GetGRC20(), lp01)

	println("LP lp01")
	println("ㄴ reward:", lpOldRewardBal, "->", lpNewRewardBal, "( diff:", lpNewRewardBal-lpOldRewardBal, ")")
	println()

	shouldGT(t, lpOldRewardBal, lpNewRewardBal)
}

func TestStakerUnstakeAndWithdraw(t *testing.T) {
	// NFT was staked with lockDuration 100 L#171
	// so, it can be withdrawl after 100 seconds since unstake requeset
	std.TestSetOrigCaller(lp01)

	st.UnstakeToken(tStartTime, tEndTime, rf01, "1")
	shouldEQ(t, nft.OwnerOf("1"), stakerAddr)

	shouldPanic(t, func() { st.WithdrawToken("1", GetOrigCaller()) })

	std.TestSkipTimestamps(99)
	shouldPanic(t, func() { st.WithdrawToken("1", GetOrigCaller()) })

	std.TestSkipTimestamps(1)
	shouldPanic(t, func() { st.WithdrawToken("1", GetOrigCaller()) })

	println("before nft 1 owner:", nft.OwnerOf("1"))
	std.TestSkipTimestamps(1)
	st.WithdrawToken("1", GetOrigCaller())
	shouldEQ(t, nft.OwnerOf("1"), GetOrigCaller())
	println("current nft 1 owner:", nft.OwnerOf("1"))
	println()
}

func TestPositionNFTBurn(t *testing.T) {
	pool := pl.GetPool("foo", "bar", 500)

	poolOldToken0Bal := BalanceOf(pool.GetToken0(), poolAddr)
	poolOldToken1Bal := BalanceOf(pool.GetToken1(), poolAddr)

	lpOldToken0Bal := BalanceOf(pool.GetToken0(), lp01)
	lpOldToken1Bal := BalanceOf(pool.GetToken1(), lp01)

	lpOldNftBal := ps.NFTBalanceOf(lp01)

	// remove all liquidity & collect
	tokenId := "1"
	position := ps.PositionGetPosition(tokenId)
	positionLiquidity := ps.PositionGetPositionTickLiquidity(tokenId)

	std.TestSetOrigCaller(lp01)
	ps.DecreaseLiquidity(bigint(tokenId), positionLiquidity, 0, 0, 2345678901)
	ps.Collect(bigint(tokenId), lp01, 1000000, 1000000)

	poolNewToken0Bal := BalanceOf(pool.GetToken0(), poolAddr)
	poolNewToken1Bal := BalanceOf(pool.GetToken1(), poolAddr)

	lpNewToken0Bal := BalanceOf(pool.GetToken0(), lp01)
	lpNewToken1Bal := BalanceOf(pool.GetToken1(), lp01)

	lpNewNftBal := ps.NFTBalanceOf(lp01)

	println("Pool")
	println("ㄴ token0:", poolOldToken0Bal, "->", poolNewToken0Bal, "( diff:", poolNewToken0Bal-poolOldToken0Bal, ")")
	println("ㄴ token1:", poolOldToken1Bal, "->", poolNewToken1Bal, "( diff:", poolNewToken1Bal-poolOldToken1Bal, ")")
	println()

	println("LP lp01")
	println("ㄴ token0:", lpOldToken0Bal, "->", lpNewToken0Bal, "( diff:", lpNewToken0Bal-lpOldToken0Bal, ")")
	println("ㄴ token1:", lpOldToken1Bal, "->", lpNewToken1Bal, "( diff:", lpNewToken1Bal-lpOldToken1Bal, ")")
	println()

	println("LP lp01 NFT")
	println("ㄴ Number of NFT(s):", lpOldNftBal, "->", lpNewNftBal, "( diff:", lpNewNftBal-lpOldNftBal, ")")
	println()
}

/* UTILS */
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
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}
