// multi pool same-tier reward scenario test
// This test verifies reward calculation when multiple pools share the same tier.
// It is designed to validate behavior after cacheRewardForPool optimization.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/router"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminUser)

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = testing.NewUserRealm(user1Addr)

	user2Addr  = testutils.TestAddress("user2")
	user2Realm = testing.NewUserRealm(user2Addr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath1 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
	poolPath2 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500"
	poolPath3 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000"

	position1 uint64
	position2 uint64
	position3 uint64
	position4 uint64
	reward1   int64
	reward2   int64
	reward3   int64
	reward4   int64
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create 3 pools and set tier 2")
	createPoolsAndSetTier()
	println()

	println("[SCENARIO] 3. Users mint and stake positions on each pool")
	mintAndStakePerPool()
	println()

	println("[SCENARIO] 4. Accumulate rewards")
	accumulateRewards()
	println()

	println("[SCENARIO] 5. Collect rewards from all positions")
	collectRewards()
	println()

	println("[SCENARIO] 6. Verify reward behavior remains correct")
	verifyScenario()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 7. ExactInSwapRoute BAR -> BAZ, bar:baz:100 to out-of-range")
	exactInSingleSwapRouteBy(
		poolPath1,
		barPath,
		bazPath,
		"2000",
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100",
		"100",
		"1",
	)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 8. Collect rewards from one position", position1)
	collectRewardByTokenID(position1)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 9. ExactInSwapRoute BAZ -> BAR, baz:bar:100 to in-range", position2)
	exactInSingleSwapRouteBy(
		poolPath1,
		bazPath,
		barPath,
		"2000",
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:100",
		"100",
		"1",
	)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 10. Collect rewards from all positions")
	collectRewards()
	println()

	println("[SCENARIO] 11. Verify reward behavior remains correct")
	verifyScenario()
	println()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] initialize staker realm")
	testing.SetRealm(stakerRealm)

	testing.SetRealm(adminRealm)
	println("[INFO] distribute tokens to users")
	bar.Transfer(cross, user1Addr, 50000)
	baz.Transfer(cross, user1Addr, 50000)
	bar.Transfer(cross, user2Addr, 50000)
	baz.Transfer(cross, user2Addr, 50000)
}

func createPoolsAndSetTier() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz pools with fee 100/500/3000")
	pl.CreatePool(cross, barPath, bazPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString())
	pl.CreatePool(cross, barPath, bazPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	pl.CreatePool(cross, barPath, bazPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] set all pools to tier 2")
	sr.SetPoolTier(cross, poolPath1, 2)
	sr.SetPoolTier(cross, poolPath2, 2)
	sr.SetPoolTier(cross, poolPath3, 2)
	testing.SkipHeights(1)

	t1 := sr.GetPoolTier(poolPath1)
	t2 := sr.GetPoolTier(poolPath2)
	t3 := sr.GetPoolTier(poolPath3)
	ufmt.Printf("[EXPECTED] pool tiers: %d,%d,%d (should be 2,2,2)\n", t1, t2, t3)
	if t1 != 2 || t2 != 2 || t3 != 2 {
		panic("all pools must remain tier 2")
	}
}

func mintAndStakePerPool() {
	testing.SetRealm(user1Realm)
	println("[INFO] user1 approve tokens")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	println("[INFO] user1 mint+stake on fee100 pool")
	p1, _, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		user1Addr,
		user1Addr,
		"",
	)
	position1 = uint64(p1)
	gnft.Approve(cross, stakerAddr, positionIdFrom(position1))
	sr.StakeToken(cross, position1, "")

	testing.SetRealm(user2Realm)
	println("[INFO] user2 approve tokens")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	println("[INFO] user2 mint+stake on fee500 pool")
	p2, _, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee500,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		user2Addr,
		user2Addr,
		"",
	)
	position2 = uint64(p2)
	gnft.Approve(cross, stakerAddr, positionIdFrom(position2))
	sr.StakeToken(cross, position2, "")

	testing.SetRealm(adminRealm)
	println("[INFO] admin approve tokens")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	println("[INFO] admin mint+stake on fee3000 pool")
	p3, _, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee3000,
		int32(-120),
		int32(120),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)
	position3 = uint64(p3)
	gnft.Approve(cross, stakerAddr, positionIdFrom(position3))
	sr.StakeToken(cross, position3, "")

	println("[INFO] admin only mint on fee100 pool")
	p4, _, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-200),
		int32(200),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)
	position4 = uint64(p4)

	ufmt.Printf("[EXPECTED] position IDs: %d,%d,%d,%d\n", position1, position2, position3, position4)
}

