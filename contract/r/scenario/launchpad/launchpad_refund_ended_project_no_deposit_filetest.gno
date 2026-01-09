// launchpad refund ended project no deposit

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/onbloc/obl"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	launchpadRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/launchpad")

	projectAddr  = testutils.TestAddress("project-owner")
	projectRealm = testing.NewUserRealm(projectAddr)
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
	rewardAmount := int64(1_000_000_000)
	conditionPath := "gno.land/r/gnoswap/gov/xgns"
	conditionsAmount := "1000000"
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

// Refund ended project without deposit
func refundEndedProjectWithoutDeposit() {
	projectId := "gno.land/r/onbloc/obl:123"

	testing.SetRealm(launchpadRealm)
	println("[INFO] Checking project status before refund")
	isActive, _ := launchpad.GetProjectActiveStatus(projectId)
	if isActive {
		println("[INFO] Project status: active")
	} else {
		println("[INFO] Project status: ended")
	}

	testing.SetRealm(adminRealm)
	println("[INFO] Checking OBL balance before refund")
	oblBalanceBefore := obl.BalanceOf(projectAddr)
	println("[INFO] Project OBL balance before refund:", oblBalanceBefore)

	println("[INFO] Project recipient attempting refund")
	launchpad.TransferLeftFromProjectByAdmin(cross, projectId, projectAddr)

	println("[INFO] Checking OBL balance after refund")
	oblBalanceAfter := obl.BalanceOf(projectAddr)
	println("[INFO] Project OBL balance after refund:", oblBalanceAfter)

	println("[EXPECTED] OBL balance after refund:", oblBalanceAfter)
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
// [EXPECTED] OBL balance after refund: 1000000000
