// PKGPATH: gno.land/r/gnoswap/v1/main

// Collecting an unstaked position later must pay exactly what collecting it right away would.
//
// Two identical positions are staked together, have their boundary ticks crossed by swaps, and
// are unstaked in the same block - which prunes those ticks, since nothing else is staked at
// them. The first is collected right away. The second is collected hundreds of blocks later,
// after a new position re-creates the same ticks with a fresh accumulation history and another
// pool joins tier 1, changing the internal reward rate from that point on. Both must pay the
// same: the checkpoint pins the tick history and the tier context the position exited under.

package main

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
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	bazPath = "gno.land/r/onbloc/baz.BAZ"

	fee100 uint32 = 100

	poolPath  = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"
	routePath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	exitTimeOfFirst int64
)

// Position ids in mint order.
const (
	depthId     uint64 = 1 // wide, unstaked - gives the pool depth to swap against
	wideId      uint64 = 2 // [-100, 100], staked throughout
	firstId     uint64 = 3 // [-20, 20]
	secondId    uint64 = 4 // [-20, 20], identical to firstId
	recreatedId uint64 = 5 // [-20, 20], staked after both were unstaked
)

func main(cur realm) {
	println("[SCENARIO] 1. Stake two identical positions and cross their boundaries")
	setup(cur)

	println()
	println("[SCENARIO] 2. Unstake both, collecting only the first, in the same block")
	immediate := unstakeBoth(cur)
	ufmt.Printf("[EXPECTED] the immediate collect paid a reward: %t\n", immediate > 0)

	println()
	println("[SCENARIO] 3. Re-create the pruned ticks and change the tier layout")
	movePoolOn(cur)

	println()
	println("[SCENARIO] 4. Collect the second position long after it left the pool")
	deferred := collectAndMeasure(cur, secondId)
	ufmt.Printf("[EXPECTED] the deferred collect matches the immediate one: %t\n", deferred == immediate)
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)
	bar.Approve(cross(cur), routerAddr, maxInt64)
	baz.Approve(cross(cur), routerAddr, maxInt64)

	pl.CreatePool(cross(cur), barPath, bazPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	mint(cur, -200, 200, "1000000000")

	mint(cur, -100, 100, "100000000")
	stake(cur, wideId)

	mint(cur, -20, 20, "10000000")
	stake(cur, firstId)

	mint(cur, -20, 20, "10000000")
	stake(cur, secondId)

	testing.SkipHeights(100)

	// Cross the shared boundary at -20 in both directions, so its outside accumulation moves
	// inside the window that is about to be settled.
	swapToTick(cur, -50)
	testing.SkipHeights(100)
	swapToTick(cur, 0)
	testing.SkipHeights(100)
}

// unstakeBoth unstakes the pair in one block and collects only the first, while the second
// still holds the shared boundary ticks alive. That collect runs against live pool state and
// is the amount the deferred one has to reproduce; unstaking the second then prunes the ticks.
func unstakeBoth(cur realm) int64 {
	testing.SetRealm(adminRealm)

	sr.UnStakeToken(cross(cur), firstId)
	immediate := collectAndMeasure(cur, firstId)

	sr.UnStakeToken(cross(cur), secondId)
	secondExitTime, _ := sr.GetUnstakedPositionExitTime(secondId)

	ufmt.Printf("[EXPECTED] second position uncollected: %t\n", sr.HasUnstakedPosition(secondId))
	ufmt.Printf("[EXPECTED] both exit at the same time: %t\n", secondExitTime == exitTimeOfFirst)

	return immediate
}

// movePoolOn moves the pool state that a deferred settlement must not read: it re-creates the
// pruned boundary ticks with a fresh accumulation history, and adds another pool to tier 1 so
// the internal reward rate differs from the one in force during the settled window.
func movePoolOn(cur realm) {
	testing.SetRealm(adminRealm)

	testing.SkipHeights(200)
	mint(cur, -20, 20, "10000000")
	stake(cur, recreatedId)

	// Perturb the internal emission schedule: a second tier-1 pool changes the tier ratio
	// and per-pool reward rate from here on.
	pl.CreatePool(cross(cur), barPath, bazPath, uint32(3000), gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), barPath+":"+bazPath+":3000", 1)

	testing.SkipHeights(300)

	ufmt.Printf("[EXPECTED] second position still uncollected: %t\n", sr.HasUnstakedPosition(secondId))
}

// collectAndMeasure collects one unstaked position and returns what it paid.
func collectAndMeasure(cur realm, positionId uint64) int64 {
	testing.SetRealm(adminRealm)

	if positionId == firstId {
		exitTimeOfFirst, _ = sr.GetUnstakedPositionExitTime(firstId)
	}

	before := gns.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), positionId)

	ufmt.Printf("[EXPECTED] position %d collected: %t\n", positionId, !sr.HasUnstakedPosition(positionId))

	return gns.BalanceOf(adminUser) - before
}

func mint(cur realm, tickLower, tickUpper int32, amount string) {
	pn.Mint(
		cross(cur),
		barPath,
		bazPath,
		fee100,
		tickLower,
		tickUpper,
		amount,
		amount,
		"0",
		"0",
		maxTimeout,
		adminUser,
		"",
	)
}

func stake(cur realm, positionId uint64) {
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross(cur), positionId, "")
}

func swapToTick(cur realm, targetTick int32) {
	testing.SetRealm(adminRealm)

	currentTick, _ := pl.GetSlot0Tick(poolPath)
	if currentTick == targetTick {
		return
	}

	limit := gnsmath.TickMathGetSqrtRatioAtTick(targetTick).ToString()
	if targetTick < currentTick {
		rt.ExactInSingleSwapRoute(cross(cur), barPath, bazPath, "1000000000", routePath, "0", limit, maxTimeout, "")
	} else {
		rt.ExactInSingleSwapRoute(cross(cur), bazPath, barPath, "1000000000", reverseRoutePath(), "0", limit, maxTimeout, "")
	}

	testing.SkipHeights(1)
}

func reverseRoutePath() string {
	return bazPath + ":" + barPath + ":" + strconv.Itoa(int(fee100))
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Stake two identical positions and cross their boundaries
//
// [SCENARIO] 2. Unstake both, collecting only the first, in the same block
// [EXPECTED] position 3 collected: true
// [EXPECTED] second position uncollected: true
// [EXPECTED] both exit at the same time: true
// [EXPECTED] the immediate collect paid a reward: true
//
// [SCENARIO] 3. Re-create the pruned ticks and change the tier layout
// [EXPECTED] second position still uncollected: true
//
// [SCENARIO] 4. Collect the second position long after it left the pool
// [EXPECTED] position 4 collected: true
// [EXPECTED] the deferred collect matches the immediate one: true
