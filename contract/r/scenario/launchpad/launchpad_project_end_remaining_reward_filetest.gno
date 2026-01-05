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

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/obl"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

	aliceAddr = testutils.TestAddress("alice")
	bobAddr   = testutils.TestAddress("bob")

	projectAddr = testutils.TestAddress("project-owner")
)

func main() {
	println("[SCENARIO] 1. Create OBL launchpad project")
	createOBLProject()
	projectId := "gno.land/r/onbloc/obl:123"
	projectTier30Id := "gno.land/r/onbloc/obl:123:30"
	println()

	println("[SCENARIO] 2. Partial deposits - only tier 30 receives deposits")
	println("[INFO] Only Alice and Bob deposit to tier 30, tier 90 and 180 have no deposits")
	depositGns(aliceAddr, projectTier30Id, int64(1_000_000))
	depositGns(bobAddr, projectTier30Id, int64(1_000_000))
	println()

	println("[SCENARIO] 3. Skip blocks to accumulate rewards")
	println("[INFO] Skipping 1000 blocks")
	testing.SkipHeights(1000)
	println()

	println("[SCENARIO] 4. Depositors collect their rewards before project ends")
	println("[INFO] Alice collecting reward")
	collectReward(aliceAddr, "1")
	println()

	println("[INFO] Bob collecting reward")
	collectReward(bobAddr, "2")
	println()

	println("[SCENARIO] 5. Skip blocks to end project")
	println("[INFO] Project duration is 180 days (7776000 blocks at 5 sec/block)")
	println("[INFO] Skipping remaining blocks to end project")
	testing.SkipHeights(7776000)
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
	println("[INFO] - Tier 90 full amount (no deposits): 200,000,000 OBL")
	println("[INFO] - Tier 180 full amount (no deposits): 700,000,000 OBL")
	println("[INFO] - Any undistributed rewards from tier 30")
	transferRemainingRewards(projectId)
	println()

	println("[SCENARIO] 10. Check project recipient balance after refund")
	checkProjectRecipientBalance()
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
	tier30Ratio := int64(10)  // 100,000,000 OBL
	tier90Ratio := int64(20)  // 200,000,000 OBL
	tier180Ratio := int64(70) // 700,000,000 OBL
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

	println("[INFO] Skipping 120960 blocks to activate project")
	testing.SkipHeights(120960)

	println("[INFO] Project created with ID:", projectId)
	println("[INFO] Total reward: 1,000,000,000 OBL")
	println("[INFO] Tier 30 reward: 100,000,000 OBL (10%)")
	println("[INFO] Tier 90 reward: 200,000,000 OBL (20%)")
	println("[INFO] Tier 180 reward: 700,000,000 OBL (70%)")
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

	beforeOblBalance := obl.BalanceOf(ownerAddr)
	ufmt.Printf("[INFO] OBL balance before: %d\n", beforeOblBalance)

	rewardAmount := launchpad.CollectRewardByDepositId(cross, depositId)

	afterOblBalance := obl.BalanceOf(ownerAddr)
	ufmt.Printf("[INFO] OBL balance after: %d\n", afterOblBalance)
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
	oblBalance := obl.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] Project recipient OBL balance: %d\n", oblBalance)
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
	ufmt.Printf("[INFO] OBL transferred: %d\n", recipientBalanceAfter-recipientBalanceBefore)
}

// Output:
// [SCENARIO] 1. Create OBL launchpad project
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [INFO] Skipping 120960 blocks to activate project
// [INFO] Project created with ID: gno.land/r/onbloc/obl:123
// [INFO] Total reward: 1,000,000,000 OBL
// [INFO] Tier 30 reward: 100,000,000 OBL (10%)
// [INFO] Tier 90 reward: 200,000,000 OBL (20%)
// [INFO] Tier 180 reward: 700,000,000 OBL (70%)
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
// [SCENARIO] 3. Skip blocks to accumulate rewards
// [INFO] Skipping 1000 blocks
//
// [SCENARIO] 4. Depositors collect their rewards before project ends
// [INFO] Alice collecting reward
// [INFO] Collecting reward for deposit ID: 1
// [INFO] OBL balance before: 0
// [INFO] OBL balance after: 96739
// [INFO] Reward collected: 96739
//
// [INFO] Bob collecting reward
// [INFO] Collecting reward for deposit ID: 2
// [INFO] OBL balance before: 0
// [INFO] OBL balance after: 96547
// [INFO] Reward collected: 96547
//
// [SCENARIO] 5. Skip blocks to end project
// [INFO] Project duration is 180 days (7776000 blocks at 5 sec/block)
// [INFO] Skipping remaining blocks to end project
//
// [SCENARIO] 6. Depositors collect final rewards after project ends
// [INFO] Alice collecting final reward
// [INFO] Collecting reward for deposit ID: 1
// [INFO] OBL balance before: 96739
// [INFO] OBL balance after: 50000096
// [INFO] Reward collected: 49903357
//
// [INFO] Bob collecting final reward
// [INFO] Collecting reward for deposit ID: 2
// [INFO] OBL balance before: 96547
// [INFO] OBL balance after: 49999903
// [INFO] Reward collected: 49903356
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
// [INFO] Project recipient OBL balance: 0
//
// [SCENARIO] 9. Admin transfers remaining rewards to project recipient
// [INFO] Remaining rewards include:
// [INFO] - Tier 90 full amount (no deposits): 200,000,000 OBL
// [INFO] - Tier 180 full amount (no deposits): 700,000,000 OBL
// [INFO] - Any undistributed rewards from tier 30
// [INFO] Admin transferring remaining rewards to project recipient
// [INFO] Launchpad OBL balance before: 900000001
// [INFO] Recipient OBL balance before: 0
// [INFO] Launchpad OBL balance after: 0
// [INFO] Recipient OBL balance after: 900000001
// [INFO] OBL transferred: 900000001
//
// [SCENARIO] 10. Check project recipient balance after refund
// [INFO] Project recipient OBL balance: 900000001
