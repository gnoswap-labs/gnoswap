// launchpad getter test

package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	_ "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/obl"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	launchpadRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/launchpad")

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = testing.NewUserRealm(user1Addr)

	user2Addr  = testutils.TestAddress("user2")
	user2Realm = testing.NewUserRealm(user2Addr)

	projectAddr  = testutils.TestAddress("project1")
	projectRealm = testing.NewUserRealm(projectAddr)
)

var t *testing.T

func main() {
	println("[SCENARIO] 1. Setup test data")
	projectId, depositId1, depositId2, projectTier30Id, projectTier90Id, projectTier180Id := setupTestData()
	println()

	println("[SCENARIO] 2. Test Project Getters")
	testProjectGetters(projectId)
	println()

	println("[SCENARIO] 3. Test ProjectTier Getters")
	testProjectTierGetters(projectId, projectTier30Id, projectTier90Id, projectTier180Id)
	println()

	println("[SCENARIO] 4. Test Deposit Getters")
	testDepositGetters(depositId1, depositId2)
	println()

	println("[SCENARIO] 5. Test RewardManager Getters")
	testRewardManagerGetters(projectTier30Id, projectTier90Id, projectTier180Id)
	println()

	println("[SCENARIO] 6. Test RewardState Getters")
	testRewardStateGetters(projectTier30Id, depositId1)
	println()
}

func setupTestData() (string, string, string, string, string, string) {
	println("[INFO] Setting up test data")

	// Create project
	recipientAddr := projectAddr
	projectName := "Test OBL Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	rewardAmount := int64(10_000_000)
	conditionPath := ""
	conditionsAmount := ""
	tier30Ratio := int64(30)
	tier90Ratio := int64(30)
	tier180Ratio := int64(40)
	startTime := int64(time.Now().Unix() + 604800) // 7 days from now

	println("[INFO] Admin creating OBL project")
	testing.SetRealm(adminRealm)
	obl.Approve(cross, launchpadAddr, rewardAmount)
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

	println("[EXPECTED] Project created with ID:", projectId)

	projectTier30Id := projectId + ":30"
	projectTier90Id := projectId + ":90"
	projectTier180Id := projectId + ":180"

	// Create deposits
	println("[INFO] Creating deposits for testing")

	// Deposit 1 (30 days)
	println("[INFO] Admin transferring GNS to user1")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, user1Addr, 5_000_000)

	println("[INFO] User1 approving and depositing to 30 day tier")
	testing.SetRealm(user1Realm)
	gns.Approve(cross, launchpadAddr, 5_000_000)
	depositId1 := launchpad.DepositGns(cross, projectTier30Id, 2_000_000, "")

	println("[EXPECTED] Deposit 1 ID:", depositId1)

	// Deposit 2 (90 days)
	println("[INFO] Admin transferring GNS to user2")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, user2Addr, 5_000_000)

	println("[INFO] User2 approving and depositing to 90 day tier")
	testing.SetRealm(user2Realm)
	gns.Approve(cross, launchpadAddr, 5_000_000)
	depositId2 := launchpad.DepositGns(cross, projectTier90Id, 3_000_000, "")

	println("[EXPECTED] Deposit 2 ID:", depositId2)

	return projectId, depositId1, depositId2, projectTier30Id, projectTier90Id, projectTier180Id
}

