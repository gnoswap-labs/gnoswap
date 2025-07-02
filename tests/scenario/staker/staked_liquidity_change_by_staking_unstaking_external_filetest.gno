// staked liquidity change by staking/unstaking external incentive scenario

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

	println("[SCENARIO] 6. Stake position 01")
	stakePosition(1)
	println()

	println("[SCENARIO] 7. Stake position 02")
	stakePosition(2)
	println()

	println("[SCENARIO] 8. Wait for external bar to start and collect reward")
	waitForExternalBarStart()
	println()

	println("[SCENARIO] 9. Collect reward for position 01")
	collectReward(1)
	println()

	println("[SCENARIO] 10. Collect reward for position 02")
	collectReward(2)
	println()

	println("[SCENARIO] 11. Skip block height 1")
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 12. Unstake position 01")
	unstakePosition(1)
	println()

	println("[SCENARIO] 13. Unstake position 02")
	unstakePosition(2)
}

func initAccountAndEmission() {
	println("[INFO] set unstaking fee to 0")
	testing.SetRealm(adminRealm)
	sr.SetUnStakingFeeByAdmin(cross, 0)

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

	println("[INFO] mint in-range position 02 (tick range: -50 ~ 50, requested amount: 50, 50)")
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

func createExternalIncentive() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, stakerAddr, consts.INT64_MAX)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive for bar token (external bar starts at 90 days, 9000000000 BAR tokens)")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		barPath,
		9000000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)
}

func stakePosition(positionId uint64) {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position", positionId)
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross, positionId, "")
}

func waitForExternalBarStart() {
	testing.SetRealm(adminRealm)

	externalStartTime := int64(1234569600)
	nowTime := time.Now().Unix()

	timeLeft := externalStartTime - nowTime

	blockAvgTime := milliToSec(consts.BLOCK_GENERATION_INTERVAL)
	blockLeft := timeLeft / blockAvgTime

	ufmt.Printf("[INFO] skip blocks until external bar starts(skipping %d blocks)\n", blockLeft)
	testing.SkipHeights(int64(blockLeft)) // skip until external bar starts

	ufmt.Println("[INFO] current block height", std.ChainHeight())

	// check reward for position 01 (in-range)
	testing.SetRealm(adminRealm)
	beforeBar := bar.BalanceOf(adminUser)

	sr.CollectReward(cross, 1, false)
	afterBar := bar.BalanceOf(adminUser)

	diff := afterBar - beforeBar
	ufmt.Printf("[EXPECTED] position 01 received external bar reward: %d\n", diff)
}

func collectReward(positionId uint64) {
	testing.SetRealm(adminRealm)

	oldBar := bar.BalanceOf(adminUser)
	ufmt.Printf("[INFO] bar balance before collect: %d\n", oldBar)

	println("[INFO] skip height 1 and collect reward")
	testing.SkipHeights(1)
	sr.CollectReward(cross, 1, false)

	newBar := bar.BalanceOf(adminUser)
	diff := newBar - oldBar

	ufmt.Printf("[INFO] bar balance after collect: %d\n", newBar)

	ufmt.Printf("[EXPECTED] position %d reward collected: %d\n", positionId, diff)
}

func unstakePosition(positionId uint64) {
	testing.SetRealm(adminRealm)

	oldBar := bar.BalanceOf(adminUser)
	ufmt.Printf("[INFO] bar balance before collect after unstake: %d\n", oldBar)

	ufmt.Printf("[INFO] unstake position %d\n", positionId)
	sr.UnStakeToken(cross, positionId, false)

	newBar := bar.BalanceOf(adminUser)
	diff := newBar - oldBar

	ufmt.Printf("[EXPECTED] position %d reward collected after unstake: %d\n", positionId, diff)
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
// [INFO] set unstaking fee to 0
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
// [INFO] mint in-range position 02 (tick range: -50 ~ 50, requested amount: 50, 50)
//
// [SCENARIO] 5. Create external incentive
// [INFO] create external incentive for bar token (external bar starts at 90 days, 9000000000 BAR tokens)
//
// [SCENARIO] 6. Stake position 01
// [INFO] stake position 1
//
// [SCENARIO] 7. Stake position 02
// [INFO] stake position 2
//
// [SCENARIO] 8. Wait for external bar to start and collect reward
// [INFO] skip blocks until external bar starts(skipping 855 blocks)
// [INFO] current block height 978
// [EXPECTED] position 01 received external bar reward: 0
//
// [SCENARIO] 9. Collect reward for position 01
// [INFO] bar balance before collect: 99990999999900
// [INFO] skip height 1 and collect reward
// [INFO] bar balance after collect: 99991000000246
// [EXPECTED] position 1 reward collected: 346
//
// [SCENARIO] 10. Collect reward for position 02
// [INFO] bar balance before collect: 99991000000246
// [INFO] skip height 1 and collect reward
// [INFO] bar balance after collect: 99991000000593
// [EXPECTED] position 2 reward collected: 347
//
// [SCENARIO] 11. Skip block height 1
//
// [SCENARIO] 12. Unstake position 01
// [INFO] bar balance before collect after unstake: 99991000000593
// [INFO] unstake position 1
// [EXPECTED] position 1 reward collected after unstake: 346
//
// [SCENARIO] 13. Unstake position 02
// [INFO] bar balance before collect after unstake: 99991000000939
// [INFO] unstake position 2
// [EXPECTED] position 2 reward collected after unstake: 1041
