// staking an out-of-range position on a pool with tick-crossing history keeps
// its rewards collectable (boundary-tick OutsideAccumulation seeding)

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

// Scenario for boundary-tick OutsideAccumulation seeding.
//
// Staker rewards use a Uniswap-V3-style accumulator pair: a pool-global
// accumulation G(t) plus a per-tick "outside" accumulation, combined into the
// position's raw reward by one of three branches:
//
//	below lower : raw = out(lower) - out(upper)
//	above upper : raw = out(upper) - out(lower)
//	in range    : raw = G - out(lower) - out(upper)
//
// A boundary tick created by a stake is seeded with the current global
// accumulation when it sits at or below the price, following Uniswap V3's
// `tick <= tickCurrent` rule, so the three branches stay consistent with each
// other. Raw rewards are additionally subtracted modulo 2^256, because a
// position whose boundaries were created at different times can legitimately
// start from a wrapped base.
//
// This scenario walks the configuration that used to brick a deposit, through
// the real pool, position, router and staker entry points:
//
//	tick 0 is crossed twice, so its outside value is positive
//	tick 5 is created by the victim's stake and seeded there
//	the victim stakes [0, 5] while the price sits above the range
//	the price returns into the range and rewards accrue
//
// Before the fix, rewardPerWarmup rejected the resulting borrow and aborted with
// GNOSWAP-STAKER-019. CollectReward and UnStakeToken both run that calculation
// before doing anything else, and every checkpoint tree is append-only, so the
// deposit and the position NFT held by the staker were locked permanently. The
// golden output below asserts that both now succeed.

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/r/gnoswap/scenarioutils"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	rt "gno.land/r/gnoswap/router"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

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
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	bazPath = "gno.land/r/onbloc/baz.BAZ"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath  = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"
	routePath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"
)

// Position ids in mint order.
const (
	depthPositionId  uint64 = 1 // wide, unstaked - gives the pool depth to swap against
	stakedLowId      uint64 = 2 // [0, 10]  - makes tick 0 and tick 10 staked boundaries
	stakedWideId     uint64 = 3 // [-20, 40] - keeps the accumulator moving
	victimPositionId uint64 = 4 // [0, 5]   - staked above its range, tick 5 created there
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool at tick 0")
	createPool(cur)
	println()

	println("[SCENARIO] 3. Provide pool depth and stake position [0, 10]")
	provideDepthAndStakeLow(cur)
	println()

	println("[SCENARIO] 4. Swap price below tick 0 (tick 0 crosses down)")
	swapToTick(cur, -1)
	println()

	println("[SCENARIO] 5. Stake wide position [-20, 40] to keep accruing")
	stakeWide(cur)
	println()

	println("[SCENARIO] 6. Swap price above tick 10 (tick 0 and 10 cross up)")
	swapToTick(cur, 20)
	println()

	println("[SCENARIO] 7. Stake position [0, 5] while above its range")
	stakeOutOfRange(cur)
	println()

	println("[SCENARIO] 8. Swap price back into the position's range")
	swapToTick(cur, 2)
	println()

	println("[SCENARIO] 9. Collect reward for the out-of-range stake")
	collectReward(cur)
	println()

	println("[SCENARIO] 10. Collect again and unstake")
	collectAgainAndUnstake(cur)
	println()

	println("[SCENARIO] 11. Other deposits are unaffected")
	collectOtherDeposit(cur)
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)
	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross(cur), 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross(cur), 0)

	println("[INFO] approve tokens for pool and router")
	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)
	bar.Approve(cross(cur), routerAddr, maxInt64)
	baz.Approve(cross(cur), routerAddr, maxInt64)
}

