// Verify that TransferLeftFromProjectByAdmin correctly accounts for depositor
// rewards even when no deposit/collect/withdraw has occurred since the tier ended.
//
// Previously, calculateTierClaimableRewards read the stale
// AccumulatedRewardPerDepositX128 without updating it to the current timestamp,
// causing active depositors' pending rewards to be under-counted and the admin
// refund to be over-counted.
//
// After the fix, calculateTierClaimableRewards calls updateRewardPerDepositX128
// before reading accumulated rewards, so the admin refund correctly excludes
// the depositors' earned rewards.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee/v1"

	_ "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/obl"
)

var (
	blockTimeSeconds int64 = 5
	secondsInDay     int64 = 24 * 60 * 60
	skipBlocks180Day int64 = 180 * secondsInDay / blockTimeSeconds

	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

	aliceAddr = testutils.TestAddress("alice")

	projectAddr = testutils.TestAddress("project-owner")
)

func main() {
	println("[SCENARIO] Reward manager update before admin refund")
	println("[INFO] When TransferLeftFromProjectByAdmin is called,")
	println("[INFO] calculateTierClaimableRewards updates AccumulatedRewardPerDepositX128 before reading.")
	println()

	println("[SCENARIO] 1. Create OBL launchpad project (1B OBL total)")
	createOBLProject()
	projectId := "gno.land/r/onbloc/obl:123"
	projectTier30Id := "gno.land/r/onbloc/obl:123:30"
	println()

	println("[SCENARIO] 2. Alice deposits 1,000,000 GNS to tier 30 (sole depositor)")
	println("[INFO] Alice is the only depositor in tier 30")
	println("[INFO] She is entitled to ALL of tier 30 rewards (~100,000,000 OBL)")
	depositGns(aliceAddr, projectTier30Id, int64(1_000_000))
	println()

	println("[SCENARIO] 3. Skip to end all tiers (180 days) with NO collect/withdraw")
	ufmt.Printf("[INFO] Skipping %d blocks (%d days at %d sec/block)\n", skipBlocks180Day, int64(180), blockTimeSeconds)
	println("[INFO] No deposit/collect/withdraw events trigger reward manager update")
	println("[INFO] Reward manager will be updated during admin refund calculation")
	testing.SkipHeights(skipBlocks180Day)
	println()

	println("[SCENARIO] 4. Verify launchpad balance before admin refund")
	launchpadBalanceBefore := obl.BalanceOf(launchpadAddr)
	recipientBalanceBefore := obl.BalanceOf(projectAddr)
	aliceOblBefore := obl.BalanceOf(aliceAddr)
	ufmt.Printf("[INFO] Launchpad OBL balance: %d\n", launchpadBalanceBefore)
	ufmt.Printf("[INFO] Project recipient OBL balance: %d\n", recipientBalanceBefore)
	ufmt.Printf("[INFO] Alice OBL balance: %d\n", aliceOblBefore)
	println()

	println("[SCENARIO] 5. Admin calls TransferLeftFromProjectByAdmin")
	println("[INFO] calculateTierClaimableRewards updates reward manager before reading")
	println("[INFO] Correctly computes Alice's claimable rewards (~99,999,999 OBL)")
	println("[INFO] refundableAmount = leftReward - claimable (only tiers 90+180 with no depositors)")
	transferRemainingRewards(projectId)
	println()

	println("[SCENARIO] 6. Verify balances after admin refund")
	launchpadBalanceAfter := obl.BalanceOf(launchpadAddr)
	recipientBalanceAfter := obl.BalanceOf(projectAddr)
	aliceOblAfter := obl.BalanceOf(aliceAddr)
	ufmt.Printf("[INFO] Launchpad OBL balance: %d\n", launchpadBalanceAfter)
	ufmt.Printf("[INFO] Project recipient OBL balance: %d\n", recipientBalanceAfter)
	ufmt.Printf("[INFO] Alice OBL balance: %d\n", aliceOblAfter)
	println()

	println("[SCENARIO] 7. Accounting verification")
	adminRefunded := recipientBalanceAfter - recipientBalanceBefore
	ufmt.Printf("[INFO] Admin refunded: %d OBL\n", adminRefunded)
	ufmt.Printf("[INFO] Launchpad remaining: %d OBL\n", launchpadBalanceAfter)
	println()
	println("[EXPECTED] Alice (sole tier 30 depositor for full 30 days) is entitled to ~100,000,000 OBL")
	println("[EXPECTED] Admin refunds ~900,000,000 OBL (tiers 90+180 with no depositors)")
	ufmt.Printf("[EXPECTED] Admin refunded %d OBL, launchpad retains %d OBL for Alice\n", adminRefunded, launchpadBalanceAfter)
	println("[EXPECTED] Depositor rewards are correctly preserved in the launchpad")
	println()

	println("[SCENARIO] 8. Collect reward for Alice")
	collectReward(aliceAddr)
	println()
}

