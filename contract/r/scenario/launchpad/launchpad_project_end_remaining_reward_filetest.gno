// launchpad project end remaining reward

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
	bobAddr   = testutils.TestAddress("bob")

	projectAddr = testutils.TestAddress("project-owner")
)

func main() {
	println("[SCENARIO] 1. Create ETH launchpad project")
	createETHProject()
	projectId := "gno.land/r/gnoswap/test_token/eth:123"
	projectTier30Id := "gno.land/r/gnoswap/test_token/eth:123:30"
	println()

	println("[SCENARIO] 2. Partial deposits - only tier 30 receives deposits")
	println("[INFO] Only Alice and Bob deposit to tier 30, tier 90 and 180 have no deposits")
	depositGns(aliceAddr, projectTier30Id, int64(1_000_000))
	depositGns(bobAddr, projectTier30Id, int64(1_000_000))
	println()

	println("[SCENARIO] 3. Skip blocks to pass collect wait duration")
	println("[INFO] Skipping 51840 blocks (259200 seconds = 3 days) to pass collect wait duration")
	testing.SkipHeights(51840) // 3 days for tier 30 collect wait duration
	println()

	println("[SCENARIO] 4. Depositors collect their rewards")
	println("[INFO] Alice collecting reward")
	collectReward(aliceAddr, "1")
	println()

	println("[INFO] Bob collecting reward")
	collectReward(bobAddr, "2")
	println()

	println("[SCENARIO] 5. Skip blocks to end project")
	ufmt.Printf("[INFO] Project duration is 180 days (%d blocks at %d sec/block)\n", skipBlocks180Day, blockTimeSeconds)
	println("[INFO] Skipping 180 days worth of blocks to ensure project ended")
	testing.SkipHeights(skipBlocks180Day)
	println()

	println("[SCENARIO] 6. Depositors collect final rewards after project ends")
	println("[INFO] Alice collecting final reward")
	collectReward(aliceAddr, "1")
	println()

	println("[INFO] Bob collecting final reward")
	collectReward(bobAddr, "2")
	println()

	println("[SCENARIO] 7. Depositors withdraw their GNS deposits")
	println("[INFO] Alice withdrawing deposit")
	withdrawDeposit(aliceAddr, "1")
	println()

	println("[INFO] Bob withdrawing deposit")
	withdrawDeposit(bobAddr, "2")
	println()

	println("[SCENARIO] 8. Check project recipient balance before refund")
	checkProjectRecipientBalance()
	println()

	println("[SCENARIO] 9. Admin transfers remaining rewards to project recipient")
	println("[INFO] Remaining rewards include:")
	println("[INFO] - Tier 90 full amount (no deposits): 200,000,000 ETH")
	println("[INFO] - Tier 180 full amount (no deposits): 700,000,000 ETH")
	println("[INFO] - Any undistributed rewards from tier 30")
	transferRemainingRewards(projectId)
	println()

	println("[SCENARIO] 10. Check project recipient balance after refund")
	checkProjectRecipientBalance()
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
	tier30Ratio := int64(10)  // 100,000,000 ETH
	tier90Ratio := int64(20)  // 200,000,000 ETH
	tier180Ratio := int64(70) // 700,000,000 ETH
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

	println("[INFO] Skipping 120960 blocks to activate project")
	testing.SkipHeights(120960)

	println("[INFO] Project created with ID:", projectId)
	println("[INFO] Total reward: 1,000,000,000 ETH")
	println("[INFO] Tier 30 reward: 100,000,000 ETH (10%)")
	println("[INFO] Tier 90 reward: 200,000,000 ETH (20%)")
	println("[INFO] Tier 180 reward: 700,000,000 ETH (70%)")
}

func depositGns(depositorAddr address, projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	ufmt.Printf("[INFO] Admin transferring %d GNS to depositor\n", depositAmount)
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, depositorAddr, depositAmount)

	println("[INFO] Depositor approving launchpad to spend GNS")
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

func collectReward(ownerAddr address, depositId string) {
	println("[INFO] Collecting reward for deposit ID:", depositId)
	testing.SetRealm(testing.NewUserRealm(ownerAddr))

	beforeEthBalance := eth.BalanceOf(ownerAddr)
	ufmt.Printf("[INFO] ETH balance before: %d\n", beforeEthBalance)

	rewardAmount := launchpad.CollectRewardByDepositId(cross, depositId)

	afterEthBalance := eth.BalanceOf(ownerAddr)
	ufmt.Printf("[INFO] ETH balance after: %d\n", afterEthBalance)
	ufmt.Printf("[INFO] Reward collected: %d\n", rewardAmount)
}

