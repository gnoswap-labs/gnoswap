// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/v1/gnft"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())

	poolAddr, _          = access.GetAddress(prabc.ROLE_POOL.String())
	communityPoolAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"
	quxPath = "gno.land/r/onbloc/qux"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath1 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
	poolPath2 = "gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:100"
)

func main() {
	println("=== Test: Initial Tier Assignment Unclaimable Period Tracking ===")
	println()

	println("[SCENARIO] 1. Initialize system")
	initSystem()

	println()
	println("[SCENARIO] 2. Test Internal Rewards (GNS emission)")
	testInitialTierInternalRewards()

	println()
	println("[SCENARIO] 3. Test External Rewards")
	testInitialTierExternalRewards()
}

func initSystem() {
	testing.SetRealm(adminRealm)

	println("[INFO] set distribution start time")
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	testing.SkipHeights(2)
}

// Test for internal rewards (GNS emission) unclaimable period tracking
func testInitialTierInternalRewards() {
	testing.SetRealm(adminRealm)

	println("[INFO] create pool bar:baz:100")
	pl.CreatePool(cross, barPath, bazPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString())
	testing.SkipHeights(1)

	println("[INFO] set pool tier to 1 (rewards start here)")
	tierAssignmentTime := time.Now().Unix()
	sr.SetPoolTier(cross, poolPath1, 1)
	testing.SkipHeights(1)
	ufmt.Printf("[EXPECTED] tier assigned at: %d, pool has zero liquidity\n", tierAssignmentTime)

	println("[INFO] wait 10 blocks while pool has zero liquidity (unclaimable period)")
	testing.SkipHeights(10)

	waitEndTime := time.Now().Unix()
	unclaimableDuration := waitEndTime - tierAssignmentTime
	ufmt.Printf("[EXPECTED] unclaimable period duration: %d seconds\n", unclaimableDuration)

	// Expected unclaimable reward calculation
	// Assuming emission rate, we can calculate expected unclaimable rewards
	println("[INFO] prepare to stake first position")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(1)

	println("[INFO] mint and stake first position (liquidity becomes positive)")
	stakeTime := time.Now().Unix()
	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		-100,
		100,
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	sr.StakeToken(cross, positionId, "")
	testing.SkipHeights(2)

	actualUnclaimablePeriod := stakeTime - tierAssignmentTime
	ufmt.Printf("[EXPECTED] actual unclaimable period from tier assignment to first stake: %d seconds\n", actualUnclaimablePeriod)

	println("[INFO] collect reward immediately after first stake")
	communityBalanceBefore := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, positionId, false)
	communityBalanceAfter := gns.BalanceOf(communityPoolAddr)
	unclaimableRewardsSent := communityBalanceAfter - communityBalanceBefore

	ufmt.Printf("[RESULT] unclaimable rewards sent to community pool: %d\n", unclaimableRewardsSent)

	// The bug: if lastUnclaimableTime was not set properly during tier assignment,
	// this value will be 0 or incorrect
	if unclaimableRewardsSent == 0 {
		println("[BUG DETECTED] No unclaimable rewards were sent!")
		println("[BUG REASON] lastUnclaimableTime was not initialized during tier assignment")
		println("[BUG IMPACT] Rewards from tier assignment to first stake are lost")
	} else {
		println("[PASS] Unclaimable rewards were properly tracked and sent")
		// We can calculate expected reward based on emission rate
		// Expected: (duration in seconds) * (emission per second for this tier)
	}

	println("[INFO] unstake position for cleanup")
	sr.UnStakeToken(cross, positionId, false)
	testing.SkipHeights(5)
}

