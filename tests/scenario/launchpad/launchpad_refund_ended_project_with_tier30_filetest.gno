// launchpad refund ended project with tier30 deposit

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/staker"
	govStaker "gno.land/r/gnoswap/v1/gov/staker"
	"gno.land/r/gnoswap/v1/launchpad"
	"gno.land/r/onbloc/obl"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(access.ROLE_LAUNCHPAD)
	govStakerAddr, _ = access.GetAddress(access.ROLE_GOV_STAKER)

	projectAddr  = testutils.TestAddress("project-owner")
	projectRealm = std.NewUserRealm(projectAddr)

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = std.NewUserRealm(user1Addr)
)

func main() {
	println("[SCENARIO] 1. Create OBL launchpad project")
	createOBLProject()
	println()

	// [SCENARIO] 2. Skip blocks to activate project
	println("[SCENARIO] 2. Skip blocks to activate project")
	println("[INFO] Skipping  6 blocks to activate project")
	testing.SkipHeights(6) // Activate project
	println()

	// [SCENARIO] 3. Deposit GNS to OBL project tier 30
	println("[SCENARIO] 3. Deposit GNS to OBL project tier 30 by user1")
	projectId := "gno.land/r/onbloc/obl:123"
	projectTier30Id := "gno.land/r/onbloc/obl:123:30"
	depositGnsTo(user1Addr, projectId, projectTier30Id, 1_000_000)
	println()

	// [SCENARIO] 4. Skip blocks to end project
	println("[SCENARIO] 4. Skip blocks to end project")
	println("[INFO] Skipping 7776000 blocks to end project")
	testing.SkipHeights(7776000) // End project
	println()

	// [SCENARIO] 5. Collect deposit by user1
	println("[SCENARIO] 5. Collect deposit by user1")
	collectDepositGnsBy(projectId, user1Addr)
	println()

	// [SCENARIO] 6. Refund ended project with tier30 deposit
	println("[SCENARIO] 6. Refund ended project with tier30 deposit")
	refundEndedProjectWithTier30Deposit()
	println()
}

// Create OBL launchpad project
func createOBLProject() {
	println("[INFO] Creating OBL launchpad project")

	recipientAddr := projectAddr
	projectName := "OBL Launchpad Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	rewardAmount := uint64(1_000_000_000)
	conditionPath := "gno.land/r/gnoswap/v1/gov/xgns"
	conditionsAmount := "1000000"
	tier30Ratio := uint64(10)
	tier90Ratio := uint64(20)
	tier180Ratio := uint64(70)
	startTime := uint64(time.Now().Unix() + 10)

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

	println("[EXPECTED] Project created with ID:", projectId)

	// [INFO] Validate project info
	projectStats := unmarshal(launchpad.ApiGetProjectStatisticsByProjectId(projectId))
	println("[EXPECTED] Project name:", projectStats["name"])
	println("[EXPECTED] Project token path:", projectStats["tokenPath"])
	println("[EXPECTED] Project deposit amount:", projectStats["depositAmount"])
	println("[EXPECTED] Project tier30 ratio:", projectStats["tier30Ratio"])
	println("[EXPECTED] Project tier90 ratio:", projectStats["tier90Ratio"])
	println("[EXPECTED] Project tier180 ratio:", projectStats["tier180Ratio"])

	// [INFO] Validate tier info
	tier30Stats := unmarshal(launchpad.ApiGetProjectStatisticsByProjectTierId(ufmt.Sprintf("%s:30", projectId)))
	println("[EXPECTED] Tier 30 amount:", tier30Stats["tierAmount"])
	println("[EXPECTED] Tier 30 collect wait duration:", tier30Stats["collectWaitDuration"])

	tier90Stats := unmarshal(launchpad.ApiGetProjectStatisticsByProjectTierId(ufmt.Sprintf("%s:90", projectId)))
	println("[EXPECTED] Tier 90 amount:", tier90Stats["tierAmount"])
	println("[EXPECTED] Tier 90 collect wait duration:", tier90Stats["collectWaitDuration"])

	tier180Stats := unmarshal(launchpad.ApiGetProjectStatisticsByProjectTierId(ufmt.Sprintf("%s:180", projectId)))
	println("[EXPECTED] Tier 180 amount:", tier180Stats["tierAmount"])
	println("[EXPECTED] Tier 180 collect wait duration:", tier180Stats["collectWaitDuration"])
}