func accumulateRewards() {
	testing.SetRealm(adminRealm)
	println("[INFO] skip 20 blocks to accumulate rewards for all 3 pools")
	testing.SkipHeights(20)

	t1 := sr.GetPoolTier(poolPath1)
	t2 := sr.GetPoolTier(poolPath2)
	t3 := sr.GetPoolTier(poolPath3)
	if t1 != 2 || t2 != 2 || t3 != 2 {
		panic("tier must remain unchanged (2) for all pools")
	}
}

func collectRewards() {
	testing.SetRealm(user1Realm)
	before1 := gns.BalanceOf(user1Addr)
	sr.CollectReward(cross, position1)
	after1 := gns.BalanceOf(user1Addr)
	reward1 = after1 - before1

	testing.SetRealm(user2Realm)
	before2 := gns.BalanceOf(user2Addr)
	sr.CollectReward(cross, position2)
	after2 := gns.BalanceOf(user2Addr)
	reward2 = after2 - before2

	testing.SetRealm(adminRealm)
	before3 := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, position3)
	after3 := gns.BalanceOf(adminUser)
	reward3 = after3 - before3

	ufmt.Printf("[EXPECTED] rewards: %d,%d,%d (all should be > 0)\n", reward1, reward2, reward3)
}

func collectRewardByTokenID(tokenID uint64) {
	testing.SetRealm(user1Realm)

	ufmt.Println("[INFO] collect reward by tokenID:", tokenID)
	before := gns.BalanceOf(user1Addr)
	sr.CollectReward(cross, tokenID)
	after := gns.BalanceOf(user1Addr)
	ufmt.Printf("[EXPECTED] reward: %d (should be > 0)\n", after-before)
}

func verifyScenario() {
	testing.SetRealm(adminRealm)

	if reward1 <= 0 || reward2 <= 0 || reward3 <= 0 {
		panic("all positions must receive positive rewards")
	}

	// The key invariant for this scenario:
	// reward calculation remains healthy with multiple pools in the same tier,
	// without any tier change/removal during the run.
	total := reward1 + reward2 + reward3
	ufmt.Printf("[EXPECTED] total reward across 3 tier2 pools: %d\n", total)

	println("[INFO] scenario completed successfully")
	println("[INFO] confirmed: cacheRewardForPool path works with 3 pools in same tier")
	println("[INFO] confirmed: rewards are computed correctly without tier change/removal")
}

