// launchpad first deposit reward

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

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	projectAddr = testutils.TestAddress("project-owner")
)

func main() {
	println("[SCENARIO] 1. Create OBL launchpad project")
	createOBLProject()
	projectTier30Id := "gno.land/r/onbloc/obl:123:30"
	println()

	println("[SCENARIO] 2. First deposit by Alice")
	depositGns(aliceAddr, projectTier30Id, int64(1_000_000))
	println()

	println("[SCENARIO] 3. Skip blocks for reward accumulation")
	println("[INFO] Skipping 100 blocks (500 seconds)")
	testing.SkipHeights(100)
	println()

	println("[SCENARIO] 4. Alice collects first deposit reward")
	collectReward(aliceAddr, "1")
	println()

	println("[SCENARIO] 5. Skip more blocks and collect again")
	println("[INFO] Skipping 200 blocks (1000 seconds)")
	testing.SkipHeights(200)
	collectReward(aliceAddr, "1")
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
	println("[INFO] Tier 30 reward amount: 100,000,000 (10% of 1,000,000,000)")
}

func depositGns(depositorAddr address, projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	println("[INFO] Admin transferring GNS to depositor")
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
	ufmt.Printf("[INFO] Deposit amount: %d\n", depositAmount)

	testing.SkipHeights(1)
}

func collectReward(ownerAddr address, depositId string) {
	println("[INFO] Collecting reward for deposit ID:", depositId)
	testing.SetRealm(testing.NewUserRealm(ownerAddr))

	beforeOblBalance := obl.BalanceOf(ownerAddr)
	ufmt.Printf("[INFO] OBL balance before collection: %d\n", beforeOblBalance)

	rewardAmount := launchpad.CollectRewardByDepositId(cross, depositId)

	afterOblBalance := obl.BalanceOf(ownerAddr)
	ufmt.Printf("[INFO] OBL balance after collection: %d\n", afterOblBalance)
	ufmt.Printf("[INFO] Reward collected: %d\n", rewardAmount)
}

// Output:
// [SCENARIO] 1. Create OBL launchpad project
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [INFO] Skipping 120960 blocks to activate project
// [INFO] Project created with ID: gno.land/r/onbloc/obl:123
// [INFO] Tier 30 reward amount: 100,000,000 (10% of 1,000,000,000)
//
// [SCENARIO] 2. First deposit by Alice
// [INFO] Admin transferring GNS to depositor
// [INFO] Depositor approving launchpad to spend GNS
// [INFO] Deposit created with ID: 1
// [INFO] Deposit amount: 1000000
//
// [SCENARIO] 3. Skip blocks for reward accumulation
// [INFO] Skipping 100 blocks (500 seconds)
//
// [SCENARIO] 4. Alice collects first deposit reward
// [INFO] Collecting reward for deposit ID: 1
// [INFO] OBL balance before collection: 0
// [INFO] OBL balance after collection: 19483
// [INFO] Reward collected: 19483
//
// [SCENARIO] 5. Skip more blocks and collect again
// [INFO] Skipping 200 blocks (1000 seconds)
// [INFO] Collecting reward for deposit ID: 1
// [INFO] OBL balance before collection: 19483
// [INFO] OBL balance after collection: 58063
// [INFO] Reward collected: 38580
