// a single router swap crossing several staked boundaries at once leaves every
// deposit in the pool collectable, including one staked out of range afterwards

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

// Batched tick crossing is where boundary bases and the raw-reward subtraction
// interact most: swapEndHook feeds every tick the swap passed through to
// processBatchedTickCrosses, which flips each boundary's OutsideAccumulation to
// `global - outside` and writes a single HistoricalTick entry for the last
// crossed boundary.
//
// This scenario drives one router swap across four staked boundaries in each
// direction, then stakes a further position out of range so its boundaries are
// created against that history, and finally collects for every deposit.
//
// The layout gives the swap staked boundaries to cross at -40, -20, 0, 20 and
// 40, with overlapping ranges so that liquidity is present throughout:
//
//	[-60, 60]  wide, staked, in range the whole time
//	[-40, 20]  crossed at both ends
//	[-20, 40]  crossed at both ends
//	[  0, 20]  narrow, both boundaries crossed
//	[  0,  5]  staked last, above its range, tick 5 created there
//
// Every deposit must remain collectable: a boundary that a batched cross has
// flipped, a boundary created after those flips, and the wide position that
// spans all of them.

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
	wideId           uint64 = 2 // [-60, 60]
	lowerSpanId      uint64 = 3 // [-40, 20]
	upperSpanId      uint64 = 4 // [-20, 40]
	narrowId         uint64 = 5 // [0, 20]
	outOfRangeLastId uint64 = 6 // [0, 5], staked above its range at the end
)

var stakedIds = []uint64{wideId, lowerSpanId, upperSpanId, narrowId, outOfRangeLastId}

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool at tick 0")
	createPool(cur)
	println()

	println("[SCENARIO] 3. Stake four overlapping positions")
	stakeOverlappingPositions(cur)
	println()

	println("[SCENARIO] 4. One swap down across boundaries 0, -20 and -40")
	swapToTick(cur, -50)
	println()

	println("[SCENARIO] 5. One swap up across boundaries -40, -20, 0, 20 and 40")
	swapToTick(cur, 50)
	println()

	println("[SCENARIO] 6. Stake [0, 5] above its range against that history")
	stakeOutOfRangeLast(cur)
	println()

	println("[SCENARIO] 7. Swap back so every position is in range")
	swapToTick(cur, 2)
	println()

	println("[SCENARIO] 8. Collect for every staked deposit")
	collectForEveryDeposit(cur)
	println()

	println("[SCENARIO] 9. Unstake every deposit")
	unstakeEveryDeposit(cur)
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

func stakeOverlappingPositions(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] mint wide unstaked position (-200 ~ 200) for swap depth")
	mint(cur, -200, 200, "1000000000", "1000000000")

	println("[INFO] mint and stake [-60, 60], [-40, 20], [-20, 40] and [0, 20]")
	mint(cur, -60, 60, "100000000", "100000000")
	stake(cur, wideId)

	mint(cur, -40, 20, "10000000", "10000000")
	stake(cur, lowerSpanId)

	mint(cur, -20, 40, "10000000", "10000000")
	stake(cur, upperSpanId)

	mint(cur, 0, 20, "10000000", "10000000")
	stake(cur, narrowId)

	testing.SkipHeights(10)
	printTick("after staking")
}

func stakeOutOfRangeLast(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] mint and stake position [0, 5]")
	mint(cur, 0, 5, "10000000", "10000000")

	currentTick, _ := pl.GetSlot0Tick(poolPath)
	if currentTick < 5 {
		panic("position must be staked above its range")
	}
	ufmt.Printf("[EXPECTED] current tick %d is above the range upper bound 5\n", currentTick)

	stake(cur, outOfRangeLastId)
	inRange, _ := pn.IsInRange(outOfRangeLastId)
	ufmt.Printf("[EXPECTED] in range after staking: %t\n", inRange)

	testing.SkipHeights(1)
}

func collectForEveryDeposit(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] accumulate rewards well past any wrap offset")
	testing.SkipHeights(300)

	for _, positionId := range stakedIds {
		before := gns.BalanceOf(adminAddr)
		r := revive(func() {
			sr.CollectReward(cross(cur), positionId)
		})
		after := gns.BalanceOf(adminAddr)

		if r != nil {
			panic(ufmt.Sprintf("[ERROR] CollectReward for %d must not abort, got: %v", positionId, r))
		}
		ufmt.Printf("[EXPECTED] position %d collected, reward received: %t\n", positionId, after > before)
	}
}

func unstakeEveryDeposit(cur realm) {
	testing.SetRealm(adminRealm)

	testing.SkipHeights(20)

	for _, positionId := range stakedIds {
		r := revive(func() {
			sr.UnStakeToken(cross(cur), positionId)
		})
		if r != nil {
			panic(ufmt.Sprintf("[ERROR] UnStakeToken for %d must not abort, got: %v", positionId, r))
		}
		owner := gnft.MustOwnerOf(positionIdFrom(positionId))
		ufmt.Printf("[EXPECTED] position %d unstaked, NFT returned: %t\n", positionId, owner == adminAddr)
	}
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

// swapToTick pushes the pool price to targetTick in a single price-limited swap,
// so one swap crosses every staked boundary in between and swapEndHook processes
// them as one batch. bar is token0, so selling bar moves the tick down and
// selling baz moves it up.
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
// [SCENARIO] 3. Stake four overlapping positions
// [INFO] mint wide unstaked position (-200 ~ 200) for swap depth
// [EXPECTED] minted position 1 [-200, 200] liquidity 100505833206
// [INFO] mint and stake [-60, 60], [-40, 20], [-20, 40] and [0, 20]
// [EXPECTED] minted position 2 [-60, 60] liquidity 33385024970
// [EXPECTED] staked position 2
// [EXPECTED] minted position 3 [-40, 20] liquidity 5005251662
// [EXPECTED] staked position 3
// [EXPECTED] minted position 4 [-20, 40] liquidity 5005251662
// [EXPECTED] staked position 4
// [EXPECTED] minted position 5 [0, 20] liquidity 10005500824
// [EXPECTED] staked position 5
// [INFO] after staking: tick 0
//
// [SCENARIO] 4. One swap down across boundaries 0, -20 and -40
// [INFO] after swapping toward tick -50: tick -50
//
// [SCENARIO] 5. One swap up across boundaries -40, -20, 0, 20 and 40
// [INFO] after swapping toward tick 50: tick 50
//
// [SCENARIO] 6. Stake [0, 5] above its range against that history
// [INFO] mint and stake position [0, 5]
// [EXPECTED] minted position 6 [0, 5] liquidity 39997000174
// [EXPECTED] current tick 50 is above the range upper bound 5
// [EXPECTED] staked position 6
// [EXPECTED] in range after staking: false
//
// [SCENARIO] 7. Swap back so every position is in range
// [INFO] after swapping toward tick 2: tick 2
//
// [SCENARIO] 8. Collect for every staked deposit
// [INFO] accumulate rewards well past any wrap offset
// [EXPECTED] position 2 collected, reward received: true
// [EXPECTED] position 3 collected, reward received: true
// [EXPECTED] position 4 collected, reward received: true
// [EXPECTED] position 5 collected, reward received: true
// [EXPECTED] position 6 collected, reward received: true
//
// [SCENARIO] 9. Unstake every deposit
// [EXPECTED] position 2 unstaked, NFT returned: true
// [EXPECTED] position 3 unstaked, NFT returned: true
// [EXPECTED] position 4 unstaked, NFT returned: true
// [EXPECTED] position 5 unstaked, NFT returned: true
// [EXPECTED] position 6 unstaked, NFT returned: true