func createPool(cur realm) {
	testing.SetRealm(adminRealm)

	pl.CreatePool(cross(cur), barPath, bazPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	printTick("pool created")
	testing.SkipHeights(1)
}

func provideDepthAndStakeLow(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] mint wide unstaked position (-100 ~ 100) for swap depth")
	mint(cur, -100, 100, "100000000", "100000000")

	println("[INFO] mint and stake position [0, 10]")
	mint(cur, 0, 10, "10000000", "10000000")
	stake(cur, stakedLowId)

	testing.SkipHeights(5)
	printTick("after staking [0, 10]")
}

func stakeWide(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] mint and stake position [-20, 40]")
	mint(cur, -20, 40, "100000000", "100000000")
	stake(cur, stakedWideId)

	// Kept short on purpose: the accumulation between tick 0's two crossings is
	// the offset the out-of-range stake's raw base is measured against.
	testing.SkipHeights(1)
	printTick("after staking [-20, 40]")
}

func stakeOutOfRange(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] mint and stake position [0, 5]")
	mint(cur, 0, 5, "10000000", "10000000")

	currentTick, _ := pl.GetSlot0Tick(poolPath)
	if currentTick < 5 {
		panic("position must be staked above its range")
	}
	ufmt.Printf("[EXPECTED] current tick %d is above the range upper bound 5\n", currentTick)

	stake(cur, victimPositionId)
	inRange, _ := pn.IsInRange(victimPositionId)
	ufmt.Printf("[EXPECTED] in range after staking: %t\n", inRange)

	testing.SkipHeights(1)
}

func collectReward(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] accumulate rewards while the position is in range")
	testing.SkipHeights(100)

	inRange, _ := pn.IsInRange(victimPositionId)
	ufmt.Printf("[INFO] in range: %t\n", inRange)

	// revive would catch a cross-realm abort; the collect must not raise one.
	before := gns.BalanceOf(adminAddr)
	r := revive(func() {
		sr.CollectReward(cross(cur), victimPositionId)
	})
	after := gns.BalanceOf(adminAddr)

	if r != nil {
		panic(ufmt.Sprintf("[ERROR] CollectReward must not abort, got: %v", r))
	}
	ufmt.Printf("[EXPECTED] CollectReward succeeded, reward received: %t\n", after > before)
}

func collectAgainAndUnstake(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] skip more blocks and collect again")
	testing.SkipHeights(50)

	retry := revive(func() {
		sr.CollectReward(cross(cur), victimPositionId)
	})
	if retry != nil {
		panic(ufmt.Sprintf("[ERROR] the second CollectReward must not abort, got: %v", retry))
	}
	println("[EXPECTED] second CollectReward succeeded")

	// UnStakeToken runs the same reward calculation before touching anything
	// else, so it is the operation that used to make the NFT unrecoverable.
	unstake := revive(func() {
		sr.UnStakeToken(cross(cur), victimPositionId)
	})
	if unstake != nil {
		panic(ufmt.Sprintf("[ERROR] UnStakeToken must not abort, got: %v", unstake))
	}
	println("[EXPECTED] UnStakeToken succeeded")

	owner := gnft.MustOwnerOf(positionIdFrom(victimPositionId))
	ufmt.Printf("[EXPECTED] NFT returned to the owner: %t\n", owner == adminAddr)
}

func collectOtherDeposit(cur realm) {
	testing.SetRealm(adminRealm)

	before := gns.BalanceOf(adminAddr)
	other := revive(func() {
		sr.CollectReward(cross(cur), stakedWideId)
	})
	after := gns.BalanceOf(adminAddr)

	if other != nil {
		panic(ufmt.Sprintf("[ERROR] an unrelated deposit must stay collectable, got: %v", other))
	}
	ufmt.Printf("[EXPECTED] unrelated deposit collected reward: %t\n", after > before)
	println("[INFO] out-of-range staking no longer strands rewards or the position NFT")
}

// --- helpers -----------------------------------------------------------------

func mint(cur realm, tickLower, tickUpper int32, amount0, amount1 string) {
	positionId, liquidity, _, _ := pn.Mint(
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
		adminAddr,
		"",
	)
	ufmt.Printf("[EXPECTED] minted position %d [%d, %d] liquidity %s\n", positionId, tickLower, tickUpper, liquidity)
}

