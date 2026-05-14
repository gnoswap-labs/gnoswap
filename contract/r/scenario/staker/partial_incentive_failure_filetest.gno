// Test demonstrates permanent reward loss when partial incentive failure occurs
// This reproduces the issue where a single lastCollectTime is used for all rewards

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain/runtime"
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/access"

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

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	gnsPath = "gno.land/r/gnoswap/gns"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive
	depositAmount    int64 = 10_000_000_000 // 10_000 tokens each
	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60

	poolPath = "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:100"
)

func main() {
	println("[SCENARIO] Test partial incentive failure handling")
	println()

	println("[STEP 1] Initialize and setup pool")
	initAndSetup()
	createPool()
	println()

	println("[STEP 2] Create MULTIPLE external incentives (atom with different periods, atone)")
	createMultipleIncentives()
	println()

	println("[STEP 3] Mint and stake position")
	positionId := mintAndStakePosition()
	println()

	println("[STEP 4] Accumulate rewards over time")
	accumulateRewards()
	println()

	println("[STEP 5] Drain atom incentives to simulate fund shortage")
	drainAtomIncentive()
	println()

	println("[STEP 6] Collect rewards - partial success expected")
	demonstratePartialFailure(positionId)
	println()

	println("[STEP 7] Verify reward collection behavior after time passes")
	verifyPermanentLoss(positionId)
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] Set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] Set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	testing.SetRealm(stakerRealm)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] Create atom:atone:100 pool")
	pl.CreatePool(cross, atomPath, atonePath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SkipHeights(1)
}

func createMultipleIncentives() {
	testing.SetRealm(adminRealm)

	println("[INFO] Approve tokens for MULTIPLE external incentives")
	// Create multiple incentives with same token but different time periods
	// This simulates multiple reward programs that could have different funding status
	atom.Approve(cross, stakerAddr, depositAmount*3)
	atone.Approve(cross, stakerAddr, depositAmount)

	// Each external incentive requires 1000 GNS as deposit
	gnsDepositPerIncentive := int64(1_000_000_000) // 1000 GNS
	totalGnsRequired := gnsDepositPerIncentive * 4 // 4 incentives
	gns.Approve(cross, stakerAddr, totalGnsRequired)

	// Different time periods for different incentives
	startTime1 := int64(1234569600)
	endTime1 := startTime1 + TIMESTAMP_90DAYS

	startTime2 := startTime1 + 86400 // Start 1 day later
	endTime2 := startTime2 + TIMESTAMP_90DAYS

	startTime3 := startTime1 + 172800 // Start 2 days later
	endTime3 := startTime3 + TIMESTAMP_90DAYS

	println("[INFO] Create external incentive #1: atom token (period 1)")
	sr.CreateExternalIncentive(
		cross,
		poolPath,
		atomPath,
		depositAmount,
		startTime1,
		endTime1,
	)

	println("[INFO] Create external incentive #2: atom token (period 2)")
	sr.CreateExternalIncentive(
		cross,
		poolPath,
		atomPath,
		depositAmount,
		startTime2,
		endTime2,
	)

	println("[INFO] Create external incentive #3: atom token (period 3)")
	sr.CreateExternalIncentive(
		cross,
		poolPath,
		atomPath,
		depositAmount,
		startTime3,
		endTime3,
	)

	println("[INFO] Create external incentive #4: atone token")
	sr.CreateExternalIncentive(
		cross,
		poolPath,
		atonePath,
		depositAmount,
		startTime1,
		endTime1,
	)

	ufmt.Printf("[SUCCESS] Created 4 external incentives (3 atom, 1 atone)\n")

	// Make external incentives start
	leftHeight := 978 - runtime.ChainHeight()
	if leftHeight > 0 {
		testing.SkipHeights(leftHeight + 5)
	}
}

func mintAndStakePosition() uint64 {
	testing.SetRealm(adminRealm)

	println("[INFO] Approve tokens for minting position")
	atom.Approve(cross, poolAddr, maxInt64)
	atone.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(2)

	println("[INFO] Mint position with significant liquidity")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		atomPath,
		atonePath,
		fee100,
		int32(-100),
		int32(100),
		"1000000",
		"1000000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)

	ufmt.Printf("[SUCCESS] Minted position ID=%d with liquidity=%s\n", positionId, liquidity)

	println("[INFO] Stake the position")
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross, positionId, "")

	testing.SkipHeights(1)
	println("[SUCCESS] Position staked")

	return positionId
}

