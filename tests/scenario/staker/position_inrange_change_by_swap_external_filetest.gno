// position in-range change by swap external incentive

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)
	routerRealm   = std.NewUserRealm(routerAddr)

	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	fee100 uint32 = 100

	max_timeout int64 = 9999999999

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100"
)

func main() {
	println("[SCENARIO] 1. Initialize account and emission")
	initAccountAndEmission()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint bar qux position 01")
	mintPosition01()
	println()

	println("[SCENARIO] 4. Mint bar qux position 02")
	mintPosition02()
	println()

	println("[SCENARIO] 5. Create external incentive")
	createExternalIncentive()
	println()

	println("[SCENARIO] 6. Stake position 01 and 02")
	stakePositions()
	println()

	println("[SCENARIO] 7. Wait for external bar to start")
	waitForExternalBarStart()
	println()

	println("[SCENARIO] 8. Check reward for both in-range positions")
	checkReward01()
	println()

	println("[SCENARIO] 9. Make position 01 out-range by swap")
	makePosition1OutRangeBySwap()
	println()

	println("[SCENARIO] 10. Check reward with position 01 out-range")
	checkReward02()
	println()

	println("[SCENARIO] 11. Make position 01 in-range by swap")
	makePosition1InRangeBySwap()
	println()

	println("[SCENARIO] 12. Check reward with both positions in-range")
	checkReward03()
}

func initAccountAndEmission() {
	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)
}

func createPool() {
	println("[INFO] set pool creation fee to 0")
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100 at tick 0")
	pl.CreatePool(
		cross,
		barPath,
		quxPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(), // 79228162514264337593543950337
	)
}

func mintPosition01() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	qux.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 01 (tick range: -50 ~ 50, requested amount: 50, 50)")
	pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-50),
		int32(50),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)
}

func mintPosition02() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	qux.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 02 (tick range: -1000 ~ 1000, requested amount: 1000, 1000)")
	pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-1000),
		int32(1000),
		"1000",
		"1000",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)
}

func createExternalIncentive() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, stakerAddr, consts.INT64_MAX)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive for bar token")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		barPath,
		9000000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)
}

func stakePositions() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve and stake position 01 and 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))

	testing.SkipHeights(1)
	sr.StakeToken(cross, 1, "")
	sr.StakeToken(cross, 2, "")
}

func waitForExternalBarStart() {
	externalStartTime := int64(1234569600)
	nowTime := time.Now().Unix()
	timeLeft := externalStartTime - nowTime

	blockAvgTime := int64(2)
	blockLeft := timeLeft / blockAvgTime

	ufmt.Printf("[INFO] external bar incentive started at height %d\n", std.ChainHeight()+blockLeft)
	previousHeight := std.ChainHeight()
	testing.SkipHeights(int64(blockLeft)) // skip until external bar starts
	testing.SkipHeights(10)               // skip bit more to see reward calculation
	currentHeight := std.ChainHeight()
	ufmt.Printf("[INFO] skip blocks until external bar starts (height: %d -> %d)\n", previousHeight, currentHeight)

}

func checkReward01() {
	testing.SetRealm(adminRealm)

	println("[INFO] check reward for position 01 (both positions in-range)")
	collectRewardOf1BlockByPositionId(1)
	collectRewardOf1BlockByPositionId(2)
}

func makePosition1OutRangeBySwap() {
	testing.SetRealm(adminRealm)

	println("[INFO] make position 01 out-range by swap")

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	qux.Approve(cross, poolAddr, consts.INT64_MAX)

	// swap to move price outside position 01's range
	testing.SetRealm(routerRealm)
	pl.Swap(
		cross,
		barPath,
		quxPath,
		fee100,
		adminAddr,
		true,         // zeroForOne
		"1000",       // amountSpecified
		"4295128740", // sqrtPriceLimitX96
		adminAddr,
	)

	newPoolTick := pl.PoolGetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] position 01 moved out of range, pool tick: %d\n", newPoolTick)
}