func stake(cur realm, positionId uint64) {
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross(cur), positionId, "")
	ufmt.Printf("[EXPECTED] staked position %d\n", positionId)
}

// swapToTick pushes the pool price to targetTick using a price-limited swap, so
// the resulting tick is deterministic regardless of how much liquidity sits in
// between. bar is token0, so selling bar moves the tick down and selling baz
// moves it up.
func swapToTick(cur realm, targetTick int32) {
	testing.SetRealm(adminRealm)

	currentTick, _ := pl.GetSlot0Tick(poolPath)
	if currentTick == targetTick {
		return
	}

	limit := gnsmath.TickMathGetSqrtRatioAtTick(targetTick).ToString()
	if targetTick < currentTick {
		rt.ExactInSingleSwapRoute(cross(cur), barPath, bazPath, "100000000", routePath, "0", limit, maxTimeout, "")
	} else {
		rt.ExactInSingleSwapRoute(cross(cur), bazPath, barPath, "100000000", reverseRoutePath(), "0", limit, maxTimeout, "")
	}

	testing.SkipHeights(1)
	printTick(ufmt.Sprintf("after swapping toward tick %d", targetTick))
}

func reverseRoutePath() string {
	return bazPath + ":" + barPath + ":" + strconv.Itoa(int(fee100))
}

func printTick(label string) {
	currentTick, _ := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] %s: tick %d\n", label, currentTick)
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Initialize and setup
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] approve tokens for pool and router
//
// [SCENARIO] 2. Create bar:baz:100 pool at tick 0
// [INFO] pool created: tick 0
//
// [SCENARIO] 3. Provide pool depth and stake position [0, 10]
// [INFO] mint wide unstaked position (-100 ~ 100) for swap depth
// [EXPECTED] minted position 1 [-100, 100] liquidity 20051041647
// [INFO] mint and stake position [0, 10]
// [EXPECTED] minted position 2 [0, 10] liquidity 20006000399
// [EXPECTED] staked position 2
// [INFO] after staking [0, 10]: tick 0
//
// [SCENARIO] 4. Swap price below tick 0 (tick 0 crosses down)
// [INFO] after swapping toward tick -1: tick -1
//
// [SCENARIO] 5. Stake wide position [-20, 40] to keep accruing
// [INFO] mint and stake position [-20, 40]
// [EXPECTED] minted position 3 [-20, 40] liquidity 48830502407
// [EXPECTED] staked position 3
// [INFO] after staking [-20, 40]: tick -1
//
// [SCENARIO] 6. Swap price above tick 10 (tick 0 and 10 cross up)
// [INFO] after swapping toward tick 20: tick 20
//
// [SCENARIO] 7. Stake position [0, 5] while above its range
// [INFO] mint and stake position [0, 5]
// [EXPECTED] minted position 4 [0, 5] liquidity 39997000174
// [EXPECTED] current tick 20 is above the range upper bound 5
// [EXPECTED] staked position 4
// [EXPECTED] in range after staking: false
//
// [SCENARIO] 8. Swap price back into the position's range
// [INFO] after swapping toward tick 2: tick 2
//
// [SCENARIO] 9. Collect reward for the out-of-range stake
// [INFO] accumulate rewards while the position is in range
// [INFO] in range: true
// [EXPECTED] CollectReward succeeded, reward received: true
//
// [SCENARIO] 10. Collect again and unstake
// [INFO] skip more blocks and collect again
// [EXPECTED] second CollectReward succeeded
// [EXPECTED] UnStakeToken succeeded
// [EXPECTED] NFT returned to the owner: true
//
// [SCENARIO] 11. Other deposits are unaffected
// [EXPECTED] unrelated deposit collected reward: true
// [INFO] out-of-range staking no longer strands rewards or the position NFT
