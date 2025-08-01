// full internal and external reward scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/demo/wugnot"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	rr "gno.land/r/gnoswap/v1/router"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _          = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _        = access.GetAddress(prabc.ROLE_ROUTER.String())
	emissionAddr, _      = access.GetAddress(prabc.ROLE_EMISSION.String())
	devOpsAddr, _        = access.GetAddress(prabc.ROLE_DEVOPS.String())
	communityPoolAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	wugnotAddr std.Address = "g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"

	externalCreator = testutils.TestAddress("externalCreator")

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"
	quxPath = "gno.land/r/onbloc/qux"

	gnsPath    = "gno.land/r/gnoswap/v1/gns"
	wugnotPath = "gno.land/r/demo/wugnot"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS  int64 = 90 * 24 * 60 * 60
	TIMESTAMP_180DAYS int64 = 180 * 24 * 60 * 60
	TIMESTAMP_365DAYS int64 = 365 * 24 * 60 * 60
)

func main() {
	println("[SCENARIO] 1. Initialize account and emission")
	initAccount()
	println()

	println("[SCENARIO] 2. Create wugnot:gns:3000 pool (tier 1)")
	createPoolWugnotGns3000Tier01()
	println()

	println("[SCENARIO] 3. Create external incentive (GNS)")
	createExternalIncentiveGns()
	println()

	println("[SCENARIO] 4. Mint position 01 (in-range)")
	mintPos01InRange()
	println()

	println("[SCENARIO] 5. Create bar:baz:500 pool (tier 2)")
	createBarBaz500Tier02()
	println()

	println("[SCENARIO] 6. Mint positions 02-06")
	mintPositions02To06()
	println()

	println("[SCENARIO] 7. Stake all tokens")
	stakeAllTokens()
	println()

	println("[SCENARIO] 8. Collect rewards for all warm-up periods")
	collectRewardsAllWarmUp()
	println()

	println("[SCENARIO] 9. Perform swaps")
	performSwaps()
	println()

	println("[SCENARIO] 10. Create bar:foo:100 pool (tier 3)")
	createPoolBarFoo100Tier03()
	println()

	println("[SCENARIO] 11. One-click staking position 07 (out-range)")
	oneClickStakingPos07OutRange()
	println()

	println("[SCENARIO] 12. Unstake token 01")
	unstakeToken01()
	println()

	println("[SCENARIO] 13. Create pool with external incentive only")
	createPoolExternalOnly()
	println()
}

func initAccount() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] change distribution percentage")
	emission.ChangeDistributionPctByAdmin(
		cross,
		1, 7500, // staker
		2, 2500, // devOps
		3, 0, // community pool
		4, 0, // xGNS
	)

	println("[INFO] issue coins and prepare wugnot")
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100_000_000_000_000}})
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, wugnotAddr, std.Coins{{"ugnot", 50_000_000_000_000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50_000_000_000_000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(nil)

	wugnotBalance := wugnot.BalanceOf(adminAddr)
	ufmt.Printf("[EXPECTED] wugnot balance: %d\n", wugnotBalance)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPoolWugnotGns3000Tier01() {
	testing.SetRealm(adminRealm)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] approve gns and create pool")
	gns.Approve(cross, poolAddr, maxInt64)
	pl.CreatePool(cross, wugnotPath, gnsPath, 3000, common.TickMathGetSqrtRatioAtTick(0).ToString())

	totalSupply := gns.TotalSupply()
	ufmt.Printf("[EXPECTED] gns total supply: %d\n", totalSupply)

	testing.SkipHeights(3)
}

func createExternalIncentiveGns() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve gns for external incentive")
	gns.Approve(cross, stakerAddr, maxInt64)

	println("[INFO] create external incentive")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000",
		"gno.land/r/gnoswap/v1/gns",
		2_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	testing.SkipHeights(1)
}

func mintPos01InRange() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens and mint position")
	wugnot.Approve(cross, poolAddr, maxInt64)
	gns.Approve(cross, poolAddr, maxInt64)

	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(-60),
		int32(60),
		"1000",
		"1000",
		"0",
		"0",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position ID: %d, liquidity: %s\n", positionId, liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)

	testing.SkipHeights(1)
}

