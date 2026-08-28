// staking below its range against a crossed upper boundary produces a wrapped
// raw reward base, which the modular subtraction has to tolerate

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

// Scenario for the wrapped raw-reward base that boundary-tick seeding does not
// - and must not - remove.
//
// Seeding follows Uniswap V3's Tick.update rule: a boundary tick is seeded with
// the global accumulation only when it is first initialized AND sits at or below
// the current tick ("by convention, we assume that all growth before a tick was
// initialized happened _below_ the tick"). A tick initialized above the price
// keeps the zero base.
//
// That convention makes `below(tick) == global` hold at creation time for every
// tick, but it does not order two ticks created at different times. A position
// whose LOWER boundary is created later than its UPPER boundary therefore starts
// from below(upper) - below(lower) < 0, which wraps modulo 2^256. Uniswap V3 has
// exactly the same property and subtracts unchecked
// (Position.update: `feeGrowthInside0X128 - _self.feeGrowthInside0LastX128`,
// pragma <0.8.0), so the wrapped difference is still the true accumulation.
//
// This scenario reaches that state through the public entry points only -
// pool.CreatePool, position.Mint, gnft.Approve, staker.StakeToken,
// router.ExactInSingleSwapRoute, staker.CollectReward, staker.UnStakeToken:
//
//	tick 0 becomes a staked boundary, then is crossed downward -> out(0) > 0
//	the position stakes [-5, 0) while the price sits far below the range
//	tick -5 is created above the price, so it keeps the zero base
//	-> raw = out(-5) - out(0) = -out(0), wrapped
//	the price returns into the range and the position accrues past the offset
//
// With the borrow treated as fatal, the collect aborted with
// GNOSWAP-STAKER-019 from here on and the position NFT could never be
// withdrawn. The golden output asserts that both now succeed.

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
	depthPositionId uint64 = 1 // wide, unstaked - gives the pool depth to swap against
	stakedWideId    uint64 = 2 // [-50, 50] - keeps the accumulator moving throughout
	upperBoundaryId uint64 = 3 // [-10, 0]  - makes tick 0 a staked boundary
	belowRangeId    uint64 = 4 // [-5, 0]   - staked far below its range, tick -5 created there
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool at tick 0")
	createPool(cur)
	println()

	println("[SCENARIO] 3. Provide depth and stake [-50, 50] and [-10, 0]")
	provideDepthAndStake(cur)
	println()

	println("[SCENARIO] 4. Swap price far below tick 0 (tick 0 crosses down)")
	swapToTick(cur, -30)
	println()

	println("[SCENARIO] 5. Stake [-5, 0] while far below its range")
	stakeBelowRange(cur)
	println()

	println("[SCENARIO] 6. Swap price back into the position's range")
	swapToTick(cur, -3)
	println()

	println("[SCENARIO] 7. Collect reward for the below-range stake")
	collectReward(cur)
	println()

	println("[SCENARIO] 8. Collect again and unstake")
	collectAgainAndUnstake(cur)
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

func provideDepthAndStake(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] mint wide unstaked position (-100 ~ 100) for swap depth")
	mint(cur, -100, 100, "100000000", "100000000")

	println("[INFO] mint and stake wide position [-50, 50]")
	mint(cur, -50, 50, "100000000", "100000000")
	stake(cur, stakedWideId)

	// [-10, 0] is out of range at tick 0 (the upper bound is exclusive), but it
	// still registers tick 0 as a staked boundary, which is the whole point.
	println("[INFO] mint and stake position [-10, 0] to register tick 0")
	mint(cur, -10, 0, "10000", "10000")
	stake(cur, upperBoundaryId)

	// Kept short: the accumulation up to tick 0's crossing is the offset the
	// below-range position's wrapped base has to climb back over.
	testing.SkipHeights(2)
	printTick("after staking")
}

func stakeBelowRange(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] mint and stake position [-5, 0]")
	mint(cur, -5, 0, "10000", "10000")

	currentTick, _ := pl.GetSlot0Tick(poolPath)
	if currentTick >= -5 {
		panic("position must be staked below its range")
	}
	ufmt.Printf("[EXPECTED] current tick %d is below the range lower bound -5\n", currentTick)

	stake(cur, belowRangeId)
	inRange, _ := pn.IsInRange(belowRangeId)
	ufmt.Printf("[EXPECTED] in range after staking: %t\n", inRange)

	testing.SkipHeights(1)
}

func collectReward(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] accumulate rewards well past the wrap offset")
	testing.SkipHeights(300)

	inRange, _ := pn.IsInRange(belowRangeId)
	ufmt.Printf("[INFO] in range: %t\n", inRange)

	before := gns.BalanceOf(adminAddr)
	r := revive(func() {
		sr.CollectReward(cross(cur), belowRangeId)
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
		sr.CollectReward(cross(cur), belowRangeId)
	})
	if retry != nil {
		panic(ufmt.Sprintf("[ERROR] the second CollectReward must not abort, got: %v", retry))
	}
	println("[EXPECTED] second CollectReward succeeded")

	unstake := revive(func() {
		sr.UnStakeToken(cross(cur), belowRangeId)
	})
	if unstake != nil {
		panic(ufmt.Sprintf("[ERROR] UnStakeToken must not abort, got: %v", unstake))
	}
	println("[EXPECTED] UnStakeToken succeeded")

	owner := gnft.MustOwnerOf(positionIdFrom(belowRangeId))
	ufmt.Printf("[EXPECTED] NFT returned to the owner: %t\n", owner == adminAddr)
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
// [SCENARIO] 3. Provide depth and stake [-50, 50] and [-10, 0]
// [INFO] mint wide unstaked position (-100 ~ 100) for swap depth
// [EXPECTED] minted position 1 [-100, 100] liquidity 20051041647
// [INFO] mint and stake wide position [-50, 50]
// [EXPECTED] minted position 2 [-50, 50] liquidity 40052020798
// [EXPECTED] staked position 2
// [INFO] mint and stake position [-10, 0] to register tick 0
// [EXPECTED] minted position 3 [-10, 0] liquidity 20006000
// [EXPECTED] staked position 3
// [INFO] after staking: tick 0
//
// [SCENARIO] 4. Swap price far below tick 0 (tick 0 crosses down)
// [INFO] after swapping toward tick -30: tick -30
//
// [SCENARIO] 5. Stake [-5, 0] while far below its range
// [INFO] mint and stake position [-5, 0]
// [EXPECTED] minted position 4 [-5, 0] liquidity 39997000
// [EXPECTED] current tick -30 is below the range lower bound -5
// [EXPECTED] staked position 4
// [EXPECTED] in range after staking: false
//
// [SCENARIO] 6. Swap price back into the position's range
// [INFO] after swapping toward tick -3: tick -3
//
// [SCENARIO] 7. Collect reward for the below-range stake
// [INFO] accumulate rewards well past the wrap offset
// [INFO] in range: true
// [EXPECTED] CollectReward succeeded, reward received: true
//
// [SCENARIO] 8. Collect again and unstake
// [INFO] skip more blocks and collect again
// [EXPECTED] second CollectReward succeeded
// [EXPECTED] UnStakeToken succeeded
// [EXPECTED] NFT returned to the owner: true