func exactInSingleSwapRouteBy(
	poolPath string,
	inputToken string,
	outputToken string,
	specifiedAmount string,
	routeQueryString string,
	queryRatios string,
	minAmountOut string,
) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] ExactInSwapRoute")
	ufmt.Println("[INFO] inputToken:", inputToken)
	ufmt.Println("[INFO] outputToken:", outputToken)
	ufmt.Println("[INFO] specifiedAmount:", specifiedAmount)
	ufmt.Println("[INFO] routeQueryString:", routeQueryString)
	ufmt.Println("[INFO] queryRatios:", queryRatios)
	ufmt.Println("[INFO] minAmountOut:", minAmountOut)

	beforeBARBalance := bar.BalanceOf(adminAddr)
	beforeBAZBalance := baz.BalanceOf(adminAddr)

	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	bar.Approve(cross, routerAddr, maxInt64)
	baz.Approve(cross, routerAddr, maxInt64)

	beforePoolTick := pl.GetSlot0Tick(poolPath)

	// current sqrtPriceX96 is 76228162514264337593543950336
	inputTokenAmount, outputTokenAmount := router.ExactInSingleSwapRoute(
		cross,
		inputToken,
		outputToken,
		specifiedAmount,
		routeQueryString,
		minAmountOut,
		"0",
		int64(9999999999),
		"",
	)

	afterBARBalance := bar.BalanceOf(adminAddr)
	afterBAZBalance := baz.BalanceOf(adminAddr)

	afterPoolTick := pl.GetSlot0Tick(poolPath)

	ufmt.Printf("[EXPECTED] inputTokenAmount: %s\n", inputTokenAmount)
	ufmt.Printf("[EXPECTED] outputTokenAmount: %s\n", outputTokenAmount)
	ufmt.Printf("[EXPECTED] BAR balance changed: %d\n", afterBARBalance-beforeBARBalance)
	ufmt.Printf("[EXPECTED] BAZ balance changed: %d\n", afterBAZBalance-beforeBAZBalance)
	ufmt.Printf("[EXPECTED] pool tick changed: %d to %d\n", beforePoolTick, afterPoolTick)
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
// [SCENARIO] 1. Initialize and setup
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] initialize staker realm
// [INFO] distribute tokens to users
//
// [SCENARIO] 2. Create 3 pools and set tier 2
// [INFO] create bar:baz pools with fee 100/500/3000
// [INFO] set all pools to tier 2
// [EXPECTED] pool tiers: 2,2,2 (should be 2,2,2)
//
// [SCENARIO] 3. Users mint and stake positions on each pool
// [INFO] user1 approve tokens
// [INFO] user1 mint+stake on fee100 pool
// [INFO] user2 approve tokens
// [INFO] user2 mint+stake on fee500 pool
// [INFO] admin approve tokens
// [INFO] admin mint+stake on fee3000 pool
// [INFO] admin only mint on fee100 pool
// [EXPECTED] position IDs: 1,2,3,4
//
// [SCENARIO] 4. Accumulate rewards
// [INFO] skip 20 blocks to accumulate rewards for all 3 pools
//
// [SCENARIO] 5. Collect rewards from all positions
// [EXPECTED] rewards: 16053059,16053059,16053059 (all should be > 0)
//
// [SCENARIO] 6. Verify reward behavior remains correct
// [EXPECTED] total reward across 3 tier2 pools: 48159177
// [INFO] scenario completed successfully
// [INFO] confirmed: cacheRewardForPool path works with 3 pools in same tier
// [INFO] confirmed: rewards are computed correctly without tier change/removal
//
// [SCENARIO] 7. ExactInSwapRoute BAR -> BAZ, bar:baz:100 to out-of-range
// [INFO] ExactInSwapRoute
// [INFO] inputToken: gno.land/r/onbloc/bar
// [INFO] outputToken: gno.land/r/onbloc/baz
// [INFO] specifiedAmount: 2000
// [INFO] routeQueryString: gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] inputTokenAmount: 2000
// [EXPECTED] outputTokenAmount: -1980
// [EXPECTED] BAR balance changed: -2000
// [EXPECTED] BAZ balance changed: 1980
// [EXPECTED] pool tick changed: 0 to -197
//
// [SCENARIO] 8. Collect rewards from one position 1
// [INFO] collect reward by tokenID: 1
// [EXPECTED] reward: 802652 (should be > 0)
//
// [SCENARIO] 9. ExactInSwapRoute BAZ -> BAR, baz:bar:100 to in-range 2
// [INFO] ExactInSwapRoute
// [INFO] inputToken: gno.land/r/onbloc/baz
// [INFO] outputToken: gno.land/r/onbloc/bar
// [INFO] specifiedAmount: 2000
// [INFO] routeQueryString: gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:100
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] inputTokenAmount: 2000
// [EXPECTED] outputTokenAmount: -2006
// [EXPECTED] BAR balance changed: 2006
// [EXPECTED] BAZ balance changed: -2000
// [EXPECTED] pool tick changed: -197 to 0
//
// [SCENARIO] 10. Collect rewards from all positions
// [EXPECTED] rewards: 802652,3210611,3210611 (all should be > 0)
//
// [SCENARIO] 11. Verify reward behavior remains correct
// [EXPECTED] total reward across 3 tier2 pools: 7223874
// [INFO] scenario completed successfully
// [INFO] confirmed: cacheRewardForPool path works with 3 pools in same tier
// [INFO] confirmed: rewards are computed correctly without tier change/removal