func createBarBaz500Tier02() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:500 pool")
	gns.Approve(cross, poolAddr, maxInt64)
	pl.CreatePool(cross, barPath, bazPath, 500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] set pool tier to 2")
	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500", 2)

	testing.SkipHeights(1)
}

func mintPositions02To06() {
	testing.SetRealm(adminRealm)

	println("[INFO] mint position 02 (bar:baz in-range)")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	pn.Mint(
		cross,
		barPath,
		bazPath,
		fee500,
		int32(-60),
		int32(60),
		"1000",
		"1000",
		"0",
		"0",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	testing.SkipHeights(1)

	println("[INFO] mint positions 03-06 (out-range)")
	// Position 03 (wugnot:gns out-range)
	for i := 3; i <= 6; i++ {
		wugnot.Approve(cross, poolAddr, maxInt64)
		gns.Approve(cross, poolAddr, maxInt64)

		pn.Mint(
			cross,
			wugnotPath,
			gnsPath,
			fee3000,
			int32(60),
			int32(120),
			"1000",
			"1000",
			"0",
			"0",
			maxTimeout,
			adminAddr,
			adminAddr,
			"",
		)

		testing.SkipHeights(1)
	}

	// Continue with positions 04-06...
	// (Similar pattern for positions 04, 05, 06)
}

func stakeAllTokens() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake tokens 01-06")
	for i := 1; i <= 6; i++ {
		gnft.Approve(cross, stakerAddr, positionIdFrom(i))
		sr.StakeToken(cross, uint64(i), "")
		testing.SkipHeights(1)
	}
}

func collectRewardsAllWarmUp() {
	testing.SetRealm(adminRealm)

	println("[INFO] collect rewards for 30% warm-up")
	for i := 1; i <= 6; i++ {
		sr.CollectReward(cross, uint64(i), false)
	}
	testing.SkipHeights(1)

	// Skip to different warm-up periods and collect rewards
	println("[INFO] progress to 50% warm-up")
	msInDay := int64(86400000)
	blocksInDay := msInDay / int64(gns.AvgBlockTimeInMs())
	blocksIn5Days := int64(5 * blocksInDay)
	testing.SkipHeights(blocksIn5Days)

	for i := 1; i <= 6; i++ {
		sr.CollectReward(cross, uint64(i), false)
	}
	testing.SkipHeights(1)
}

func performSwaps() {
	testing.SetRealm(adminRealm)

	println("[INFO] perform exact-in swaps")
	wugnot.Approve(cross, poolAddr, maxInt64)
	gns.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, routerAddr, maxInt64)
	gns.Approve(cross, routerAddr, maxInt64)

	tokenIn, tokenOut := rr.ExactInSwapRoute(
		cross,
		wugnotPath,
		gnsPath,
		"500",
		"gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000",
		"100",
		"0",
		maxTimeout,
		"",
	)

	ufmt.Printf("[EXPECTED] swap result - tokenIn: %s, tokenOut: %s\n", tokenIn, tokenOut)
	testing.SkipHeights(1)

	println("[INFO] check reward for position 01 after swap")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 01 reward after swap: %d\n", diff)
	testing.SkipHeights(1)
}

func createPoolBarFoo100Tier03() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:foo:100 pool")
	pl.CreatePool(cross, barPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(600000).ToString())
	testing.SkipHeights(1)

	println("[INFO] set pool tier to 3")
	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:100", 3)
	testing.SkipHeights(1)
}

func oneClickStakingPos07OutRange() {
	testing.SetRealm(adminRealm)

	println("[INFO] mint and stake position 07 (one-click)")
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)

	lpTokenId, liquidity, amount0, amount1, poolPath := sr.MintAndStake(
		cross,
		barPath,
		fooPath,
		fee100,
		int32(-60),
		int32(60),
		"1000",
		"1000",
		"0",
		"0",
		maxTimeout,
		"",
	)

	ufmt.Printf("[EXPECTED] mint and stake result - ID: %d, liquidity: %s\n", lpTokenId, liquidity)
	ufmt.Printf("[EXPECTED] amounts - 0: %s, 1: %s, pool: %s\n", amount0, amount1, poolPath)

	testing.SkipHeights(1)

	println("[INFO] collect reward for position 07")
	oldCommunityPool := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, 7, false)
	newCommunityPool := gns.BalanceOf(communityPoolAddr)

	rewardToCommunity := newCommunityPool - oldCommunityPool
	ufmt.Printf("[EXPECTED] reward to community pool: %d\n", rewardToCommunity)

	testing.SkipHeights(1)
}

