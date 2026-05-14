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
	"gno.land/r/gnoswap/test_token/eth"
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

	println("[SCENARIO] 1. Create ETH launchpad project (1B ETH total)")
	createETHProject()
	projectId := "gno.land/r/gnoswap/test_token/eth:123"
	projectTier30Id := "gno.land/r/gnoswap/test_token/eth:123:30"
	println()

	println("[SCENARIO] 2. Alice deposits 1,000,000 GNS to tier 30 (sole depositor)")
	println("[INFO] Alice is the only depositor in tier 30")
	println("[INFO] She is entitled to ALL of tier 30 rewards (~100,000,000 ETH)")
	depositGns(aliceAddr, projectTier30Id, int64(1_000_000))
	println()

	println("[SCENARIO] 3. Skip to end all tiers (180 days) with NO collect/withdraw")
	ufmt.Printf("[INFO] Skipping %d blocks (%d days at %d sec/block)\n", skipBlocks180Day, int64(180), blockTimeSeconds)
	println("[INFO] No deposit/collect/withdraw events trigger reward manager update")
	println("[INFO] Reward manager will be updated during admin refund calculation")
	testing.SkipHeights(skipBlocks180Day)
	println()

	println("[SCENARIO] 4. Verify launchpad balance before admin refund")
	launchpadBalanceBefore := eth.BalanceOf(launchpadAddr)
	recipientBalanceBefore := eth.BalanceOf(projectAddr)
	aliceEthBefore := eth.BalanceOf(aliceAddr)
	ufmt.Printf("[INFO] Launchpad ETH balance: %d\n", launchpadBalanceBefore)
	ufmt.Printf("[INFO] Project recipient ETH balance: %d\n", recipientBalanceBefore)
	ufmt.Printf("[INFO] Alice ETH balance: %d\n", aliceEthBefore)
	println()

	println("[SCENARIO] 5. Admin calls TransferLeftFromProjectByAdmin")
	println("[INFO] calculateTierClaimableRewards updates reward manager before reading")
	println("[INFO] Correctly computes Alice's claimable rewards (~99,999,999 ETH)")
	println("[INFO] refundableAmount = leftReward - claimable (only tiers 90+180 with no depositors)")
	transferRemainingRewards(projectId)
	println()

	println("[SCENARIO] 6. Verify balances after admin refund")
	launchpadBalanceAfter := eth.BalanceOf(launchpadAddr)
	recipientBalanceAfter := eth.BalanceOf(projectAddr)
	aliceEthAfter := eth.BalanceOf(aliceAddr)
	ufmt.Printf("[INFO] Launchpad ETH balance: %d\n", launchpadBalanceAfter)
	ufmt.Printf("[INFO] Project recipient ETH balance: %d\n", recipientBalanceAfter)
	ufmt.Printf("[INFO] Alice ETH balance: %d\n", aliceEthAfter)
	println()

	println("[SCENARIO] 7. Accounting verification")
	adminRefunded := recipientBalanceAfter - recipientBalanceBefore
	ufmt.Printf("[INFO] Admin refunded: %d ETH\n", adminRefunded)
	ufmt.Printf("[INFO] Launchpad remaining: %d ETH\n", launchpadBalanceAfter)
	println()
	println("[EXPECTED] Alice (sole tier 30 depositor for full 30 days) is entitled to ~100,000,000 ETH")
	println("[EXPECTED] Admin refunds ~900,000,000 ETH (tiers 90+180 with no depositors)")
	ufmt.Printf("[EXPECTED] Admin refunded %d ETH, launchpad retains %d ETH for Alice\n", adminRefunded, launchpadBalanceAfter)
	println("[EXPECTED] Depositor rewards are correctly preserved in the launchpad")
	println()

	println("[SCENARIO] 8. Collect reward for Alice")
	collectReward(aliceAddr)
	println()
}

