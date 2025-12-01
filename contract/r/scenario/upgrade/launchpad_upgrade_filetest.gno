// launchpad contract upgrade scenario test
package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/launchpad"
	"gno.land/r/onbloc/obl"

	_ "gno.land/r/gnoswap/launchpad/v1"
	_ "gno.land/r/gnoswap/launchpad/v3_valid"
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	launchpadV1Path   = "gno.land/r/gnoswap/launchpad/v1"
	launchpadTestPath = "gno.land/r/gnoswap/launchpad/v3_valid"
)

func main() {
	println("[SCENARIO] 1. Initialize launchpad contract with v1")
	initializeV1()
	println()

	println("[SCENARIO] 2. Create project with v1")
	projectId := createProject()
	println()

	println("[SCENARIO] 3. Verify project info with v1")
	verifyProjectInfo(projectId)
	println()

	println("[SCENARIO] 4. Upgrade launchpad contract to test version")
	testLaunchpadUpgrade()
	println()

	println("[SCENARIO] 5. Verify project info with v3 valid")
	verifyProjectInfo(projectId)
	println()
}

func initializeV1() {
	ufmt.Println("[INFO] Setting implementation to v1")
	testing.SetRealm(adminRealm)
	launchpad.UpgradeImpl(cross, launchpadV1Path)

	ufmt.Printf("[EXPECTED] launchpad upgraded to: %s\n", launchpadV1Path)
}

func createProject() string {
	testing.SetRealm(adminRealm)

	println("[INFO] Creating OBL launchpad project")

	recipientAddr := adminAddr
	projectName := "Test OBL Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	rewardAmount := int64(10_000_000)
	conditionPath := ""
	conditionsAmount := ""
	tier30Ratio := int64(30)
	tier90Ratio := int64(30)
	tier180Ratio := int64(40)
	startTime := int64(time.Now().Unix() + 3600) // 1 hour from now

	println("[INFO] Admin creating OBL project")
	testing.SetRealm(adminRealm)
	launchpadAddr := access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())
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

	println("[EXPECTED] Project created with ID:", projectId)

	return projectId
}

func testLaunchpadUpgrade() {
	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading launchpad contract to test version")
	testing.SetRealm(adminRealm)
	launchpad.UpgradeImpl(cross, launchpadTestPath)
	ufmt.Printf("[EXPECTED] launchpad upgraded to: %s\n", launchpadTestPath)
}

func verifyProjectInfo(projectId string) {
	testing.SetRealm(adminRealm)
	projectInfo := launchpad.ApiGetProjectAndTierStatisticsByProjectId(projectId)
	println("[EXPECTED] Project info:", projectInfo)
}

// Output:
// [SCENARIO] 1. Initialize launchpad contract with v1
// [INFO] Setting implementation to v1
// [EXPECTED] launchpad upgraded to: gno.land/r/gnoswap/launchpad/v1
//
// [SCENARIO] 2. Create project with v1
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [EXPECTED] Project created with ID: gno.land/r/onbloc/obl:123
//
// [SCENARIO] 3. Verify project info with v1
// [EXPECTED] Project info: {"height":"123","now":"1234567890","projectId":"gno.land/r/onbloc/obl:123","name":"Test OBL Project","tokenPath":"gno.land/r/onbloc/obl","depositAmount":"10000000","recipient":"g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5","conditionsToken":"","conditionsAmount":"","createdTime":"1234567890","startedTime":"1234571490","endedTime":"1250123490","refundedAmount":"10000000","tier30Id":"gno.land/r/onbloc/obl:123:259200","tier30TierAmount":"3000000","tier30TierAmountPerSecondX128":"393845332084419517897424314157139133629","tier30Started":"1234571490","tier30Ended":"1237163490","tier30TotalDepositAmount":"0","tier30ActualDepositAmount":"0","tier30TotalParticipant":"0","tier30ActualParticipant":"0","tier30UserCollectedAmount":"0","tier90Id":"gno.land/r/onbloc/obl:123:604800","tier90TierAmount":"3000000","tier90TierAmountPerSecondX128":"131281777361473172632474771385713044543","tier90Started":"1234571490","tier90Ended":"1242347490","tier90TotalDepositAmount":"0","tier90ActualDepositAmount":"0","tier90TotalParticipant":"0","tier90ActualParticipant":"0","tier90UserCollectedAmount":"0","tier180Id":"gno.land/r/onbloc/obl:123:1209600","tier180TierAmount":"4000000","tier180TierAmountPerSecondX128":"87521184907648781754983180923808696362","tier180Started":"1234571490","tier180Ended":"1250123490","tier180TotalDepositAmount":"0","tier180ActualDepositAmount":"0","tier180TotalParticipant":"0","tier180ActualParticipant":"0","tier180UserCollectedAmount":"0"}
//
// [SCENARIO] 4. Upgrade launchpad contract to test version
// [INFO] Upgrading launchpad contract to test version
// [EXPECTED] launchpad upgraded to: gno.land/r/gnoswap/launchpad/v3_valid
//
// [SCENARIO] 5. Verify project info with v3 valid
// [EXPECTED] Project info: {"height":"123","now":"1234567890","projectId":"gno.land/r/onbloc/obl:123","name":"Test OBL Project","tokenPath":"gno.land/r/onbloc/obl","depositAmount":"10000000","recipient":"g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5","conditionsToken":"","conditionsAmount":"","createdTime":"1234567890","startedTime":"1234571490","endedTime":"1250123490","refundedAmount":"10000000","tier30Id":"gno.land/r/onbloc/obl:123:259200","tier30TierAmount":"3000000","tier30TierAmountPerSecondX128":"393845332084419517897424314157139133629","tier30Started":"1234571490","tier30Ended":"1237163490","tier30TotalDepositAmount":"0","tier30ActualDepositAmount":"0","tier30TotalParticipant":"0","tier30ActualParticipant":"0","tier30UserCollectedAmount":"0","tier90Id":"gno.land/r/onbloc/obl:123:604800","tier90TierAmount":"3000000","tier90TierAmountPerSecondX128":"131281777361473172632474771385713044543","tier90Started":"1234571490","tier90Ended":"1242347490","tier90TotalDepositAmount":"0","tier90ActualDepositAmount":"0","tier90TotalParticipant":"0","tier90ActualParticipant":"0","tier90UserCollectedAmount":"0","tier180Id":"gno.land/r/onbloc/obl:123:1209600","tier180TierAmount":"4000000","tier180TierAmountPerSecondX128":"87521184907648781754983180923808696362","tier180Started":"1234571490","tier180Ended":"1250123490","tier180TotalDepositAmount":"0","tier180ActualDepositAmount":"0","tier180TotalParticipant":"0","tier180ActualParticipant":"0","tier180UserCollectedAmount":"0"}