func createOBLProject() {
	println("[INFO] Creating OBL launchpad project")

	recipientAddr := projectAddr
	projectName := "OBL Launchpad Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	rewardAmount := int64(1_000_000_000)
	conditionPath := ""
	conditionsAmount := ""
	tier30Ratio := int64(10)                       // 100,000,000 OBL
	tier90Ratio := int64(20)                       // 200,000,000 OBL
	tier180Ratio := int64(70)                      // 700,000,000 OBL
	startTime := int64(time.Now().Unix() + 604800) // 7 days

	println("[INFO] Admin creating OBL project")
	testing.SetRealm(adminRealm)
	obl.Approve(cross, launchpadAddr, int64(rewardAmount))
	projectId := launchpad.CreateProject(
		cross,
		projectName,
		rewardTokenPath,
		recipientAddr,
		rewardAmount,
		conditionPath,
		conditionsAmount,
		tier30Ratio,
		tier90Ratio,
		tier180Ratio,
		startTime,
	)

	println("[INFO] Skipping 120960 blocks (7 days) to activate project")
	testing.SkipHeights(120960)

	println("[INFO] Project created with ID:", projectId)
	println("[INFO] Tier 30 reward: 100,000,000 OBL (10%)")
	println("[INFO] Tier 90 reward: 200,000,000 OBL (20%)")
	println("[INFO] Tier 180 reward: 700,000,000 OBL (70%)")
}

func depositGns(depositorAddr address, projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	ufmt.Printf("[INFO] Admin transferring %d GNS to Alice\n", depositAmount)
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, depositorAddr, depositAmount)

	println("[INFO] Alice approving launchpad to spend GNS")
	testing.SetRealm(testing.NewUserRealm(depositorAddr))
	gns.Approve(cross, launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(
		cross,
		projectTierId,
		depositAmount,
		"",
	)
	println("[INFO] Deposit created with ID:", depositId)

	testing.SkipHeights(1)
}

func transferRemainingRewards(projectId string) {
	println("[INFO] Admin transferring remaining rewards to project recipient")
	testing.SetRealm(adminRealm)

	launchpadBalanceBefore := obl.BalanceOf(launchpadAddr)
	recipientBalanceBefore := obl.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] Launchpad OBL balance before: %d\n", launchpadBalanceBefore)
	ufmt.Printf("[INFO] Recipient OBL balance before: %d\n", recipientBalanceBefore)

	launchpad.TransferLeftFromProjectByAdmin(cross, projectId, projectAddr)

	launchpadBalanceAfter := obl.BalanceOf(launchpadAddr)
	recipientBalanceAfter := obl.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] Launchpad OBL balance after: %d\n", launchpadBalanceAfter)
	ufmt.Printf("[INFO] Recipient OBL balance after: %d\n", recipientBalanceAfter)
	ufmt.Printf("[INFO] OBL transferred to recipient: %d\n", recipientBalanceAfter-recipientBalanceBefore)
}