func createETHProject() {
	println("[INFO] Creating ETH launchpad project")

	recipientAddr := projectAddr
	projectName := "ETH Launchpad Project"
	rewardTokenPath := "gno.land/r/gnoswap/test_token/eth"
	rewardAmount := int64(1_000_000_000)
	conditionPath := ""
	conditionsAmount := ""
	tier30Ratio := int64(10)                       // 100,000,000 ETH
	tier90Ratio := int64(20)                       // 200,000,000 ETH
	tier180Ratio := int64(70)                      // 700,000,000 ETH
	startTime := int64(time.Now().Unix() + 604800) // 7 days

	println("[INFO] Admin creating ETH project")
	testing.SetRealm(adminRealm)
	eth.Approve(cross, launchpadAddr, int64(rewardAmount))
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
	println("[INFO] Tier 30 reward: 100,000,000 ETH (10%)")
	println("[INFO] Tier 90 reward: 200,000,000 ETH (20%)")
	println("[INFO] Tier 180 reward: 700,000,000 ETH (70%)")
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

	launchpadBalanceBefore := eth.BalanceOf(launchpadAddr)
	recipientBalanceBefore := eth.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] Launchpad ETH balance before: %d\n", launchpadBalanceBefore)
	ufmt.Printf("[INFO] Recipient ETH balance before: %d\n", recipientBalanceBefore)

	launchpad.TransferLeftFromProjectByAdmin(cross, projectId, projectAddr)

	launchpadBalanceAfter := eth.BalanceOf(launchpadAddr)
	recipientBalanceAfter := eth.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] Launchpad ETH balance after: %d\n", launchpadBalanceAfter)
	ufmt.Printf("[INFO] Recipient ETH balance after: %d\n", recipientBalanceAfter)
	ufmt.Printf("[INFO] ETH transferred to recipient: %d\n", recipientBalanceAfter-recipientBalanceBefore)
}

func collectReward(addr address) {
	println("[INFO] Collecting reward for address:", addr)
	testing.SetRealm(testing.NewUserRealm(addr))

	depositId := "1"

	beforeEthBalance := eth.BalanceOf(addr)
	ufmt.Printf("[INFO] ETH balance before: %d\n", beforeEthBalance)

	rewardAmount := launchpad.CollectRewardByDepositId(cross, depositId)
	afterEthBalance := eth.BalanceOf(addr)
	ufmt.Printf("[INFO] ETH balance after: %d\n", afterEthBalance)
	ufmt.Printf("[INFO] Reward collected: %d\n", rewardAmount)
}

// Output:
// [SCENARIO] Reward manager update before admin refund
// [INFO] When TransferLeftFromProjectByAdmin is called,
// [INFO] calculateTierClaimableRewards updates AccumulatedRewardPerDepositX128 before reading.
//
// [SCENARIO] 1. Create ETH launchpad project (1B ETH total)
// [INFO] Creating ETH launchpad project
// [INFO] Admin creating ETH project
// [INFO] Skipping 120960 blocks (7 days) to activate project
// [INFO] Project created with ID: gno.land/r/gnoswap/test_token/eth:123
// [INFO] Tier 30 reward: 100,000,000 ETH (10%)
// [INFO] Tier 90 reward: 200,000,000 ETH (20%)
// [INFO] Tier 180 reward: 700,000,000 ETH (70%)
//
// [SCENARIO] 2. Alice deposits 1,000,000 GNS to tier 30 (sole depositor)
// [INFO] Alice is the only depositor in tier 30
// [INFO] She is entitled to ALL of tier 30 rewards (~100,000,000 ETH)
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
// [INFO] Launchpad ETH balance: 1000000000
// [INFO] Project recipient ETH balance: 0
// [INFO] Alice ETH balance: 0
//
// [SCENARIO] 5. Admin calls TransferLeftFromProjectByAdmin
// [INFO] calculateTierClaimableRewards updates reward manager before reading
// [INFO] Correctly computes Alice's claimable rewards (~99,999,999 ETH)
// [INFO] refundableAmount = leftReward - claimable (only tiers 90+180 with no depositors)
// [INFO] Admin transferring remaining rewards to project recipient
// [INFO] Launchpad ETH balance before: 1000000000
// [INFO] Recipient ETH balance before: 0
// [INFO] Launchpad ETH balance after: 99999999
// [INFO] Recipient ETH balance after: 900000001
// [INFO] ETH transferred to recipient: 900000001
//
// [SCENARIO] 6. Verify balances after admin refund
// [INFO] Launchpad ETH balance: 99999999
// [INFO] Project recipient ETH balance: 900000001
// [INFO] Alice ETH balance: 0
//
// [SCENARIO] 7. Accounting verification
// [INFO] Admin refunded: 900000001 ETH
// [INFO] Launchpad remaining: 99999999 ETH
//
// [EXPECTED] Alice (sole tier 30 depositor for full 30 days) is entitled to ~100,000,000 ETH
// [EXPECTED] Admin refunds ~900,000,000 ETH (tiers 90+180 with no depositors)
// [EXPECTED] Admin refunded 900000001 ETH, launchpad retains 99999999 ETH for Alice
// [EXPECTED] Depositor rewards are correctly preserved in the launchpad
//
// [SCENARIO] 8. Collect reward for Alice
// [INFO] Collecting reward for address: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
// [INFO] ETH balance before: 0
// [INFO] ETH balance after: 99999999
// [INFO] Reward collected: 99999999