func withdrawDeposit(ownerAddr address, depositId string) {
	println("[INFO] Withdrawing deposit ID:", depositId)
	testing.SetRealm(testing.NewUserRealm(ownerAddr))

	beforeGnsBalance := gns.BalanceOf(ownerAddr)
	ufmt.Printf("[INFO] GNS balance before: %d\n", beforeGnsBalance)

	gnsAmount, _ := launchpad.CollectDepositGns(cross, depositId)

	afterGnsBalance := gns.BalanceOf(ownerAddr)
	ufmt.Printf("[INFO] GNS balance after: %d\n", afterGnsBalance)
	ufmt.Printf("[INFO] GNS withdrawn: %d\n", gnsAmount)
}

func checkProjectRecipientBalance() {
	ethBalance := eth.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] Project recipient ETH balance: %d\n", ethBalance)
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
	ufmt.Printf("[INFO] ETH transferred: %d\n", recipientBalanceAfter-recipientBalanceBefore)
}

// Output:
// [SCENARIO] 1. Create ETH launchpad project
// [INFO] Creating ETH launchpad project
// [INFO] Admin creating ETH project
// [INFO] Skipping 120960 blocks to activate project
// [INFO] Project created with ID: gno.land/r/gnoswap/test_token/eth:123
// [INFO] Total reward: 1,000,000,000 ETH
// [INFO] Tier 30 reward: 100,000,000 ETH (10%)
// [INFO] Tier 90 reward: 200,000,000 ETH (20%)
// [INFO] Tier 180 reward: 700,000,000 ETH (70%)
//
// [SCENARIO] 2. Partial deposits - only tier 30 receives deposits
// [INFO] Only Alice and Bob deposit to tier 30, tier 90 and 180 have no deposits
// [INFO] Admin transferring 1000000 GNS to depositor
// [INFO] Depositor approving launchpad to spend GNS
// [INFO] Deposit created with ID: 1
// [INFO] Admin transferring 1000000 GNS to depositor
// [INFO] Depositor approving launchpad to spend GNS
// [INFO] Deposit created with ID: 2
//
// [SCENARIO] 3. Skip blocks to pass collect wait duration
// [INFO] Skipping 51840 blocks (259200 seconds = 3 days) to pass collect wait duration
//
// [SCENARIO] 4. Depositors collect their rewards
// [INFO] Alice collecting reward
// [INFO] Collecting reward for deposit ID: 1
// [INFO] ETH balance before: 0
// [INFO] ETH balance after: 5000289
// [INFO] Reward collected: 5000289
//
// [INFO] Bob collecting reward
// [INFO] Collecting reward for deposit ID: 2
// [INFO] ETH balance before: 0
// [INFO] ETH balance after: 5000096
// [INFO] Reward collected: 5000096
//
// [SCENARIO] 5. Skip blocks to end project
// [INFO] Project duration is 180 days (3110400 blocks at 5 sec/block)
// [INFO] Skipping 180 days worth of blocks to ensure project ended
//
// [SCENARIO] 6. Depositors collect final rewards after project ends
// [INFO] Alice collecting final reward
// [INFO] Collecting reward for deposit ID: 1
// [INFO] ETH balance before: 5000289
// [INFO] ETH balance after: 50000096
// [INFO] Reward collected: 44999807
//
// [INFO] Bob collecting final reward
// [INFO] Collecting reward for deposit ID: 2
// [INFO] ETH balance before: 5000096
// [INFO] ETH balance after: 49999903
// [INFO] Reward collected: 44999807
//
// [SCENARIO] 7. Depositors withdraw their GNS deposits
// [INFO] Alice withdrawing deposit
// [INFO] Withdrawing deposit ID: 1
// [INFO] GNS balance before: 0
// [INFO] GNS balance after: 1000000
// [INFO] GNS withdrawn: 1000000
//
// [INFO] Bob withdrawing deposit
// [INFO] Withdrawing deposit ID: 2
// [INFO] GNS balance before: 0
// [INFO] GNS balance after: 1000000
// [INFO] GNS withdrawn: 1000000
//
// [SCENARIO] 8. Check project recipient balance before refund
// [INFO] Project recipient ETH balance: 0
//
// [SCENARIO] 9. Admin transfers remaining rewards to project recipient
// [INFO] Remaining rewards include:
// [INFO] - Tier 90 full amount (no deposits): 200,000,000 ETH
// [INFO] - Tier 180 full amount (no deposits): 700,000,000 ETH
// [INFO] - Any undistributed rewards from tier 30
// [INFO] Admin transferring remaining rewards to project recipient
// [INFO] Launchpad ETH balance before: 900000001
// [INFO] Recipient ETH balance before: 0
// [INFO] Launchpad ETH balance after: 0
// [INFO] Recipient ETH balance after: 900000001
// [INFO] ETH transferred: 900000001
//
// [SCENARIO] 10. Check project recipient balance after refund
// [INFO] Project recipient ETH balance: 900000001
