// launchpad deposit project single recipient

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
	launchpadRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/launchpad")

	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm        = testing.NewUserRealm(stakerAddr)
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm     = testing.NewUserRealm(govStakerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	bobAddr  = testutils.TestAddress("bob")
	bobRealm = testing.NewUserRealm(bobAddr)

	projectAddr  = testutils.TestAddress("project-owner")
	projectRealm = testing.NewUserRealm(projectAddr)
)

func main() {
	println("[SCENARIO] 1. Create OBL launchpad project")
	createOBLProject()
	projectId := "gno.land/r/onbloc/obl:123"
	projectTier30Id := "gno.land/r/onbloc/obl:123:30"
	println("[INFO] Project tier 30 Total Distribute Amount: 100,000,000")
	println("[INFO] Project tier 30 Distribute Amount Per Second: 38.5802469136")
	println()

	println("[SCENARIO] 2. Deposit GNS to OBL project tier 30 by user1")
	depositGnsTo(aliceAddr, projectId, projectTier30Id, int64(1_000_000))
	println("[INFO] Alice second distribute amount: 38.5802469136")
	println()

	println("[SCENARIO] 3. Deposit GNS to OBL project tier 30 by user2")
	println("[INFO] Alice second distribute amount: 19.2901234568")
	println("[INFO] Bob second distribute amount: 19.2901234568")
	depositGnsTo(bobAddr, projectId, projectTier30Id, int64(1_000_000))
	println()

	println("[SCENARIO] 4. Skip blocks to pass collect wait duration")
	println("[INFO] Skipping 51840 blocks (259200 seconds = 3 days) to pass collect wait duration")
	testing.SkipHeights(51840) // 3 days for tier 30 collect wait duration
	println()

	println("[SCENARIO] 5. Collect launchpad reward for first Deposit with undistributed reward")
	collectLaunchpadReward(aliceAddr, "1")
	println()

	println("[SCENARIO] 6. Collect launchpad reward for second Deposit")
	collectLaunchpadReward(bobAddr, "2")
	println()

	println("[SCENARIO] 7. Skip blocks after reward collection")
	testing.SkipHeights(1)
	collectLaunchpadReward(aliceAddr, "1")
	collectLaunchpadReward(bobAddr, "2")
	println()
}

// Create OBL launchpad project
func createOBLProject() {
	println("[INFO] Creating OBL launchpad project")

	recipientAddr := testutils.TestAddress("project-owner")
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
		tier30Ratio,  // 100000000
		tier90Ratio,  // 200000000
		tier180Ratio, // 700000000
		startTime,    // 5 block later
	)

	println("[INFO] Skipping 120960 blocks")
	testing.SkipHeights(120960)

	println("[EXPECTED] Project created with ID:", projectId)

	// [INFO] Validate project info
	testing.SetRealm(launchpadRealm)
	project, _ := launchpad.GetProject(projectId)
	println("[EXPECTED] Project name:", project.Name())
	println("[EXPECTED] Project token path:", project.TokenPath())
	println("[EXPECTED] Project deposit amount:", project.DepositAmount())
	tiersRatios := project.TiersRatios()
	println("[EXPECTED] Project tier30 ratio:", tiersRatios[30])
	println("[EXPECTED] Project tier90 ratio:", tiersRatios[90])
	println("[EXPECTED] Project tier180 ratio:", tiersRatios[180])

	// [INFO] Validate tier info
	tier30, _ := launchpad.GetProjectTier(projectId, 30)
	println("[EXPECTED] Tier 30 amount:", tier30.TotalDistributeAmount())

	tier90, _ := launchpad.GetProjectTier(projectId, 90)
	println("[EXPECTED] Tier 90 amount:", tier90.TotalDistributeAmount())

	tier180, _ := launchpad.GetProjectTier(projectId, 180)
	println("[EXPECTED] Tier 180 amount:", tier180.TotalDistributeAmount())
}

