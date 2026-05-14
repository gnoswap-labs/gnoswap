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
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

	aliceAddr   = testutils.TestAddress("alice")
	bobAddr     = testutils.TestAddress("bob")
	charlieAddr = testutils.TestAddress("charlie")

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
	depositGns("Alice", aliceAddr, projectTier30Id, int64(1_000_000))
	println()

	println("[SCENARIO] 3. Skip half of the project duration blocks - Alice accumulates rewards alone")
	testing.SkipHeights(259200)
	println("[INFO] Alice accumulated rewards for half of the project duration as sole depositor")
	println()

	println("[SCENARIO] 4. Bob deposits 1,000,000 GNS to tier 30")
	depositGns("Bob", bobAddr, projectTier30Id, int64(1_000_000))
	println()

	println("[SCENARIO] 5. Charlie deposits 1,000,000 GNS to tier 30 (with skip 1 blocks)")
	testing.SkipHeights(1)
	depositGns("Charlie", charlieAddr, projectTier30Id, int64(1_000_000))
	println()

	println("[SCENARIO] 6. Skip to end all tiers (180+ days) with NO collect/withdraw")
	println("[INFO] No deposit/collect/withdraw events trigger reward manager update")
	println("[INFO] Reward manager will be updated during admin refund calculation")
	testing.SkipHeights(24*60*60*180/5 + 1)
	println()

	println("[SCENARIO] 7. Verify launchpad balance before admin refund")
	launchpadBalanceBefore := eth.BalanceOf(launchpadAddr)
	recipientBalanceBefore := eth.BalanceOf(projectAddr)
	aliceEthBefore := eth.BalanceOf(aliceAddr)
	bobEthBefore := eth.BalanceOf(bobAddr)
	charlieEthBefore := eth.BalanceOf(charlieAddr)
	ufmt.Printf("[INFO] Launchpad ETH balance: %d\n", launchpadBalanceBefore)
	ufmt.Printf("[INFO] Project recipient ETH balance: %d\n", recipientBalanceBefore)
	ufmt.Printf("[INFO] Alice ETH balance: %d\n", aliceEthBefore)
	ufmt.Printf("[INFO] Bob ETH balance: %d\n", bobEthBefore)
	ufmt.Printf("[INFO] Charlie ETH balance: %d\n", charlieEthBefore)
	println()

	println("[SCENARIO] 8. Admin calls TransferLeftFromProjectByAdmin")
	transferRemainingRewards(projectId)
	println()

	println("[SCENARIO] 9. Collect reward for Alice")
	collectReward("Alice", "1", aliceAddr)
	println()

	println("[SCENARIO] 10. Collect reward for Bob")
	collectReward("Bob", "2", bobAddr)
	println()

	println("[SCENARIO] 11. Collect reward for Charlie")
	collectReward("Charlie", "3", charlieAddr)
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

	println("[INFO] Skipping 604800 / 5 blocks (7 days) to activate project")
	testing.SkipHeights(604800 / 5) // 5 seconds per block

	println("[INFO] Project created with ID:", projectId)
	println("[INFO] Tier 30 reward: 100,000,000 ETH (10%)")
	println("[INFO] Tier 90 reward: 200,000,000 ETH (20%)")
	println("[INFO] Tier 180 reward: 700,000,000 ETH (70%)")
}

func depositGns(username string, depositorAddr address, projectTierId string, depositAmount int64) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, depositorAddr, depositAmount)

	testing.SetRealm(testing.NewUserRealm(depositorAddr))
	gns.Approve(cross, launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(
		cross,
		projectTierId,
		depositAmount,
		"",
	)
	println("[INFO] %s deposit created with ID: %s\n", username, depositId)

	testing.SkipHeights(1)
}

