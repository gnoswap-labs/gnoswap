// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100
//
// POSITIONs:
// 1. Single position staked through incentive end (never unstaked)
//
// SCENARIO:
// Verifies that a finished external incentive is cleaned up via CollectReward
// even when the staked position is never unstaked:
// 1. Create 90-day external incentive and stake a position
// 2. Wait until after the incentive ends (no unstake)
// 3. Creator calls EndExternalIncentive to refund deposit/leftover rewards
// 4. User collects once after end (removes incentive from deposit)
// 5. Second collect returns zero, proving the ended incentive no longer blocks cleanup

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

	userAddr  = testutils.TestAddress("user1")
	userUser  = userAddr
	userRealm = testing.NewUserRealm(userAddr)

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
	REWARD_AMOUNT      int64 = 1_500_000_000     // 1500 GNS

	actualIncentiveID string
)

func main() {
	println("[SCENARIO] External incentive ends without unstake (cleanup on collect)")
	println()

	println("[SCENARIO] 1. Initialize")
	initialize()
	println()

	println("[SCENARIO] 2. Create pool and set tier")
	createPoolAndSetTier()
	println()

	println("[SCENARIO] 3. Create external incentive and start")
	createAndStartIncentive()
	println()

	println("[SCENARIO] 4. User mints and stakes position")
	userMintAndStake()
	println()

	println("[SCENARIO] 5. Skip until after incentive end (no unstake)")
	skipUntilAfterEnd()
	println()

	println("[SCENARIO] 6. Creator ends incentive (refund path)")
	endExternalIncentive()
	println()

	println("[SCENARIO] 7. User collects after end (should clean up incentive)")
	collectAfterEnd()
	println()

	println("[SCENARIO] 8. Second collect returns zero (incentive removed)")
	verifyNoFurtherRewards()
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross, 0)
	pl.SetPoolCreationFee(cross, 0)
	testing.SkipHeights(1)

	bar.Transfer(cross, userUser, 10000)
	qux.Transfer(cross, userUser, 10000)

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

	createTimestamp := time.Now().Unix()

	// Start at the next UTC midnight to satisfy start-time validation
	startTime := ((createTimestamp / 86400) + 1) * 86400
	endTime := startTime + INCENTIVE_DURATION

	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", externalCreatorAddr, createTimestamp, 1)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		gnsPath,
		REWARD_AMOUNT,
		startTime,
		endTime,
	)

	// Move chain time to incentive start
	nowTime := time.Now().Unix()
	timeLeft := startTime - nowTime
	if timeLeft > 0 {
		blockLeft := timeLeft / 5
		testing.SkipHeights(blockLeft)
	}

	ufmt.Printf("[INFO] created external incentive %s\n", actualIncentiveID)
}

func userMintAndStake() {
	testing.SetRealm(userRealm)

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
		userAddr,
		userAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[INFO] user staked position %d\n", lpTokenId)
}

func skipUntilAfterEnd() {
	// Jump past full 90-day period plus 1-day buffer
	blocksToSkip := int64(((INCENTIVE_DURATION + 24*60*60) / 5))
	testing.SkipHeights(blocksToSkip)
	println("[INFO] skipped to after incentive end without unstaking")
}

func endExternalIncentive() {
	testing.SetRealm(externalCreatorRealm)

	sr.EndExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		actualIncentiveID,
	)

	println("[INFO] external incentive ended via refund path")
}

func collectAfterEnd() {
	testing.SetRealm(userRealm)

	gnsBefore := gns.BalanceOf(userUser)
	sr.CollectReward(cross, 1, false)
	gnsAfter := gns.BalanceOf(userUser)

	rewards := gnsAfter - gnsBefore
	ufmt.Printf("[INFO] collected %d GNS after incentive end (incentive should be removed)\n", rewards)
}

func verifyNoFurtherRewards() {
	testing.SetRealm(userRealm)

	gnsBefore := gns.BalanceOf(userUser)
	sr.CollectReward(cross, 1, false)
	gnsAfter := gns.BalanceOf(userUser)

	rewards := gnsAfter - gnsBefore
	ufmt.Printf("[VERIFY] second collect after end: %d GNS\n", rewards)

	if rewards == 0 {
		println("[VERIFIED] Ended external incentive no longer blocks cleanup or yields rewards")
	} else {
		println("[WARNING] Unexpected rewards after incentive end")
	}
}

func positionIdFrom(positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] External incentive ends without unstake (cleanup on collect)
//
// [SCENARIO] 1. Initialize
// [INFO] initialized accounts
//
// [SCENARIO] 2. Create pool and set tier
// [INFO] created pool and set tier
//
// [SCENARIO] 3. Create external incentive and start
// [INFO] created external incentive g1v4u8getjdeskcsmjv4shgmmjta047h6lua7mup:1234567900:1
//
// [SCENARIO] 4. User mints and stakes position
// [INFO] user staked position 1
//
// [SCENARIO] 5. Skip until after incentive end (no unstake)
// [INFO] skipped to after incentive end without unstaking
//
// [SCENARIO] 6. Creator ends incentive (refund path)
// [INFO] external incentive ended via refund path
//
// [SCENARIO] 7. User collects after end (should clean up incentive)
// [INFO] collected 1202687037 GNS after incentive end (incentive should be removed)
//
// [SCENARIO] 8. Second collect returns zero (incentive removed)
// [VERIFY] second collect after end: 0 GNS
// [VERIFIED] Ended external incentive no longer blocks cleanup or yields rewards
