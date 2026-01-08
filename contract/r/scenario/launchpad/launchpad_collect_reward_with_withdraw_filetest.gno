// launchpad collect reward with withdraw test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

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
	launchpadRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/launchpad")

	userAddr  = testutils.TestAddress("user1")
	userRealm = testing.NewUserRealm(userAddr)

	projectAddr  = testutils.TestAddress("project1")
	projectRealm = testing.NewUserRealm(projectAddr)

	blockTime = int64(5)
)

var t *testing.T

func main() {
	println("[SCENARIO] 1. Create launchpad project")
	projectId := createOBLProject()
	projectTier30 := projectId + ":30"
	println()

	println("[SCENARIO] 2. Deposit GNS in project tier30 with skip 3 days")
	testing.SkipHeights(60 * 60 * 24 * 3 / blockTime) // 3 days
	depositGns(projectTier30, 1_000_000)
	println()

	println("[SCENARIO] 3. Skip blocks to end project (27 days)")
	testing.SkipHeights(60 * 60 * 24 * 27 / blockTime) // 27 days
	testing.SkipHeights(1)                             // 1 block to pass collect wait duration
	println()

	println("[SCENARIO] 4. Withdraw GNS")
	collectDepositGns("1")
	println()
}

// Create OBL launchpad project
func createOBLProject() string {
	println("[INFO] Creating OBL launchpad project")

	recipientAddr := projectAddr
	projectName := "Test OBL Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	rewardAmount := int64(10_000_000)
	conditionPath := ""
	conditionsAmount := ""
	tier30Ratio := int64(30)
	tier90Ratio := int64(30)
	tier180Ratio := int64(40)
	secondsOf7Days := int64(60 * 60 * 24 * 7)
	startTime := time.Now().Unix() + secondsOf7Days // 7 days from now

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

	ufmt.Printf("[INFO] Skipping %d blocks to activate project\n", secondsOf7Days/blockTime)
	testing.SkipHeights(secondsOf7Days / blockTime)

	println("[EXPECTED] Project created with ID:", projectId)
	return projectId
}

func depositGns(projectTierId string, depositAmount int64) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, userAddr, depositAmount)

	// Deposit GNS
	testing.SetRealm(userRealm)
	gns.Approve(cross, launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(cross, projectTierId, depositAmount, "")

	ufmt.Printf("[EXPECTED] Deposit GNS in project tier %s (ID: %s)\n", projectTierId, depositId)
}

func collectDepositGns(depositId string) {
	testing.SetRealm(userRealm)

	beforeOblBalance := obl.BalanceOf(userAddr)
	beforeGnsBalance := gns.BalanceOf(userAddr)
	launchpad.CollectDepositGns(cross, depositId)
	afterOblBalance := obl.BalanceOf(userAddr)
	afterGnsBalance := gns.BalanceOf(userAddr)

	ufmt.Printf("[EXPECTED] OBL balance after collect: %d\n", afterOblBalance-beforeOblBalance)
	ufmt.Printf("[EXPECTED] GNS balance after collect: %d\n", afterGnsBalance-beforeGnsBalance)
}

// Output:
// [SCENARIO] 1. Create launchpad project
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [INFO] Skipping 120960 blocks to activate project
// [EXPECTED] Project created with ID: gno.land/r/onbloc/obl:123
//
// [SCENARIO] 2. Deposit GNS in project tier30 with skip 3 days
// [EXPECTED] Deposit GNS in project tier gno.land/r/onbloc/obl:123:30 (ID: 1)
//
// [SCENARIO] 3. Skip blocks to end project (27 days)
//
// [SCENARIO] 4. Withdraw GNS
// [EXPECTED] OBL balance after collect: 2999999
// [EXPECTED] GNS balance after collect: 1000000