// Test for external rewards unclaimable period tracking
func testInitialTierExternalRewards() {
	testing.SetRealm(adminRealm)

	println("[INFO] create pool foo:qux:100")
	pl.CreatePool(cross, fooPath, quxPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString())
	testing.SkipHeights(1)

	println("[INFO] approve tokens for external incentive")
	gns.Approve(cross, stakerAddr, 100_000_000_000) // deposit 100 GNS
	foo.Approve(cross, stakerAddr, maxInt64)        // reward token
	testing.SkipHeights(1)

	println("[INFO] create external incentive (starts next day midnight)")
	currentTime := time.Now().Unix()
	// External incentive must start at least at next day midnight
	// Calculate next day midnight
	dayInSeconds := int64(86400)
	currentMidnight := (currentTime / dayInSeconds) * dayInSeconds
	nextDayMidnight := currentMidnight + dayInSeconds
	incentiveStartTime := nextDayMidnight
	// Duration must be exactly 90, 180, or 365 days
	incentiveDuration := int64(90 * 86400) // 90 days
	incentiveEndTime := nextDayMidnight + incentiveDuration

	sr.CreateExternalIncentive(
		cross,
		poolPath2,
		fooPath,
		1_000_000_000, // rewardAmount
		incentiveStartTime,
		incentiveEndTime,
	)
	testing.SkipHeights(1)
	ufmt.Printf("[EXPECTED] external incentive created, pool has zero liquidity\n")

	println("[INFO] wait until incentive starts and some time passes (unclaimable period)")
	// Calculate blocks to wait until incentive starts + some extra time
	blocksToWaitForStart := (incentiveStartTime - time.Now().Unix()) / 5
	if blocksToWaitForStart < 0 {
		blocksToWaitForStart = 0
	}
	testing.SkipHeights(blocksToWaitForStart + 10) // Wait until start + 10 extra blocks

	waitEndTime := time.Now().Unix()
	unclaimableDuration := waitEndTime - incentiveStartTime
	if unclaimableDuration > 0 {
		ufmt.Printf("[EXPECTED] unclaimable period duration: %d seconds\n", unclaimableDuration)
	}

	println("[INFO] prepare to stake first position")
	foo.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(1)

	println("[INFO] mint and stake first position (liquidity becomes positive)")
	stakeTime := time.Now().Unix()
	positionId, _, _, _ := pn.Mint(
		cross,
		fooPath,
		quxPath,
		fee100,
		-200,
		200,
		"2000",
		"2000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	sr.StakeToken(cross, positionId, "")
	testing.SkipHeights(2)

	actualUnclaimablePeriod := stakeTime - incentiveStartTime
	if actualUnclaimablePeriod > 0 {
		ufmt.Printf("[EXPECTED] unclaimable period from incentive start to first stake: %d seconds\n", actualUnclaimablePeriod)
	}

	println("[INFO] wait and unstake to end the incentive period")
	testing.SkipHeights(5)
	sr.UnStakeToken(cross, positionId, false)

	println("[RESULT] External incentive unclaimable period should be tracked")
	println("[NOTE] External uses different tracking mechanism (unclaimablePeriods tree)")
	println("[NOTE] Should be handled by NewIncentives() initialization")
}

// Output:
// === Test: Initial Tier Assignment Unclaimable Period Tracking ===
//
// [SCENARIO] 1. Initialize system
// [INFO] set distribution start time
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
//
// [SCENARIO] 2. Test Internal Rewards (GNS emission)
// [INFO] create pool bar:baz:100
// [INFO] set pool tier to 1 (rewards start here)
// [EXPECTED] tier assigned at: 1234567905, pool has zero liquidity
// [INFO] wait 10 blocks while pool has zero liquidity (unclaimable period)
// [EXPECTED] unclaimable period duration: 55 seconds
// [INFO] prepare to stake first position
// [INFO] mint and stake first position (liquidity becomes positive)
// [EXPECTED] actual unclaimable period from tier assignment to first stake: 60 seconds
// [INFO] collect reward immediately after first stake
// [RESULT] unclaimable rewards sent to community pool: 182826722
// [PASS] Unclaimable rewards were properly tracked and sent
// [INFO] unstake position for cleanup
//
// [SCENARIO] 3. Test External Rewards
// [INFO] create pool foo:qux:100
// [INFO] approve tokens for external incentive
// [INFO] create external incentive (starts next day midnight)
// [EXPECTED] external incentive created, pool has zero liquidity
// [INFO] wait until incentive starts and some time passes (unclaimable period)
// [EXPECTED] unclaimable period duration: 50 seconds
// [INFO] prepare to stake first position
// [INFO] mint and stake first position (liquidity becomes positive)
// [EXPECTED] unclaimable period from incentive start to first stake: 55 seconds
// [INFO] wait and unstake to end the incentive period
// [RESULT] External incentive unclaimable period should be tracked
// [NOTE] External uses different tracking mechanism (unclaimablePeriods tree)
// [NOTE] Should be handled by NewIncentives() initialization