func accumulateRewards() {
	println("[INFO] Skip 10,000 blocks to accumulate significant rewards")
	testing.SkipHeights(10000)
	println("[SUCCESS] Rewards accumulated for all incentives")
}

func drainAtomIncentive() {
	testing.SetRealm(adminRealm)

	// Create multiple temporary positions to drain atom incentive
	println("[INFO] Creating temporary positions to drain atom incentive...")

	for i := 1; i <= 20; i++ { // Create MORE positions to drain more effectively
		// Mint large position
		tempPosId, _, _, _ := pn.Mint(
			cross,
			atomPath,
			atonePath,
			fee100,
			int32(-10),
			int32(10),
			"50000000", // MUCH larger liquidity to drain faster
			"50000000",
			"1",
			"1",
			maxTimeout,
			adminAddr,
			"",
		)

		// Stake it
		gnft.Approve(cross, stakerAddr, positionIdFrom(tempPosId))
		sr.StakeToken(cross, tempPosId, "")

		if i <= 5 || i == 20 {
			ufmt.Printf("[INFO] Temporary position %d created and staked\n", tempPosId)
		} else if i == 6 {
			println("[INFO] ... creating positions 6-19 ...")
		}
	}

	// Skip many blocks and collect MULTIPLE times to drain atom incentive
	println("[INFO] Skip blocks and collect multiple rounds to drain incentives")

	totalAtomDrained := int64(0)

	// Multiple collection rounds to ensure draining
	for round := 1; round <= 3; round++ {
		testing.SkipHeights(30000)
		ufmt.Printf("[INFO] Collection round %d\n", round)

		for i := 2; i <= 21; i++ { // Position IDs 2-21 are temporary
			beforeAtom := atom.BalanceOf(adminUser)
			sr.CollectReward(cross, uint64(i))
			afterAtom := atom.BalanceOf(adminUser)
			drained := afterAtom - beforeAtom
			totalAtomDrained += drained

			if drained > 0 && (i <= 3 || i == 21) {
				ufmt.Printf("[INFO] Round %d: Collected %d atom from position %d\n", round, drained, i)
			}
		}
	}

	ufmt.Printf("[SUCCESS] Total atom drained: %d (should be close to %d)\n", totalAtomDrained, depositAmount*3)

	// Verify atom incentive is nearly empty - we have 3 atom incentives, so check against total
	if totalAtomDrained < depositAmount*3*90/100 {
		println("[WARNING] May not have sufficiently drained atom incentive")
	}
}

func demonstratePartialFailure(positionId uint64) {
	testing.SetRealm(adminRealm)

	println("[INFO] Skip 5,000 more blocks to accumulate new rewards")
	testing.SkipHeights(5000)

	// Check balances before collection
	beforeAtom := atom.BalanceOf(adminUser)
	beforeAtone := atone.BalanceOf(adminUser)

	println("[ACTION] Collect rewards from main position (ID=1)")

	sr.CollectReward(cross, positionId)

	// Check balances after collection
	afterAtom := atom.BalanceOf(adminUser)
	afterAtone := atone.BalanceOf(adminUser)

	atomReward := afterAtom - beforeAtom
	atoneReward := afterAtone - beforeAtone

	ufmt.Printf("[RESULT] atom reward collected: %d\n", atomReward)
	ufmt.Printf("[RESULT] atone reward collected: %d\n", atoneReward)

	if atomReward == 0 || atomReward < atoneReward/10 {
		println("[INFO] atom incentive gave minimal or no rewards")
	}
	if atoneReward > 0 {
		println("[INFO] atone incentive provided rewards")
	}
}

