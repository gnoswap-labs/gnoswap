// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/gnsmath"
	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	rr "gno.land/r/gnoswap/router"
	sr "gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"

	fee100     uint32 = 100
	maxTimeout int64  = 9999999999
	maxInt64   int64  = 9223372036854775807
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Create pool at tick 15")
	createPool(cur)
	println()

	println("[SCENARIO] 3. Mint adjacent equal-liquidity positions")
	mintAdjacentPositions(cur)
	println()

	println("[SCENARIO] 4. Stake both positions and clear rewards")
	stakeAndClearRewards(cur)
	println()

	println("[SCENARIO] 5. Cross the shared boundary tick")
	crossSharedBoundary(cur)
	println()

	println("[SCENARIO] 6. Verify reward moves across zero-net boundary")
	verifyRewardAfterBoundaryCross(cur)
	println()
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetWarmUp(cross(cur), 30, 150)
	sr.SetWarmUp(cross(cur), 50, 300)
	sr.SetWarmUp(cross(cur), 70, 900)
	sr.SetWarmUp(cross(cur), 100, maxInt64)
	sr.SetUnStakingFee(cross(cur), 0)

	testing.SetRealm(stakerRealm)
	testing.SkipHeights(1)
}

func createPool(cur realm) {
	testing.SetRealm(adminRealm)

	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee())
	pl.CreatePool(cross(cur), barPath, bazPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(15).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	if tick := pl.GetSlot0Tick(poolPath); tick != 15 {
		panic(ufmt.Sprintf("expected initial pool tick 15, got %d", tick))
	}

	ufmt.Printf("[EXPECTED] pool created at tick %d\n", pl.GetSlot0Tick(poolPath))
	testing.SkipHeights(1)
}

func mintAdjacentPositions(cur realm) {
	mintPosition(cur, 0, 10, "0", "200000")
	mintPosition(cur, 10, 20, "100000", "100000")
	matchPositionLiquidity(cur, 1, 2)

	liq1 := pn.GetPositionLiquidity(1)
	liq2 := pn.GetPositionLiquidity(2)
	ufmt.Printf("[INFO] position 1 liquidity: %s\n", liq1)
	ufmt.Printf("[INFO] position 2 liquidity: %s\n", liq2)
	if liq1 != liq2 {
		panic(ufmt.Sprintf("expected equal liquidity for zero-net boundary, got %s and %s", liq1, liq2))
	}

	ufmt.Printf("[EXPECTED] adjacent positions share tick 10 with equal liquidity\n")
}

func matchPositionLiquidity(cur realm, positionId1 uint64, positionId2 uint64) {
	liq1, err := strconv.Atoi(pn.GetPositionLiquidity(positionId1))
	if err != nil {
		panic(err)
	}
	liq2, err := strconv.Atoi(pn.GetPositionLiquidity(positionId2))
	if err != nil {
		panic(err)
	}

	if liq1 > liq2 {
		trimPositionLiquidity(cur, positionId1, liq1-liq2)
		return
	}
	if liq2 > liq1 {
		trimPositionLiquidity(cur, positionId2, liq2-liq1)
		return
	}
}

func trimPositionLiquidity(cur realm, positionId uint64, removedLiquidity int) {
	_, liquidity, _, _, amount0, amount1, _ := pn.DecreaseLiquidity(
		cross(cur),
		positionId,
		strconv.Itoa(removedLiquidity),
		"0",
		"0",
		maxTimeout,
	)

	ufmt.Printf(
		"[INFO] trimmed position %d liquidity=%s amount0=%s amount1=%s\n",
		positionId,
		liquidity,
		amount0,
		amount1,
	)
	testing.SkipHeights(1)
}

func mintPosition(cur realm, tickLower int32, tickUpper int32, amount0 string, amount1 string) {
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)

	positionId, liquidity, used0, used1 := pn.Mint(
		cross(cur),
		barPath,
		bazPath,
		fee100,
		tickLower,
		tickUpper,
		amount0,
		amount1,
		"0",
		"0",
		maxTimeout,
		adminUser,
		"",
	)

	ufmt.Printf(
		"[INFO] minted position %d [%d,%d] liquidity=%s amount0=%s amount1=%s\n",
		positionId,
		tickLower,
		tickUpper,
		liquidity,
		used0,
		used1,
	)
	testing.SkipHeights(1)
}

