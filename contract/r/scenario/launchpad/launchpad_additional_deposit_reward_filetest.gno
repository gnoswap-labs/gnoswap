// launchpad additional deposit reward

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
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/obl"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

	aliceAddr   = testutils.TestAddress("alice")
	bobAddr     = testutils.TestAddress("bob")
	charlieAddr = testutils.TestAddress("charlie")
	davidAddr   = testutils.TestAddress("david")
	erinAddr    = testutils.TestAddress("erin")
	frankAddr   = testutils.TestAddress("frank")

	projectAddr = testutils.TestAddress("project-owner")
)

func main() {
	println("[SCENARIO] 1. Create OBL launchpad project")
	createOBLProject()
	projectTier30Id := "gno.land/r/onbloc/obl:123:30"
	projectTier90Id := "gno.land/r/onbloc/obl:123:90"
	projectTier180Id := "gno.land/r/onbloc/obl:123:180"
	println()

	println("[SCENARIO] 2. First deposit by Alice (1,000,000 GNS)")
	depositGns(aliceAddr, projectTier30Id, int64(1_000_000))
	println("[INFO] Alice is the only depositor, receives 100% of rewards")
	println()

	println("[SCENARIO] 3. Skip 100 blocks - Alice accumulates rewards alone")
	println("[INFO] Skipping 100 blocks (500 seconds)")
	testing.SkipHeights(100)
	println("[INFO] Alice accumulated rewards for 100 blocks as sole depositor")
	println()

	println("[SCENARIO] 4. Second deposit by Bob (1,000,000 GNS) - same amount as Alice")
	depositGns(bobAddr, projectTier30Id, int64(1_000_000))
	println("[INFO] Now Alice and Bob each have 50% share of rewards")
	println()

	println("[SCENARIO] 5. Skip 100 blocks - rewards split between Alice and Bob")
	println("[INFO] Skipping 100 blocks (500 seconds)")
	testing.SkipHeights(100)
	println("[INFO] Rewards now split 50/50 between Alice and Bob")
	println()

	println("[SCENARIO] 6. Third deposit by Charlie (2,000,000 GNS) - double amount")
	depositGns(charlieAddr, projectTier30Id, int64(2_000_000))
	println("[INFO] Share distribution: Alice 25%, Bob 25%, Charlie 50%")
	println()

	println("[SCENARIO] 7. Skip blocks to pass collect wait duration")
	println("[INFO] Skipping 51840 blocks (259200 seconds = 3 days) to pass collect wait duration")
	testing.SkipHeights(51840) // 3 days for tier 30 collect wait duration
	println()

	println("[SCENARIO] 8. Collect rewards for all depositors")
	println("[INFO] Collecting Alice's reward (deposit ID: 1)")
	collectReward(aliceAddr, "1")
	println()

	println("[INFO] Collecting Bob's reward (deposit ID: 2)")
	collectReward(bobAddr, "2")
	println()

	println("[INFO] Collecting Charlie's reward (deposit ID: 3)")
	collectReward(charlieAddr, "3")
	println()

	println("[SCENARIO] 9. Skip more blocks and collect again to verify ongoing distribution")
	println("[INFO] Skipping 50 blocks (250 seconds)")
	testing.SkipHeights(50)
	println()

	println("[INFO] Alice collecting additional reward")
	collectReward(aliceAddr, "1")
	println()

	println("[INFO] Bob collecting additional reward")
	collectReward(bobAddr, "2")
	println()

	println("[INFO] Charlie collecting additional reward")
	collectReward(charlieAddr, "3")
	println()

	validateCollectableDurationByTier(projectTier30Id, projectTier90Id, projectTier180Id)
}