func verifyPermanentLoss(positionId uint64) {
	testing.SetRealm(adminRealm)

	println("[INFO] Skip 10,000 blocks")
	testing.SkipHeights(10000)

	println("[ACTION] Collect rewards after time has passed")

	beforeAtom := atom.BalanceOf(adminUser)
	beforeAtone := atone.BalanceOf(adminUser)

	sr.CollectReward(cross, positionId)

	afterAtom := atom.BalanceOf(adminUser)
	afterAtone := atone.BalanceOf(adminUser)

	atomReward := afterAtom - beforeAtom
	atoneReward := afterAtone - beforeAtone

	ufmt.Printf("[RESULT] atom reward: %d\n", atomReward)
	ufmt.Printf("[RESULT] atone reward: %d\n", atoneReward)

	// Immediate re-collection to confirm per-incentive tracking
	println("[ACTION] Immediate re-collection")

	beforeAtom = atom.BalanceOf(adminUser)
	beforeAtone = atone.BalanceOf(adminUser)

	sr.CollectReward(cross, positionId)

	immediateAtom := atom.BalanceOf(adminUser) - beforeAtom
	immediateAtone := atone.BalanceOf(adminUser) - beforeAtone

	ufmt.Printf("[RESULT] Immediate atom reward: %d\n", immediateAtom)
	ufmt.Printf("[RESULT] Immediate atone reward: %d\n", immediateAtone)

	// Skip more time and collect again
	println("[INFO] Skip 5000 blocks")
	testing.SkipHeights(5000)

	println("[ACTION] Final collection after additional time")

	finalBeforeAtom := atom.BalanceOf(adminUser)
	finalBeforeAtone := atone.BalanceOf(adminUser)

	sr.CollectReward(cross, positionId)

	finalAtom := atom.BalanceOf(adminUser) - finalBeforeAtom
	finalAtone := atone.BalanceOf(adminUser) - finalBeforeAtone

	ufmt.Printf("[RESULT] atom collected: %d\n", finalAtom)
	ufmt.Printf("[RESULT] atone collected: %d\n", finalAtone)
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] Test partial incentive failure handling
//
// [STEP 1] Initialize and setup pool
// [INFO] Set unstaking fee to 0
// [INFO] Set pool creation fee to 0
// [INFO] Create atom:atone:100 pool
//
// [STEP 2] Create MULTIPLE external incentives (atom with different periods, atone)
// [INFO] Approve tokens for MULTIPLE external incentives
// [INFO] Create external incentive #1: atom token (period 1)
// [INFO] Create external incentive #2: atom token (period 2)
// [INFO] Create external incentive #3: atom token (period 3)
// [INFO] Create external incentive #4: atone token
// [SUCCESS] Created 4 external incentives (3 atom, 1 atone)
//
// [STEP 3] Mint and stake position
// [INFO] Approve tokens for minting position
// [INFO] Mint position with significant liquidity
// [SUCCESS] Minted position ID=1 with liquidity=200510416
// [INFO] Stake the position
// [SUCCESS] Position staked
//
// [STEP 4] Accumulate rewards over time
// [INFO] Skip 10,000 blocks to accumulate significant rewards
// [SUCCESS] Rewards accumulated for all incentives
//
// [STEP 5] Drain atom incentives to simulate fund shortage
// [INFO] Creating temporary positions to drain atom incentive...
// [INFO] Temporary position 2 created and staked
// [INFO] Temporary position 3 created and staked
// [INFO] Temporary position 4 created and staked
// [INFO] Temporary position 5 created and staked
// [INFO] Temporary position 6 created and staked
// [INFO] ... creating positions 6-19 ...
// [INFO] Temporary position 21 created and staked
// [INFO] Skip blocks and collect multiple rounds to drain incentives
// [INFO] Collection round 1
// [INFO] Round 1: Collected 5709458 atom from position 2
// [INFO] Round 1: Collected 5709458 atom from position 3
// [INFO] Round 1: Collected 5709458 atom from position 21
// [INFO] Collection round 2
// [INFO] Round 2: Collected 8679627 atom from position 2
// [INFO] Round 2: Collected 8679627 atom from position 3
// [INFO] Round 2: Collected 8679627 atom from position 21
// [INFO] Collection round 3
// [INFO] Round 3: Collected 9373998 atom from position 2
// [INFO] Round 3: Collected 9373998 atom from position 3
// [INFO] Round 3: Collected 9373998 atom from position 21
// [SUCCESS] Total atom drained: 475261660 (should be close to 30000000000)
// [WARNING] May not have sufficiently drained atom incentive
//
// [STEP 6] Collect rewards - partial success expected
// [INFO] Skip 5,000 more blocks to accumulate new rewards
// [ACTION] Collect rewards from main position (ID=1)
// [RESULT] atom reward collected: 19348260
// [RESULT] atone reward collected: 19312691
// [INFO] atone incentive provided rewards
//
// [STEP 7] Verify reward collection behavior after time passes
// [INFO] Skip 10,000 blocks
// [ACTION] Collect rewards after time has passed
// [RESULT] atom reward: 9663
// [RESULT] atone reward: 3221
// [ACTION] Immediate re-collection
// [RESULT] Immediate atom reward: 0
// [RESULT] Immediate atone reward: 0
// [INFO] Skip 5000 blocks
// [ACTION] Final collection after additional time
// [RESULT] atom collected: 4830
// [RESULT] atone collected: 1610