func unstakeToken01() {
	testing.SetRealm(adminRealm)

	println("[INFO] unstake token 01")
	beforeGns := gns.BalanceOf(adminUser)
	sr.UnStakeToken(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)

	rewardFromUnstake := afterGns - beforeGns
	ufmt.Printf("[EXPECTED] reward from unstaking: %d\n", rewardFromUnstake)

	testing.SkipHeights(1)
}

func createPoolExternalOnly() {
	testing.SetRealm(adminRealm)

	println("[INFO] create baz:qux:3000 pool (external only)")
	pl.CreatePool(cross, bazPath, quxPath, 3000, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SkipHeights(1)

	println("[INFO] create external incentive (baz)")
	baz.Transfer(cross, externalCreator, 2_000_000_000)
	gns.Transfer(cross, externalCreator, depositGnsAmount)

	testing.SetRealm(std.NewUserRealm(externalCreator))
	baz.Approve(cross, stakerAddr, 2_000_000_000)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	startTime := int64(1244332800)
	endTime := startTime + TIMESTAMP_90DAYS

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:3000",
		bazPath,
		2_000_000_000,
		startTime,
		endTime,
	)

	ufmt.Printf("[EXPECTED] external incentive created - start: %d, end: %d\n", startTime, endTime)

	testing.SkipHeights(1)
}

func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic("positionId is nil")
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize account and emission
// [INFO] set unstaking fee to 0
// [INFO] change distribution percentage
// [INFO] issue coins and prepare wugnot
// [EXPECTED] wugnot balance: 50000000000000
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create wugnot:gns:3000 pool (tier 1)
// [INFO] set pool creation fee to 0
// [INFO] approve gns and create pool
// [EXPECTED] gns total supply: 100000000000000
//
// [SCENARIO] 3. Create external incentive (GNS)
// [INFO] approve gns for external incentive
// [INFO] create external incentive
//
// [SCENARIO] 4. Mint position 01 (in-range)
// [INFO] approve tokens and mint position
// [EXPECTED] position ID: 1, liquidity: 333850
// [EXPECTED] amount0: 1000, amount1: 1000
//
// [SCENARIO] 5. Create bar:baz:500 pool (tier 2)
// [INFO] create bar:baz:500 pool
// [INFO] set pool tier to 2
//
// [SCENARIO] 6. Mint positions 02-06
// [INFO] mint position 02 (bar:baz in-range)
// [INFO] mint positions 03-06 (out-range)
//
// [SCENARIO] 7. Stake all tokens
// [INFO] stake tokens 01-06
//
// [SCENARIO] 8. Collect rewards for all warm-up periods
// [INFO] collect rewards for 30% warm-up
// [INFO] progress to 50% warm-up
//
// [SCENARIO] 9. Perform swaps
// [INFO] perform exact-in swaps
// [EXPECTED] swap result - tokenIn: 500, tokenOut: -497
// [INFO] check reward for position 01 after swap
// [EXPECTED] position 01 reward after swap: 7491949
//
// [SCENARIO] 10. Create bar:foo:100 pool (tier 3)
// [INFO] create bar:foo:100 pool
// [INFO] set pool tier to 3
//
// [SCENARIO] 11. One-click staking position 07 (out-range)
// [INFO] mint and stake position 07 (one-click)
// [EXPECTED] mint and stake result - ID: 7, liquidity: 166674
// [EXPECTED] amounts - 0: 0, 1: 1000, pool: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:100
// [INFO] collect reward for position 07
// [EXPECTED] reward to community pool: 4280820
//
// [SCENARIO] 12. Unstake token 01
// [INFO] unstake token 01
// [EXPECTED] reward from unstaking: 15519260
//
// [SCENARIO] 13. Create pool with external incentive only
// [INFO] create baz:qux:3000 pool (external only)
// [INFO] create external incentive (baz)
// [EXPECTED] external incentive created - start: 1244332800, end: 1252108800