// Deposit GNS to OBL project tier 30
func depositGnsTo(toAddress address, projectId, projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	println("[INFO] Depositing GNS to OBL project tier 30")

	println("[INFO] Admin transferring GNS to depositor for deposit")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, toAddress, depositAmount) // to deposit

	// approve launchpad to spend GNS
	println("[INFO] Depositor approving launchpad to spend GNS")
	testing.SetRealm(testing.NewUserRealm(toAddress))
	gns.Approve(cross, launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(
		cross,
		projectTierId,
		depositAmount,
		"",
	)
	println("[EXPECTED] Deposit created with ID:", depositId)

	// validate deposit
	testing.SetRealm(launchpadRealm)
	deposit, _ := launchpad.GetDeposit(depositId)
	println("[EXPECTED] Deposit amount:", deposit.DepositAmount())
	println("[EXPECTED] Deposit tier:", deposit.Tier())
	println("[EXPECTED] Deposit depositor:", deposit.Depositor())

	testing.SkipHeights(1)
}

func collectLaunchpadReward(ownerAddress address, depositId string) {
	println("[INFO] Collecting launchpad reward for Deposit ID:", depositId)
	testing.SetRealm(testing.NewUserRealm(ownerAddress))

	beforeOblBalance := obl.BalanceOf(ownerAddress)

	launchpad.CollectRewardByDepositId(cross, depositId)

	afterOblBalance := obl.BalanceOf(ownerAddress)
	println("[EXPECTED] Obl balance after collection:", afterOblBalance-beforeOblBalance)
}

// Output:
// [SCENARIO] 1. Create OBL launchpad project
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [INFO] Skipping 120960 blocks
// [EXPECTED] Project created with ID: gno.land/r/onbloc/obl:123
// [EXPECTED] Project name: OBL Launchpad Project
// [EXPECTED] Project token path: gno.land/r/onbloc/obl
// [EXPECTED] Project deposit amount: 1000000000
// [EXPECTED] Project tier30 ratio: 10
// [EXPECTED] Project tier90 ratio: 20
// [EXPECTED] Project tier180 ratio: 70
// [EXPECTED] Tier 30 amount: 100000000
// [EXPECTED] Tier 90 amount: 200000000
// [EXPECTED] Tier 180 amount: 700000000
// [INFO] Project tier 30 Total Distribute Amount: 100,000,000
// [INFO] Project tier 30 Distribute Amount Per Second: 38.5802469136
//
// [SCENARIO] 2. Deposit GNS to OBL project tier 30 by user1
// [INFO] Depositing GNS to OBL project tier 30
// [INFO] Admin transferring GNS to depositor for deposit
// [INFO] Depositor approving launchpad to spend GNS
// [EXPECTED] Deposit created with ID: 1
// [EXPECTED] Deposit amount: 1000000
// [EXPECTED] Deposit tier: 30
// [EXPECTED] Deposit depositor: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
// [INFO] Alice second distribute amount: 38.5802469136
//
// [SCENARIO] 3. Deposit GNS to OBL project tier 30 by user2
// [INFO] Alice second distribute amount: 19.2901234568
// [INFO] Bob second distribute amount: 19.2901234568
// [INFO] Depositing GNS to OBL project tier 30
// [INFO] Admin transferring GNS to depositor for deposit
// [INFO] Depositor approving launchpad to spend GNS
// [EXPECTED] Deposit created with ID: 2
// [EXPECTED] Deposit amount: 1000000
// [EXPECTED] Deposit tier: 30
// [EXPECTED] Deposit depositor: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 4. Skip blocks to pass collect wait duration
// [INFO] Skipping 51840 blocks (259200 seconds = 3 days) to pass collect wait duration
//
// [SCENARIO] 5. Collect launchpad reward for first Deposit with undistributed reward
// [INFO] Collecting launchpad reward for Deposit ID: 1
// [EXPECTED] Obl balance after collection: 5000289
//
// [SCENARIO] 6. Collect launchpad reward for second Deposit
// [INFO] Collecting launchpad reward for Deposit ID: 2
// [EXPECTED] Obl balance after collection: 5000096
//
// [SCENARIO] 7. Skip blocks after reward collection
// [INFO] Collecting launchpad reward for Deposit ID: 1
// [EXPECTED] Obl balance after collection: 96
// [INFO] Collecting launchpad reward for Deposit ID: 2
// [EXPECTED] Obl balance after collection: 96