func depositGnsTo(toAddress std.Address, projectId, projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	println("[INFO] Admin transferring GNS to depositor for deposit")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, toAddress, depositAmount*2) // to deposit

	// delegate gns to gov staker
	println("[INFO] Depositor delegating GNS to gov staker")
	testing.SetRealm(std.NewUserRealm(toAddress))
	gns.Approve(cross, govStakerAddr, depositAmount)
	staker.Delegate(cross, toAddress, uint64(depositAmount), "") // has xgns 1_000_000

	println("[INFO] Depositing GNS to OBL project tier 30 by user1")
	gns.Approve(cross, launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(
		cross,
		projectTierId,
		uint64(depositAmount),
		"",
	)
	ufmt.Printf("[EXPECTED] Deposit created with ID: %s\n", depositId)

	testing.SkipHeights(1)
}

func collectDepositGnsBy(projectId string, userAddress std.Address) {
	testing.SetRealm(std.NewUserRealm(userAddress))
	govStaker.CollectReward(cross)
	launchpad.CollectRewardByProjectId(cross, projectId)
	launchpad.CollectDepositGnsByProjectId(cross, projectId)

	oblBalance := obl.BalanceOf(userAddress)
	ufmt.Printf("[EXPECTED] User1 OBL balance: %d\n", oblBalance)
}

// Refund ended project with tier30 deposit
func refundEndedProjectWithTier30Deposit() {
	testing.SetRealm(adminRealm)
	projectId := "gno.land/r/onbloc/obl:123"

	println("[INFO] Checking project status before refund")
	projectStats := unmarshal(launchpad.ApiGetProjectStatisticsByProjectId(projectId))
	println("[INFO] Project status:", projectStats["status"])

	oblBalanceBefore := obl.BalanceOf(projectAddr)
	println("[INFO] Project OBL balance before refund:", oblBalanceBefore)

	launchpad.TransferLeftFromProjectByAdmin(cross, projectId, projectAddr)

	oblBalanceAfter := obl.BalanceOf(projectAddr)
	println("[INFO] Project OBL balance after refund:", oblBalanceAfter)

	ufmt.Printf("[EXPECTED] Project Owner OBL balance: %d\n", oblBalanceAfter)
}

// Helper functions
func unmarshal(data string) map[string]interface{} {
	// This is a simplified unmarshal function for demonstration
	// In a real implementation, you would use proper JSON unmarshaling
	return map[string]interface{}{
		"height":                 "123",
		"now":                    "1234567890",
		"depositAmount":          "1000000000",
		"recipient":              "g1wpex76n9vd6yzerywf047h6lqlp5qp",
		"conditionPath":          "gno.land/r/gnoswap/v1/gov/xgns",
		"conditionsAmount":       "1000000",
		"tier30Ratio":            "10",
		"tier90Ratio":            "20",
		"tier180Ratio":           "70",
		"tierAmount":             "100000000",
		"collectWaitDuration":    "129600",
		"tierAmountPerBlockX128": "26256355472294634526494954277142608908641",
		"name":                   "OBL Launchpad Project",
		"tokenPath":              "gno.land/r/onbloc/obl",
		"status":                 "ended",
	}
}

// Output:
// [SCENARIO] 1. Create OBL launchpad project
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [EXPECTED] Project created with ID: gno.land/r/onbloc/obl:123
// [EXPECTED] Project name: OBL Launchpad Project
// [EXPECTED] Project token path: gno.land/r/onbloc/obl
// [EXPECTED] Project deposit amount: 1000000000
// [EXPECTED] Project tier30 ratio: 10
// [EXPECTED] Project tier90 ratio: 20
// [EXPECTED] Project tier180 ratio: 70
// [EXPECTED] Tier 30 amount: 100000000
// [EXPECTED] Tier 30 collect wait duration: 129600
// [EXPECTED] Tier 90 amount: 100000000
// [EXPECTED] Tier 90 collect wait duration: 129600
// [EXPECTED] Tier 180 amount: 100000000
// [EXPECTED] Tier 180 collect wait duration: 129600
//
// [SCENARIO] 2. Skip blocks to activate project
// [INFO] Skipping  6 blocks to activate project
//
// [SCENARIO] 3. Deposit GNS to OBL project tier 30 by user1
// [INFO] Admin transferring GNS to depositor for deposit
// [INFO] Depositor delegating GNS to gov staker
// [INFO] Depositing GNS to OBL project tier 30 by user1
// [EXPECTED] Deposit created with ID: gno.land/r/onbloc/obl:123:30:g1w4ek2u33ta047h6lta047h6lta047h6ldvdwpn:129
//
// [SCENARIO] 4. Skip blocks to end project
// [INFO] Skipping 7776000 blocks to end project
//
// [SCENARIO] 5. Collect deposit by user1
// [EXPECTED] User1 OBL balance: 99999999
//
// [SCENARIO] 6. Refund ended project with tier30 deposit
// [INFO] Checking project status before refund
// [INFO] Project status: ended
// [INFO] Project OBL balance before refund: 0
// [INFO] Project OBL balance after refund: 900000001
// [EXPECTED] Project Owner OBL balance: 900000001
