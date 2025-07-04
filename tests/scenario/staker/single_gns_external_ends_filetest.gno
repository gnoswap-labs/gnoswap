// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100

// POSITIONs:
// 1. in-range

// REWARDs:
// - external gns 90 days ( bar:qux:100 )

package main

import (
	"std"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
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

	// g1v4u8getjdeskcsmjv4shgmmjta047h6lua7mup
	externalCreatorAddr  = testutils.TestAddress("externalCreator")
	externalCreatorUser  = externalCreatorAddr
	externalCreatorRealm = std.NewUserRealm(externalCreatorAddr)

	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	poolAddr, _   = access.GetAddress(access.ROLE_POOL)

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	gnsPath = "gno.land/r/gnoswap/v1/gns"

	fee100 uint32 = 100

	max_timeout int64 = 9999999999

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60
)

func main() {
	println("[SCENARIO] 1. Initialize account and settings")
	initAccountAndSettings()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint bar qux position 01")
	mintBarQuxPosition01()
	println()

	println("[SCENARIO] 4. Mint bar qux position 02")
	mintBarQuxPosition02()
	println()

	println("[SCENARIO] 5. Create external incentive GNS")
	createExternalIncentiveGns()
	println()

	println("[SCENARIO] 6. Start external incentive")
	startExternalIncentive()
	println()

	println("[SCENARIO] 7. Stake position 01")
	stakePosition01()
	println()

	println("[SCENARIO] 8. Stake position 02")
	stakePosition02()
	println()

	println("[SCENARIO] 9. Collect rewards for both positions")
	collectRewardsForBothPositions()
	println()

	println("[SCENARIO] 10. End external GNS incentive")
	endExternalGnsIncentive()
	println()

	println("[SCENARIO] 11. Collect rewards after external incentive ends")
	collectRewardsAfterExternalEnds()
}

func initAccountAndSettings() {
	println("[INFO] set unstaking fee to 0")
	testing.SetRealm(adminRealm)
	sr.SetUnStakingFeeByAdmin(cross, 0)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100 at tick 0")
	testing.SkipHeights(1)
	pl.CreatePool(
		cross,
		barPath,
		quxPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(), // 79228162514264337593543950337
	)
}

func mintBarQuxPosition01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position 01")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	qux.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 01 (tick range: -50 ~ 50, requested amount: 50, 50)")
	testing.SkipHeights(1)
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

func mintBarQuxPosition02() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position 02")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	qux.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 02 (tick range: -50 ~ 50, requested amount: 50, 50)")
	testing.SkipHeights(1)
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

func createExternalIncentiveGns() {
	println("[INFO] transfer GNS to external creator")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, externalCreatorUser, 9000000000)
	gns.Transfer(cross, externalCreatorUser, depositGnsAmount)

	println("[INFO] approve GNS for external incentive creation")
	testing.SetRealm(externalCreatorRealm) // creator
	gns.Approve(cross, stakerAddr, consts.INT64_MAX)

	println("[INFO] create external incentive for 90 days")
	testing.SkipHeights(1)
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		gnsPath,
		9000000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)
}

func startExternalIncentive() {
	externalStartTime := int64(1234569600)
	nowTime := time.Now().Unix()
	timeLeft := externalStartTime - nowTime

	blockAvgTime := milliToSec(consts.BLOCK_GENERATION_INTERVAL)
	blockLeft := timeLeft / blockAvgTime

	println("[INFO] skip blocks until external incentive starts")
	testing.SkipHeights(int64(blockLeft) + std.ChainHeight()) // skip until external bar starts
	ufmt.Printf("[INFO] external incentive started at timestamp: %d\n", externalStartTime)
}

func stakePosition01() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position 01")
	testing.SkipHeights(1)
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")
}

func stakePosition02() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position 02")
	testing.SkipHeights(1)
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")
}

func collectRewardsForBothPositions() {
	testing.SetRealm(adminRealm)

	println("[INFO] collect rewards for both positions")
	testing.SkipHeights(1)
	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)
	ufmt.Println("[INFO] rewards collected for both positions during external incentive period")
}

