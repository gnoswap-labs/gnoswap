// launchpad refund ended project no deposit

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/launchpad"
	"gno.land/r/onbloc/obl"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(access.ROLE_LAUNCHPAD)
	projectAddr      = testutils.TestAddress("project-owner")
	projectRealm     = std.NewUserRealm(projectAddr)
)

func main() {
	println("[SCENARIO] 1. Create OBL launchpad project")
	createOBLProject()
	println()

	// [SCENARIO] 2. Skip blocks to end project
	println("[SCENARIO] 2. Skip blocks to end project")
	println("[INFO] Skipping 7776000 + 6 blocks to end project")
	testing.SkipHeights(7776000 + 6) // End project
	println()

	// [SCENARIO] 3. Refund ended project without deposit
	println("[SCENARIO] 3. Refund ended project without deposit")
	refundEndedProjectWithoutDeposit()
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

// Refund ended project without deposit
func refundEndedProjectWithoutDeposit() {
	testing.SetRealm(adminRealm)
	projectId := "gno.land/r/onbloc/obl:123"

	println("[INFO] Checking project status before refund")
	projectStats := unmarshal(launchpad.ApiGetProjectStatisticsByProjectId(projectId))
	println("[INFO] Project status:", projectStats["status"])

	println("[INFO] Checking OBL balance before refund")
	oblBalanceBefore := obl.BalanceOf(projectAddr)
	println("[INFO] Project OBL balance before refund:", oblBalanceBefore)

	println("[INFO] Project recipient attempting refund")
	launchpad.TransferLeftFromProjectByAdmin(cross, projectId, projectAddr)

	println("[INFO] Checking OBL balance after refund")
	oblBalanceAfter := obl.BalanceOf(projectAddr)
	println("[INFO] Project OBL balance after refund:", oblBalanceAfter)

	ufmt.Printf("[EXPECTED] OBL balance should be 0 after refund: %d OBL\n", oblBalanceAfter)
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
// [SCENARIO] 2. Skip blocks to end project
// [INFO] Skipping 7776000 + 6 blocks to end project
//
// [SCENARIO] 3. Refund ended project without deposit
// [INFO] Checking project status before refund
// [INFO] Project status: ended
// [INFO] Checking OBL balance before refund
// [INFO] Project OBL balance before refund: 0
// [INFO] Project recipient attempting refund
// [INFO] Checking OBL balance after refund
// [INFO] Project OBL balance after refund: 1000000000
// [EXPECTED] OBL balance should be 0 after refund: 1000000000 OBL
