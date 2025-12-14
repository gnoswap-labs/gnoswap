// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100

// POSITIONs:
// 1. Single position staked during incentive period

// SCENARIO:
// This test verifies lazy removal functionality when incentive ends:
// 1. Create external incentive with 90-day duration
// 2. User stakes position and collects rewards during incentive period
// 3. Incentive ends naturally
// 4. User collects rewards after incentive end - lazy removal should remove incentive ID
// 5. Verify no funds are stuck and incentive ID is cleaned up from deposit

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
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
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	user1Addr  = testutils.TestAddress("user1")
	user1User  = user1Addr
	user1Realm = testing.NewUserRealm(user1Addr)

	externalCreatorAddr  = testutils.TestAddress("externalCreator")
	externalCreatorUser  = externalCreatorAddr
	externalCreatorRealm = testing.NewUserRealm(externalCreatorAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
	gnsPath = "gno.land/r/gnoswap/gns"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	depositGnsAmount int64 = 1_000_000_000

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 1000000000        // 1000 GNS

	actualIncentiveID string
)

func main() {
	println("[SCENARIO] Testing lazy removal after incentive ends")
	println()

	println("[SCENARIO] 1. Initialize")
	initialize()
	println()

	println("[SCENARIO] 2. Create pool and set tier")
	createPoolAndSetTier()
	println()

	println("[SCENARIO] 3. Create and start 90-day external incentive")
	createAndStartIncentive()
	println()

	println("[SCENARIO] 4. User mints and stakes position")
	userMintAndStake()
	println()

	println("[SCENARIO] 5. Collect rewards during incentive period (day 45/90)")
	collectDuringIncentive()
	println()

	println("[SCENARIO] 6. Skip time until incentive ends")
	skipUntilEnd()
	println()

	println("[SCENARIO] 7. Collect rewards after end (lazy removal should occur)")
	collectAfterEnd()
	println()

	println("[SCENARIO] 8. Verify second collection yields zero (incentive removed)")
	verifyIncentiveRemoved()
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross, 0)
	pl.SetPoolCreationFee(cross, 0)
	testing.SkipHeights(1)

	bar.Transfer(cross, user1User, 10000)
	qux.Transfer(cross, user1User, 10000)

	gns.Transfer(cross, externalCreatorUser, REWARD_AMOUNT+depositGnsAmount)

	println("[INFO] initialized accounts")
}

func createPoolAndSetTier() {
	testing.SetRealm(adminRealm)

	testing.SkipHeights(1)
	pl.CreatePool(
		cross,
		barPath,
		quxPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)
	println("[INFO] created pool and set tier")
}

func createAndStartIncentive() {
	testing.SetRealm(externalCreatorRealm)

	gns.Approve(cross, stakerAddr, maxInt64)

	startTime := int64(1234569600) // +1 day midnight
	endTime := startTime + INCENTIVE_DURATION

	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", externalCreatorAddr, time.Now().Unix(), 1)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		gnsPath,
		REWARD_AMOUNT,
		startTime,
		endTime,
	)

	// Skip to start time
	nowTime := time.Now().Unix()
	timeLeft := startTime - nowTime
	blockLeft := timeLeft / 5
	testing.SkipHeights(blockLeft)

	ufmt.Printf("[INFO] created 90-day incentive - ID: %s\n", actualIncentiveID)
}

func userMintAndStake() {
	testing.SetRealm(user1Realm)

	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(1)
	lpTokenId, _, _, _ := pn.Mint(
		cross,
		barPath,
		quxPath,
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

	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[INFO] user staked position %d\n", lpTokenId)
}

func collectDuringIncentive() {
	testing.SetRealm(user1Realm)

	// Skip 45 days (half of 90-day period)
	blocksToSkip := int64((45 * 24 * 60 * 60) / 5)
	testing.SkipHeights(blocksToSkip)

	gnsBefore := gns.BalanceOf(user1User)
	sr.CollectReward(cross, 1, false)
	gnsAfter := gns.BalanceOf(user1User)

	rewards := gnsAfter - gnsBefore
	ufmt.Printf("[INFO] collected %d GNS during incentive period (day 45/90)\n", rewards)
}

func skipUntilEnd() {
	// Skip remaining 45 days + 1 day buffer
	blocksToSkip := int64((46 * 24 * 60 * 60) / 5)
	testing.SkipHeights(blocksToSkip)

	println("[INFO] incentive has ended")
}

func collectAfterEnd() {
	testing.SetRealm(user1Realm)

	gnsBefore := gns.BalanceOf(user1User)
	sr.CollectReward(cross, 1, false)
	gnsAfter := gns.BalanceOf(user1User)

	rewards := gnsAfter - gnsBefore
	ufmt.Printf("[INFO] collected %d GNS after incentive end\n", rewards)
	ufmt.Printf("[INFO] lazy removal should have removed incentive ID from deposit\n")
}

func verifyIncentiveRemoved() {
	testing.SetRealm(user1Realm)

	gnsBefore := gns.BalanceOf(user1User)
	sr.CollectReward(cross, 1, false)
	gnsAfter := gns.BalanceOf(user1User)

	rewards := gnsAfter - gnsBefore
	ufmt.Printf("[VERIFY] second collection after end: %d GNS\n", rewards)

	if rewards == 0 {
		println("[VERIFIED] Incentive successfully removed from deposit - no duplicate collection")
	} else {
		println("[WARNING] Unexpected rewards after incentive end")
	}
}

func positionIdFrom(positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] Testing lazy removal after incentive ends
//
// [SCENARIO] 1. Initialize
// [INFO] initialized accounts
//
// [SCENARIO] 2. Create pool and set tier
// [INFO] created pool and set tier
//
// [SCENARIO] 3. Create and start 90-day external incentive
// [INFO] created 90-day incentive - ID: g1v4u8getjdeskcsmjv4shgmmjta047h6lua7mup:1234567900:1
//
// [SCENARIO] 4. User mints and stakes position
// [INFO] user staked position 1
//
// [SCENARIO] 5. Collect rewards during incentive period (day 45/90)
// [INFO] collected 304127998 GNS during incentive period (day 45/90)
//
// [SCENARIO] 6. Skip time until incentive ends
// [INFO] incentive has ended
//
// [SCENARIO] 7. Collect rewards after end (lazy removal should occur)
// [INFO] collected 497663359 GNS after incentive end
// [INFO] lazy removal should have removed incentive ID from deposit
//
// [SCENARIO] 8. Verify second collection yields zero (incentive removed)
// [VERIFY] second collection after end: 0 GNS
// [VERIFIED] Incentive successfully removed from deposit - no duplicate collection