func testProjectGetters(projectId string) {
	println("[INFO] Testing project getters")

	// Set realm to launchpad for getter calls
	testing.SetRealm(launchpadRealm)

	// GetProjectCount
	count := launchpad.GetProjectCount()
	println("[EXPECTED] Project count:", count)

	// GetProjectIDs
	ids := launchpad.GetProjectIDs(0, 10)
	println("[EXPECTED] Project IDs (offset=0, limit=10):", len(ids), "projects")
	for i, id := range ids {
		ufmt.Printf("[EXPECTED] - Project %d: %s\n", i+1, id)
	}

	// GetProject
	project, err := launchpad.GetProject(projectId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Project details:")
	println("[EXPECTED] - ID:", project.ID())
	println("[EXPECTED] - Name:", project.Name())
	println("[EXPECTED] - Token Path:", project.TokenPath())
	println("[EXPECTED] - Recipient:", project.Recipient())
	println("[EXPECTED] - Deposit Amount:", project.DepositAmount())

	// GetProjectName
	name, err := launchpad.GetProjectName(projectId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Project name:", name)

	// GetProjectTokenPath
	tokenPath, err := launchpad.GetProjectTokenPath(projectId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Project token path:", tokenPath)

	// GetProjectDepositAmount
	depositAmount, err := launchpad.GetProjectDepositAmount(projectId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Project deposit amount:", depositAmount)

	// GetProjectRecipient
	recipient, err := launchpad.GetProjectRecipient(projectId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Project recipient:", recipient)

	// GetProjectCondition (this project has no conditions)
	condition, err := launchpad.GetProjectCondition(projectId, "gno.land/r/gnoswap/gns")
	if err != nil {
		// Expected error when no condition exists
		println("[EXPECTED] Project condition error (no condition set):", err.Error())
	} else if condition == nil {
		println("[EXPECTED] Project condition for gno.land/r/gnoswap/gns: nil")
	} else {
		println("[EXPECTED] Project condition token path:", condition.TokenPath())
		println("[EXPECTED] Project condition minimum amount:", condition.MinimumAmount())
	}

	// GetProjectTiersRatios
	tiersRatios, err := launchpad.GetProjectTiersRatios(projectId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Project tiers ratios:")
	println("[EXPECTED] - Tier 30:", tiersRatios[30])
	println("[EXPECTED] - Tier 90:", tiersRatios[90])
	println("[EXPECTED] - Tier 180:", tiersRatios[180])

	// GetProjectCreatedHeight
	createdHeight, err := launchpad.GetProjectCreatedHeight(projectId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Project created height:", createdHeight)

	// GetProjectCreatedAt
	createdAt, err := launchpad.GetProjectCreatedAt(projectId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Project created at:", createdAt)

	// GetProjectActiveStatus
	isActive, err := launchpad.GetProjectActiveStatus(projectId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Project active status:", isActive)
}

func testProjectTierGetters(projectId, projectTier30Id, projectTier90Id, projectTier180Id string) {
	println("[INFO] Testing project tier getters")

	// Set realm to launchpad for getter calls
	testing.SetRealm(launchpadRealm)

	tiers := []int64{30, 90, 180}

	for i, tier := range tiers {
		ufmt.Printf("[INFO] Testing tier %d\n", tier)

		// GetProjectTier
		projectTier, err := launchpad.GetProjectTier(projectId, tier)
		if err != nil {
			panic(err)
		}
		if projectTier != nil {
			ufmt.Printf("[EXPECTED] Tier %d details:\n", tier)
			ufmt.Printf("[EXPECTED] - ID: %s\n", projectTier.ID())
			ufmt.Printf("[EXPECTED] - Start Time: %d\n", projectTier.StartTime())
			ufmt.Printf("[EXPECTED] - End Time: %d\n", projectTier.EndTime())
		}

		// GetProjectTierDistributeAmountPerSecondX128
		distributeAmountX128, err := launchpad.GetProjectTierDistributeAmountPerSecondX128(projectId, tier)
		if err != nil {
			panic(err)
		}
		ufmt.Printf("[EXPECTED] Tier %d distribute amount per second X128: %s\n", tier, distributeAmountX128.ToString())

		// GetProjectTierTotalDistributeAmount
		totalDistribute, err := launchpad.GetProjectTierTotalDistributeAmount(projectId, tier)
		if err != nil {
			panic(err)
		}
		ufmt.Printf("[EXPECTED] Tier %d total distribute amount: %d\n", tier, totalDistribute)

		// GetProjectTierTotalDepositAmount
		totalDeposit, err := launchpad.GetProjectTierTotalDepositAmount(projectId, tier)
		if err != nil {
			panic(err)
		}
		ufmt.Printf("[EXPECTED] Tier %d total deposit amount: %d\n", tier, totalDeposit)

		// GetProjectTierTotalWithdrawAmount
		totalWithdraw, err := launchpad.GetProjectTierTotalWithdrawAmount(projectId, tier)
		if err != nil {
			panic(err)
		}
		ufmt.Printf("[EXPECTED] Tier %d total withdraw amount: %d\n", tier, totalWithdraw)

		// GetProjectTierTotalDepositCount
		depositCount, err := launchpad.GetProjectTierTotalDepositCount(projectId, tier)
		if err != nil {
			panic(err)
		}
		ufmt.Printf("[EXPECTED] Tier %d total deposit count: %d\n", tier, depositCount)

		// GetProjectTierTotalWithdrawCount
		withdrawCount, err := launchpad.GetProjectTierTotalWithdrawCount(projectId, tier)
		if err != nil {
			panic(err)
		}
		ufmt.Printf("[EXPECTED] Tier %d total withdraw count: %d\n", tier, withdrawCount)

		// GetProjectTierTotalCollectedAmount
		collectedAmount, err := launchpad.GetProjectTierTotalCollectedAmount(projectId, tier)
		if err != nil {
			panic(err)
		}
		ufmt.Printf("[EXPECTED] Tier %d total collected amount: %d\n", tier, collectedAmount)

		// GetProjectTierStartTime
		startTime, err := launchpad.GetProjectTierStartTime(projectId, tier)
		if err != nil {
			panic(err)
		}
		ufmt.Printf("[EXPECTED] Tier %d start time: %d\n", tier, startTime)

		// GetProjectTierEndTime
		endTime, err := launchpad.GetProjectTierEndTime(projectId, tier)
		if err != nil {
			panic(err)
		}
		ufmt.Printf("[EXPECTED] Tier %d end time: %d\n", tier, endTime)

		if i < len(tiers)-1 {
			println()
		}
	}
}

func testDepositGetters(depositId1, depositId2 string) {
	println("[INFO] Testing deposit getters")

	// Set realm to launchpad for getter calls
	testing.SetRealm(launchpadRealm)

	// GetDepositCount
	count := launchpad.GetDepositCount()
	println("[EXPECTED] Deposit count:", count)

	// GetCurrentDepositId
	currentId := launchpad.GetCurrentDepositId()
	println("[EXPECTED] Current deposit ID counter:", currentId)

	// Test deposit 1
	println("[INFO] Testing deposit 1 getters")

	// GetDeposit
	deposit1, err := launchpad.GetDeposit(depositId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Deposit 1 details:")
	println("[EXPECTED] - ID:", deposit1.ID())
	println("[EXPECTED] - Project ID:", deposit1.ProjectID())
	println("[EXPECTED] - Tier:", deposit1.Tier())
	println("[EXPECTED] - Amount:", deposit1.DepositAmount())

	// GetDepositProjectID
	projectId1, err := launchpad.GetDepositProjectID(depositId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Deposit 1 project ID:", projectId1)

	// GetDepositTier
	tier1, err := launchpad.GetDepositTier(depositId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Deposit 1 tier:", tier1)

	// GetDepositProjectTierID
	projectTierId1, err := launchpad.GetDepositProjectTierID(depositId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Deposit 1 project tier ID:", projectTierId1)

	// GetDepositAmount
	amount1, err := launchpad.GetDepositAmount(depositId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Deposit 1 amount:", amount1)

	// GetDepositWithdrawnHeight
	withdrawnHeight1, err := launchpad.GetDepositWithdrawnHeight(depositId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Deposit 1 withdrawn height:", withdrawnHeight1)

	// GetDepositWithdrawnTime
	withdrawnTime1, err := launchpad.GetDepositWithdrawnTime(depositId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Deposit 1 withdrawn time:", withdrawnTime1)

	// GetDepositCreatedHeight
	createdHeight1, err := launchpad.GetDepositCreatedHeight(depositId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Deposit 1 created height:", createdHeight1)

	// GetDepositCreatedAt
	createdAt1, err := launchpad.GetDepositCreatedAt(depositId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Deposit 1 created at:", createdAt1)

	// GetDepositEndTime
	endTime1, err := launchpad.GetDepositEndTime(depositId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Deposit 1 end time:", endTime1)
}

func testRewardManagerGetters(projectTier30Id, projectTier90Id, projectTier180Id string) {
	println("[INFO] Testing reward manager getters")

	// Set realm to launchpad for getter calls
	testing.SetRealm(launchpadRealm)

	// GetProjectTierRewardManagerCount
	count := launchpad.GetProjectTierRewardManagerCount()
	println("[EXPECTED] Reward manager count:", count)

	println("[INFO] Testing reward manager for 30 day tier")

	// GetProjectTierRewardManager
	manager, err := launchpad.GetProjectTierRewardManager(projectTier30Id)
	if err != nil {
		panic(err)
	}
	if manager != nil {
		println("[EXPECTED] Reward manager details:")
		println("[EXPECTED] - Total Distribute Amount:", manager.TotalDistributeAmount())
		println("[EXPECTED] - Total Claimed Amount:", manager.TotalClaimedAmount())
	}

	// GetProjectTierRewardDistributeAmountPerSecondX128
	distributeAmountX128, err := launchpad.GetProjectTierRewardDistributeAmountPerSecondX128(projectTier30Id)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Distribute amount per second X128:", distributeAmountX128.ToString())

	// GetProjectTierRewardAccumulatedRewardPerDepositX128
	accRewardPerDepositX128, err := launchpad.GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTier30Id)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Accumulated reward per deposit X128:", accRewardPerDepositX128.ToString())

	// GetProjectTierRewardTotalDistributeAmount
	totalDistribute, err := launchpad.GetProjectTierRewardTotalDistributeAmount(projectTier30Id)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Total distribute amount:", totalDistribute)

	// GetProjectTierRewardTotalClaimedAmount
	totalClaimed, err := launchpad.GetProjectTierRewardTotalClaimedAmount(projectTier30Id)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Total claimed amount:", totalClaimed)

	// GetProjectTierRewardDistributeStartTime
	startTime, err := launchpad.GetProjectTierRewardDistributeStartTime(projectTier30Id)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Distribute start time:", startTime)

	// GetProjectTierRewardDistributeEndTime
	endTime, err := launchpad.GetProjectTierRewardDistributeEndTime(projectTier30Id)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Distribute end time:", endTime)

	// GetProjectTierRewardAccumulatedDistributeAmount
	accDistributeAmount, err := launchpad.GetProjectTierRewardAccumulatedDistributeAmount(projectTier30Id)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Accumulated distribute amount:", accDistributeAmount)

	// GetProjectTierRewardAccumulatedHeight
	accHeight, err := launchpad.GetProjectTierRewardAccumulatedHeight(projectTier30Id)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Accumulated height:", accHeight)

	// GetProjectTierRewardAccumulatedTime
	accTime, err := launchpad.GetProjectTierRewardAccumulatedTime(projectTier30Id)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Accumulated time:", accTime)

	// GetProjectTierRewardClaimableDuration
	claimableDuration, err := launchpad.GetProjectTierRewardClaimableDuration(projectTier30Id)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Reward claimable duration:", claimableDuration)
}

func testRewardStateGetters(projectTierId, depositId string) {
	println("[INFO] Testing reward state getters")

	// Set realm to launchpad for getter calls
	testing.SetRealm(launchpadRealm)

	// GetRewardState
	rewardState, err := launchpad.GetRewardState(projectTierId, depositId)
	if err != nil {
		panic(err)
	}
	if rewardState != nil {
		println("[EXPECTED] Reward state details:")
		println("[EXPECTED] - Deposit Amount:", rewardState.DepositAmount())
		println("[EXPECTED] - Accumulated Reward Amount:", rewardState.AccumulatedRewardAmount())
		println("[EXPECTED] - Claimed Amount:", rewardState.ClaimedAmount())
		println("[EXPECTED] - Claimable Time:", rewardState.ClaimableTime())
	} else {
		println("[EXPECTED] No reward state found for deposit")
	}
}

// Output:
// [SCENARIO] 1. Setup test data
// [INFO] Setting up test data
// [INFO] Admin creating OBL project
// [INFO] Skipping 120960 blocks to activate project
// [EXPECTED] Project created with ID: gno.land/r/onbloc/obl:123
// [INFO] Creating deposits for testing
// [INFO] Admin transferring GNS to user1
// [INFO] User1 approving and depositing to 30 day tier
// [EXPECTED] Deposit 1 ID: 1
// [INFO] Admin transferring GNS to user2
// [INFO] User2 approving and depositing to 90 day tier
// [EXPECTED] Deposit 2 ID: 2
//
// [SCENARIO] 2. Test Project Getters
// [INFO] Testing project getters
// [EXPECTED] Project count: 1
// [EXPECTED] Project IDs (offset=0, limit=10): 1 projects
// [EXPECTED] - Project 1: gno.land/r/onbloc/obl:123
// [EXPECTED] Project details:
// [EXPECTED] - ID: gno.land/r/onbloc/obl:123
// [EXPECTED] - Name: Test OBL Project
// [EXPECTED] - Token Path: gno.land/r/onbloc/obl
// [EXPECTED] - Recipient: g1wpex76n9vd6rzh6lta047h6lta047h6lztprp7
// [EXPECTED] - Deposit Amount: 10000000
// [EXPECTED] Project name: Test OBL Project
// [EXPECTED] Project token path: gno.land/r/onbloc/obl
// [EXPECTED] Project deposit amount: 10000000
// [EXPECTED] Project recipient: g1wpex76n9vd6rzh6lta047h6lta047h6lztprp7
// [EXPECTED] Project condition error (no condition set): condition not found
// [EXPECTED] Project tiers ratios:
// [EXPECTED] - Tier 30: 30
// [EXPECTED] - Tier 90: 30
// [EXPECTED] - Tier 180: 40
// [EXPECTED] Project created height: 123
// [EXPECTED] Project created at: 1234567890
// [EXPECTED] Project active status: true
//
// [SCENARIO] 3. Test ProjectTier Getters
// [INFO] Testing project tier getters
// [INFO] Testing tier 30
// [EXPECTED] Tier 30 details:
// [EXPECTED] - ID: gno.land/r/onbloc/obl:123:30
// [EXPECTED] - Start Time: 1235172690
// [EXPECTED] - End Time: 1237764690
// [EXPECTED] Tier 30 distribute amount per second X128: 393845332084419517897424314157139133629
// [EXPECTED] Tier 30 total distribute amount: 3000000
// [EXPECTED] Tier 30 total deposit amount: 2000000
// [EXPECTED] Tier 30 total withdraw amount: 0
// [EXPECTED] Tier 30 total deposit count: 1
// [EXPECTED] Tier 30 total withdraw count: 0
// [EXPECTED] Tier 30 total collected amount: 0
// [EXPECTED] Tier 30 start time: 1235172690
// [EXPECTED] Tier 30 end time: 1237764690
//
// [INFO] Testing tier 90
// [EXPECTED] Tier 90 details:
// [EXPECTED] - ID: gno.land/r/onbloc/obl:123:90
// [EXPECTED] - Start Time: 1235172690
// [EXPECTED] - End Time: 1242948690
// [EXPECTED] Tier 90 distribute amount per second X128: 131281777361473172632474771385713044543
// [EXPECTED] Tier 90 total distribute amount: 3000000
// [EXPECTED] Tier 90 total deposit amount: 3000000
// [EXPECTED] Tier 90 total withdraw amount: 0
// [EXPECTED] Tier 90 total deposit count: 1
// [EXPECTED] Tier 90 total withdraw count: 0
// [EXPECTED] Tier 90 total collected amount: 0
// [EXPECTED] Tier 90 start time: 1235172690
// [EXPECTED] Tier 90 end time: 1242948690
//
// [INFO] Testing tier 180
// [EXPECTED] Tier 180 details:
// [EXPECTED] - ID: gno.land/r/onbloc/obl:123:180
// [EXPECTED] - Start Time: 1235172690
// [EXPECTED] - End Time: 1250724690
// [EXPECTED] Tier 180 distribute amount per second X128: 87521184907648781754983180923808696362
// [EXPECTED] Tier 180 total distribute amount: 4000000
// [EXPECTED] Tier 180 total deposit amount: 0
// [EXPECTED] Tier 180 total withdraw amount: 0
// [EXPECTED] Tier 180 total deposit count: 0
// [EXPECTED] Tier 180 total withdraw count: 0
// [EXPECTED] Tier 180 total collected amount: 0
// [EXPECTED] Tier 180 start time: 1235172690
// [EXPECTED] Tier 180 end time: 1250724690
//
// [SCENARIO] 4. Test Deposit Getters
// [INFO] Testing deposit getters
// [EXPECTED] Deposit count: 2
// [EXPECTED] Current deposit ID counter: 2
// [INFO] Testing deposit 1 getters
// [EXPECTED] Deposit 1 details:
// [EXPECTED] - ID: 1
// [EXPECTED] - Project ID: gno.land/r/onbloc/obl:123
// [EXPECTED] - Tier: 30
// [EXPECTED] - Amount: 2000000
// [EXPECTED] Deposit 1 project ID: gno.land/r/onbloc/obl:123
// [EXPECTED] Deposit 1 tier: 30
// [EXPECTED] Deposit 1 project tier ID: gno.land/r/onbloc/obl:123:30
// [EXPECTED] Deposit 1 amount: 2000000
// [EXPECTED] Deposit 1 withdrawn height: 0
// [EXPECTED] Deposit 1 withdrawn time: 0
// [EXPECTED] Deposit 1 created height: 121083
// [EXPECTED] Deposit 1 created at: 1235172690
// [EXPECTED] Deposit 1 end time: 1237764690
//
// [SCENARIO] 5. Test RewardManager Getters
// [INFO] Testing reward manager getters
// [EXPECTED] Reward manager count: 3
// [INFO] Testing reward manager for 30 day tier
// [EXPECTED] Reward manager details:
// [EXPECTED] - Total Distribute Amount: 3000000
// [EXPECTED] - Total Claimed Amount: 0
// [EXPECTED] Distribute amount per second X128: 393845332084419517897424314157139133629
// [EXPECTED] Accumulated reward per deposit X128: 0
// [EXPECTED] Total distribute amount: 3000000
// [EXPECTED] Total claimed amount: 0
// [EXPECTED] Distribute start time: 1235172690
// [EXPECTED] Distribute end time: 1237764690
// [EXPECTED] Accumulated distribute amount: 0
// [EXPECTED] Accumulated height: 0
// [EXPECTED] Accumulated time: 0
// [EXPECTED] Reward claimable duration: 259200
//
// [SCENARIO] 6. Test RewardState Getters
// [INFO] Testing reward state getters
// [EXPECTED] Reward state details:
// [EXPECTED] - Deposit Amount: 2000000
// [EXPECTED] - Accumulated Reward Amount: 0
// [EXPECTED] - Claimed Amount: 0
// [EXPECTED] - Claimable Time: 1235431890