func stakeAndClearRewards(cur realm) {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 1))
	sr.StakeToken(cross(cur), 1, "")
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 2))
	sr.StakeToken(cross(cur), 2, "")

	testing.SkipHeights(1)
	sr.CollectReward(cross(cur), 1)
	sr.CollectReward(cross(cur), 2)

	ufmt.Printf("[EXPECTED] positions staked and rewards cleared\n")
	testing.SkipHeights(1)
}

func crossSharedBoundary(cur realm) {
	testing.SetRealm(adminRealm)

	beforeTick := pl.GetSlot0Tick(poolPath)
	if beforeTick < 10 {
		panic(ufmt.Sprintf("expected tick above shared boundary before swap, got %d", beforeTick))
	}

	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)
	bar.Approve(cross(cur), routerAddr, maxInt64)
	baz.Approve(cross(cur), routerAddr, maxInt64)

	tokenIn, tokenOut := rr.ExactInSwapRoute(
		cross(cur),
		barPath,
		bazPath,
		"100000",
		poolPath,
		"100",
		"0",
		maxTimeout,
		"",
	)

	afterTick := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] swapped %s BAR for %s BAZ\n", tokenIn, tokenOut)
	ufmt.Printf("[INFO] tick moved %d -> %d\n", beforeTick, afterTick)
	if afterTick >= 10 {
		panic(ufmt.Sprintf("expected swap to cross shared tick 10, got %d", afterTick))
	}

	sr.CollectReward(cross(cur), 1)
	sr.CollectReward(cross(cur), 2)
	ufmt.Printf("[INFO] cleared transition rewards after boundary cross\n")
	testing.SkipHeights(1)
}

func verifyRewardAfterBoundaryCross(cur realm) {
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1)
	afterGns := gns.BalanceOf(adminUser)
	position1Reward := afterGns - beforeGns

	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 2)
	afterGns = gns.BalanceOf(adminUser)
	position2Reward := afterGns - beforeGns

	ufmt.Printf("[INFO] position 1 reward after boundary cross: %d GNS\n", position1Reward)
	ufmt.Printf("[INFO] position 2 reward after boundary cross: %d GNS\n", position2Reward)

	if position1Reward <= 0 {
		panic(ufmt.Sprintf("expected position 1 to receive reward after boundary cross, got %d", position1Reward))
	}
	if position2Reward != 0 {
		panic(ufmt.Sprintf("expected position 2 to stop receiving reward, got %d", position2Reward))
	}

	ufmt.Printf("[EXPECTED] reward moved from [10,20] to [0,10] across zero-net shared boundary\n")
}

func positionIdFrom(cur realm, positionId any) grc721.TokenID {
	switch positionId := positionId.(type) {
	case string:
		return grc721.TokenID(positionId)
	case int:
		return grc721.TokenID(strconv.Itoa(positionId))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId)))
	case grc721.TokenID:
		return positionId
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize and setup
//
// [SCENARIO] 2. Create pool at tick 15
// [EXPECTED] pool created at tick 15
//
// [SCENARIO] 3. Mint adjacent equal-liquidity positions
// [INFO] minted position 1 [0,10] liquidity=399920007 amount0=0 amount1=200000
// [INFO] minted position 2 [10,20] liquidity=399770076 amount0=99851 amount1=100000
// [INFO] trimmed position 1 liquidity=149931 amount0=0 amount1=74
// [INFO] position 1 liquidity: 399770076
// [INFO] position 2 liquidity: 399770076
// [EXPECTED] adjacent positions share tick 10 with equal liquidity
//
// [SCENARIO] 4. Stake both positions and clear rewards
// [EXPECTED] positions staked and rewards cleared
//
// [SCENARIO] 5. Cross the shared boundary tick
// [INFO] swapped 100000 BAR for -99962 BAZ
// [INFO] tick moved 15 -> 9
// [INFO] cleared transition rewards after boundary cross
//
// [SCENARIO] 6. Verify reward moves across zero-net boundary
// [INFO] position 1 reward after boundary cross: 8026538 GNS
// [INFO] position 2 reward after boundary cross: 0 GNS
// [EXPECTED] reward moved from [10,20] to [0,10] across zero-net shared boundary