func createOBLProject() {
	println("[INFO] Creating OBL launchpad project")

	recipientAddr := projectAddr
	projectName := "OBL Launchpad Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	rewardAmount := int64(1_000_000_000)
	conditionPath := ""
	conditionsAmount := ""
	tier30Ratio := int64(10)
	tier90Ratio := int64(20)
	tier180Ratio := int64(70)
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
	println("[INFO] Tier 30 total reward: 100,000,000 OBL (10% of 1,000,000,000)")
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
	ufmt.Printf("[INFO] Deposit amount: %d GNS\n", depositAmount)

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

func validateCollectableDurationByTier(projectTier30Id, projectTier90Id, projectTier180Id string) {
	dayTime := int64(60 * 60 * 24)
	validateCollectableDurationForTier(davidAddr, projectTier30Id, dayTime/5)  // 1 days
	validateCollectableDurationForTier(erinAddr, projectTier90Id, dayTime/5)   // 1 days
	validateCollectableDurationForTier(frankAddr, projectTier180Id, dayTime/5) // 1 days
}

func validateCollectableDurationForTier(depositorAddr address, projectTierId string, claimableBlocks int64) {
	depositId := depositGnsSilent(depositorAddr, projectTierId, int64(1_000_000))

	skipBeforeAssert := claimableBlocks - 2 // depositGnsSilent already advanced 1 block
	if skipBeforeAssert > 0 {
		testing.SkipHeights(skipBeforeAssert)
	}
	assertCollectNotYetClaimable(depositorAddr, depositId)

	testing.SkipHeights(1)
	collectRewardSilent(depositorAddr, depositId)
}

func depositGnsSilent(depositorAddr address, projectTierId string, depositAmount int64) string {
	testing.SetOriginCaller(adminAddr)
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

	testing.SkipHeights(1)
	return depositId
}

func collectRewardSilent(ownerAddr address, depositId string) {
	testing.SetRealm(testing.NewUserRealm(ownerAddr))
	launchpad.CollectRewardByDepositId(cross, depositId)
}

func assertCollectNotYetClaimable(ownerAddr address, depositId string) {
	expectedPanicMessage := "[GNOSWAP-LAUNCHPAD-019] invalid reward state"
	uassert.AbortsContains(t, expectedPanicMessage, func() {
		testing.SetRealm(testing.NewUserRealm(ownerAddr))
		launchpad.CollectRewardByDepositId(cross, depositId)
	})
	ufmt.Printf("[EXPECTED] Collect should abort before claimable time: %s\n", expectedPanicMessage)
}

// Output:
// [SCENARIO] 1. Create OBL launchpad project
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [INFO] Skipping 120960 blocks to activate project
// [INFO] Project created with ID: gno.land/r/onbloc/obl:123
// [INFO] Tier 30 total reward: 100,000,000 OBL (10% of 1,000,000,000)
//
// [SCENARIO] 2. First deposit by Alice (1,000,000 GNS)
// [INFO] Admin transferring 1000000 GNS to depositor
// [INFO] Depositor approving launchpad to spend GNS
// [INFO] Deposit created with ID: 1
// [INFO] Deposit amount: 1000000 GNS
// [INFO] Alice is the only depositor, receives 100% of rewards
//
// [SCENARIO] 3. Skip 100 blocks - Alice accumulates rewards alone
// [INFO] Skipping 100 blocks (500 seconds)
// [INFO] Alice accumulated rewards for 100 blocks as sole depositor
//
// [SCENARIO] 4. Second deposit by Bob (1,000,000 GNS) - same amount as Alice
// [INFO] Admin transferring 1000000 GNS to depositor
// [INFO] Depositor approving launchpad to spend GNS
// [INFO] Deposit created with ID: 2
// [INFO] Deposit amount: 1000000 GNS
// [INFO] Now Alice and Bob each have 50% share of rewards
//
// [SCENARIO] 5. Skip 100 blocks - rewards split between Alice and Bob
// [INFO] Skipping 100 blocks (500 seconds)
// [INFO] Rewards now split 50/50 between Alice and Bob
//
// [SCENARIO] 6. Third deposit by Charlie (2,000,000 GNS) - double amount
// [INFO] Admin transferring 2000000 GNS to depositor
// [INFO] Depositor approving launchpad to spend GNS
// [INFO] Deposit created with ID: 3
// [INFO] Deposit amount: 2000000 GNS
// [INFO] Share distribution: Alice 25%, Bob 25%, Charlie 50%
//
// [SCENARIO] 7. Skip blocks to pass collect wait duration
// [INFO] Skipping 51840 blocks (259200 seconds = 3 days) to pass collect wait duration
//
// [SCENARIO] 8. Collect rewards for all depositors
// [INFO] Collecting Alice's reward (deposit ID: 1)
// [INFO] Collecting reward for deposit ID: 1
// [INFO] OBL balance before: 0
// [INFO] OBL balance after: 2529272
// [INFO] Reward collected: 2529272
//
// [INFO] Collecting Bob's reward (deposit ID: 2)
// [INFO] Collecting reward for deposit ID: 2
// [INFO] OBL balance before: 0
// [INFO] OBL balance after: 2509789
// [INFO] Reward collected: 2509789
//
// [INFO] Collecting Charlie's reward (deposit ID: 3)
// [INFO] Collecting reward for deposit ID: 3
// [INFO] OBL balance before: 0
// [INFO] OBL balance after: 5000096
// [INFO] Reward collected: 5000096
//
// [SCENARIO] 9. Skip more blocks and collect again to verify ongoing distribution
// [INFO] Skipping 50 blocks (250 seconds)
//
// [INFO] Alice collecting additional reward
// [INFO] Collecting reward for deposit ID: 1
// [INFO] OBL balance before: 2529272
// [INFO] OBL balance after: 2531684
// [INFO] Reward collected: 2412
//
// [INFO] Bob collecting additional reward
// [INFO] Collecting reward for deposit ID: 2
// [INFO] OBL balance before: 2509789
// [INFO] OBL balance after: 2512201
// [INFO] Reward collected: 2412
//
// [INFO] Charlie collecting additional reward
// [INFO] Collecting reward for deposit ID: 3
// [INFO] OBL balance before: 5000096
// [INFO] OBL balance after: 5004918
// [INFO] Reward collected: 4822
//
// [EXPECTED] Collect should abort before claimable time: [GNOSWAP-LAUNCHPAD-019] invalid reward state
// [EXPECTED] Collect should abort before claimable time: [GNOSWAP-LAUNCHPAD-019] invalid reward state
// [EXPECTED] Collect should abort before claimable time: [GNOSWAP-LAUNCHPAD-019] invalid reward state