func transferRemainingRewards(projectId string) {
	println("[INFO] Admin transferring remaining rewards to project recipient")
	testing.SetRealm(adminRealm)

	launchpadBalanceBefore := eth.BalanceOf(launchpadAddr)
	recipientBalanceBefore := eth.BalanceOf(projectAddr)

	launchpad.TransferLeftFromProjectByAdmin(cross, projectId, projectAddr)

	launchpadBalanceAfter := eth.BalanceOf(launchpadAddr)
	recipientBalanceAfter := eth.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] Launchpad ETH changed: %d\n", launchpadBalanceAfter-launchpadBalanceBefore)
	ufmt.Printf("[INFO] Recipient ETH changed: %d\n", recipientBalanceAfter-recipientBalanceBefore)
}

func collectReward(username string, depositId string, addr address) {
	ufmt.Printf("[INFO] Collecting reward for %s address: %s\n", username, addr)
	testing.SetRealm(testing.NewUserRealm(addr))

	beforeEthBalance := eth.BalanceOf(addr)
	launchpad.CollectRewardByDepositId(cross, depositId)
	afterEthBalance := eth.BalanceOf(addr)
	ufmt.Printf("[INFO] %s ETH balance changed: %d\n", username, afterEthBalance-beforeEthBalance)
}

// Output:
// [SCENARIO] Reward manager update before admin refund
// [INFO] When TransferLeftFromProjectByAdmin is called,
// [INFO] calculateTierClaimableRewards updates AccumulatedRewardPerDepositX128 before reading.
//
// [SCENARIO] 1. Create ETH launchpad project (1B ETH total)
// [INFO] Creating ETH launchpad project
// [INFO] Admin creating ETH project
// [INFO] Skipping 604800 / 5 blocks (7 days) to activate project
// [INFO] Project created with ID: gno.land/r/gnoswap/test_token/eth:123
// [INFO] Tier 30 reward: 100,000,000 ETH (10%)
// [INFO] Tier 90 reward: 200,000,000 ETH (20%)
// [INFO] Tier 180 reward: 700,000,000 ETH (70%)
//
// [SCENARIO] 2. Alice deposits 1,000,000 GNS to tier 30 (sole depositor)
// [INFO] %s deposit created with ID: %s
//  Alice 1
//
// [SCENARIO] 3. Skip half of the project duration blocks - Alice accumulates rewards alone
// [INFO] Alice accumulated rewards for half of the project duration as sole depositor
//
// [SCENARIO] 4. Bob deposits 1,000,000 GNS to tier 30
// [INFO] %s deposit created with ID: %s
//  Bob 2
//
// [SCENARIO] 5. Charlie deposits 1,000,000 GNS to tier 30 (with skip 1 blocks)
// [INFO] %s deposit created with ID: %s
//  Charlie 3
//
// [SCENARIO] 6. Skip to end all tiers (180+ days) with NO collect/withdraw
// [INFO] No deposit/collect/withdraw events trigger reward manager update
// [INFO] Reward manager will be updated during admin refund calculation
//
// [SCENARIO] 7. Verify launchpad balance before admin refund
// [INFO] Launchpad ETH balance: 1000000000
// [INFO] Project recipient ETH balance: 0
// [INFO] Alice ETH balance: 0
// [INFO] Bob ETH balance: 0
// [INFO] Charlie ETH balance: 0
//
// [SCENARIO] 8. Admin calls TransferLeftFromProjectByAdmin
// [INFO] Admin transferring remaining rewards to project recipient
// [INFO] Launchpad ETH changed: -900000002
// [INFO] Recipient ETH changed: 900000002
//
// [SCENARIO] 9. Collect reward for Alice
// [INFO] Collecting reward for Alice address: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
// [INFO] Alice ETH balance changed: 66666859
//
// [SCENARIO] 10. Collect reward for Bob
// [INFO] Collecting reward for Bob address: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
// [INFO] Bob ETH balance changed: 16666666
//
// [SCENARIO] 11. Collect reward for Charlie
// [INFO] Collecting reward for Charlie address: g1vd5xzunvd9j47h6lta047h6lta047h6l6a3cm8
// [INFO] Charlie ETH balance changed: 16666473