func collectReward(addr address) {
	println("[INFO] Collecting reward for address:", addr)
	testing.SetRealm(testing.NewUserRealm(addr))

	depositId := "1"

	beforeOblBalance := obl.BalanceOf(addr)
	ufmt.Printf("[INFO] OBL balance before: %d\n", beforeOblBalance)

	rewardAmount := launchpad.CollectRewardByDepositId(cross, depositId)
	afterOblBalance := obl.BalanceOf(addr)
	ufmt.Printf("[INFO] OBL balance after: %d\n", afterOblBalance)
	ufmt.Printf("[INFO] Reward collected: %d\n", rewardAmount)
}

// Output:
// [SCENARIO] Reward manager update before admin refund
// [INFO] When TransferLeftFromProjectByAdmin is called,
// [INFO] calculateTierClaimableRewards updates AccumulatedRewardPerDepositX128 before reading.
//
// [SCENARIO] 1. Create OBL launchpad project (1B OBL total)
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [INFO] Skipping 120960 blocks (7 days) to activate project
// [INFO] Project created with ID: gno.land/r/onbloc/obl:123
// [INFO] Tier 30 reward: 100,000,000 OBL (10%)
// [INFO] Tier 90 reward: 200,000,000 OBL (20%)
// [INFO] Tier 180 reward: 700,000,000 OBL (70%)
//
// [SCENARIO] 2. Alice deposits 1,000,000 GNS to tier 30 (sole depositor)
// [INFO] Alice is the only depositor in tier 30
// [INFO] She is entitled to ALL of tier 30 rewards (~100,000,000 OBL)
// [INFO] Admin transferring 1000000 GNS to Alice
// [INFO] Alice approving launchpad to spend GNS
// [INFO] Deposit created with ID: 1
//
// [SCENARIO] 3. Skip to end all tiers (180 days) with NO collect/withdraw
// [INFO] Skipping 3110400 blocks (180 days at 5 sec/block)
// [INFO] No deposit/collect/withdraw events trigger reward manager update
// [INFO] Reward manager will be updated during admin refund calculation
//
// [SCENARIO] 4. Verify launchpad balance before admin refund
// [INFO] Launchpad OBL balance: 1000000000
// [INFO] Project recipient OBL balance: 0
// [INFO] Alice OBL balance: 0
//
// [SCENARIO] 5. Admin calls TransferLeftFromProjectByAdmin
// [INFO] calculateTierClaimableRewards updates reward manager before reading
// [INFO] Correctly computes Alice's claimable rewards (~99,999,999 OBL)
// [INFO] refundableAmount = leftReward - claimable (only tiers 90+180 with no depositors)
// [INFO] Admin transferring remaining rewards to project recipient
// [INFO] Launchpad OBL balance before: 1000000000
// [INFO] Recipient OBL balance before: 0
// [INFO] Launchpad OBL balance after: 99999999
// [INFO] Recipient OBL balance after: 900000001
// [INFO] OBL transferred to recipient: 900000001
//
// [SCENARIO] 6. Verify balances after admin refund
// [INFO] Launchpad OBL balance: 99999999
// [INFO] Project recipient OBL balance: 900000001
// [INFO] Alice OBL balance: 0
//
// [SCENARIO] 7. Accounting verification
// [INFO] Admin refunded: 900000001 OBL
// [INFO] Launchpad remaining: 99999999 OBL
//
// [EXPECTED] Alice (sole tier 30 depositor for full 30 days) is entitled to ~100,000,000 OBL
// [EXPECTED] Admin refunds ~900,000,000 OBL (tiers 90+180 with no depositors)
// [EXPECTED] Admin refunded 900000001 OBL, launchpad retains 99999999 OBL for Alice
// [EXPECTED] Depositor rewards are correctly preserved in the launchpad
//
// [SCENARIO] 8. Collect reward for Alice
// [INFO] Collecting reward for address: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
// [INFO] OBL balance before: 0
// [INFO] OBL balance after: 99999999
// [INFO] Reward collected: 99999999