func endExternalGnsIncentive() {
	externalEndTime := (1234569600 + TIMESTAMP_90DAYS)
	nowTime := time.Now().Unix()
	timeLeft := externalEndTime - nowTime

	blockLeft := timeLeft

	println("[INFO] skip blocks until external incentive ends")
	testing.SkipHeights(int64(blockLeft)) // skip until external gns ends

	println("[INFO] end external incentive and collect remaining GNS")
	testing.SetRealm(externalCreatorRealm)
	gnsBalanceBeforeEnds := gns.BalanceOf(externalCreatorUser)
	sr.EndExternalIncentive(
		cross,
		externalCreatorAddr,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		gnsPath,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
		126,
	)
	gnsBalanceAfterEnds := gns.BalanceOf(externalCreatorUser)

	ufmt.Printf("[INFO] GNS balance before ending: %d\n", gnsBalanceBeforeEnds)
	ufmt.Printf("[INFO] GNS balance after ending: %d\n", gnsBalanceAfterEnds)

	ufmt.Println("[EXPECTED] external creator should receive deposit amount minus penalty")
}

func collectRewardsAfterExternalEnds() {
	testing.SetRealm(adminRealm)

	println("[INFO] collect rewards after external incentive ends")
	before := gns.BalanceOf(adminUser)
	testing.SkipHeights(1)

	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)
	after := gns.BalanceOf(adminUser)
	diff := after - before

	ufmt.Printf("[INFO] GNS balance before collection: %d\n", before)
	ufmt.Printf("[INFO] GNS balance after collection: %d\n", after)
	ufmt.Printf("[INFO] total reward collected: %d\n", diff)

	if diff == 0 {
		panic("reward can not be zero")
	}

	ufmt.Println("[EXPECTED] positions should still receive rewards after external incentive ends")
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

func milliToSec(ms int64) int64 {
	return ms / consts.MILLISECONDS_PER_SECOND
}

// Output:
// [SCENARIO] 1. Initialize account and settings
// [INFO] set unstaking fee to 0
//
// [SCENARIO] 2. Create pool
// [INFO] set pool creation fee to 0
// [INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100 at tick 0
//
// [SCENARIO] 3. Mint bar qux position 01
// [INFO] approve tokens for position 01
// [INFO] mint in-range position 01 (tick range: -50 ~ 50, requested amount: 50, 50)
//
// [SCENARIO] 4. Mint bar qux position 02
// [INFO] approve tokens for position 02
// [INFO] mint in-range position 02 (tick range: -50 ~ 50, requested amount: 50, 50)
//
// [SCENARIO] 5. Create external incentive GNS
// [INFO] transfer GNS to external creator
// [INFO] approve GNS for external incentive creation
// [INFO] create external incentive for 90 days
//
// [SCENARIO] 6. Start external incentive
// [INFO] skip blocks until external incentive starts
// [INFO] external incentive started at timestamp: 1234569600
//
// [SCENARIO] 7. Stake position 01
// [INFO] stake position 01
//
// [SCENARIO] 8. Stake position 02
// [INFO] stake position 02
//
// [SCENARIO] 9. Collect rewards for both positions
// [INFO] collect rewards for both positions
// [INFO] rewards collected for both positions during external incentive period
//
// [SCENARIO] 10. End external GNS incentive
// [INFO] skip blocks until external incentive ends
// [INFO] end external incentive and collect remaining GNS
// [INFO] GNS balance before ending: 0
// [INFO] GNS balance after ending: 1000296192
// [EXPECTED] external creator should receive deposit amount minus penalty
//
// [SCENARIO] 11. Collect rewards after external incentive ends
// [INFO] collect rewards after external incentive ends
// [INFO] GNS balance before collection: 99990000001387
// [INFO] GNS balance after collection: 99997247150993
// [INFO] total reward collected: 7247149606
// [EXPECTED] positions should still receive rewards after external incentive ends