func checkReward02() {
	testing.SetRealm(adminRealm)

	println("[INFO] check reward for position 01 (position 01 out-range)")
	collectRewardOf1BlockByPositionId(1)
	collectRewardOf1BlockByPositionId(2)
}

func makePosition1InRangeBySwap() {
	testing.SetRealm(adminRealm)

	println("[INFO] make position 01 in-range by swap")
	qux.Approve(cross, poolAddr, consts.INT64_MAX)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)

	// swap to move price back inside position 01's range
	testing.SetRealm(routerRealm)
	pl.Swap(
		cross,
		quxPath,
		barPath,
		fee100,
		adminAddr,
		false,  // zeroForOne
		"1000", // amountSpecified
		"1461446703485210103287273052203988822378723970340", // sqrtPriceLimitX96
		adminAddr,
	)

	newPoolTick := pl.PoolGetSlot0Tick(poolPath)

	ufmt.Printf("[EXPECTED] position 01 moved back in range, pool tick: %d\n", newPoolTick)
}

func checkReward03() {
	testing.SetRealm(adminRealm)

	println("[INFO] check reward for position 01 (both positions in-range again)")
	collectRewardOf1BlockByPositionId(1)
	collectRewardOf1BlockByPositionId(2)
}

func collectRewardOf1BlockByPositionId(positionId uint64) {
	testing.SetRealm(adminRealm)
	sr.CollectReward(cross, positionId, false)
	beforeBarBalance := bar.BalanceOf(adminAddr)

	skipHeight := int64(100)
	testing.SkipHeights(skipHeight)
	sr.CollectReward(cross, positionId, false)
	afterBarBalance := bar.BalanceOf(adminAddr)
	diff := afterBarBalance - beforeBarBalance

	ufmt.Printf("[EXPECTED] position %d of 100 block reward (height: %d ~ %d): %d\n", positionId, std.ChainHeight()-skipHeight, std.ChainHeight(), diff)
}

func milliToSec(milliseconds int64) int64 {
	return milliseconds / 1000
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
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create pool
// [INFO] set pool creation fee to 0
// [INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100 at tick 0
//
// [SCENARIO] 3. Mint bar qux position 01
// [INFO] mint in-range position 01 (tick range: -50 ~ 50, requested amount: 50, 50)
//
// [SCENARIO] 4. Mint bar qux position 02
// [INFO] mint in-range position 02 (tick range: -1000 ~ 1000, requested amount: 1000, 1000)
//
// [SCENARIO] 5. Create external incentive
// [INFO] create external incentive for bar token
//
// [SCENARIO] 6. Stake position 01 and 02
// [INFO] approve and stake position 01 and 02
//
// [SCENARIO] 7. Wait for external bar to start
// [INFO] external bar incentive started at height 976
// [INFO] skip blocks until external bar starts (height: 124 -> 986)
//
// [SCENARIO] 8. Check reward for both in-range positions
// [INFO] check reward for position 01 (both positions in-range)
// [EXPECTED] position 1 of 100 block reward (height: 986 ~ 1086): 33957
// [EXPECTED] position 2 of 100 block reward (height: 1086 ~ 1186): 34769
//
// [SCENARIO] 9. Make position 01 out-range by swap
// [INFO] make position 01 out-range by swap
// [EXPECTED] position 01 moved out of range, pool tick: -900
//
// [SCENARIO] 10. Check reward with position 01 out-range
// [INFO] check reward for position 01 (position 01 out-range)
// [EXPECTED] position 1 of 100 block reward (height: 1186 ~ 1286): 0
// [EXPECTED] position 2 of 100 block reward (height: 1286 ~ 1386): 68725
//
// [SCENARIO] 11. Make position 01 in-range by swap
// [INFO] make position 01 in-range by swap
// [EXPECTED] position 01 moved back in range, pool tick: 18
//
// [SCENARIO] 12. Check reward with both positions in-range
// [INFO] check reward for position 01 (both positions in-range again)
// [EXPECTED] position 1 of 100 block reward (height: 1386 ~ 1486): 33957
// [EXPECTED] position 2 of 100 block reward (height: 1486 ~ 1586): 34769
