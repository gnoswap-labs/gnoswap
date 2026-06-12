// PKGPATH: gno.land/r/gnoswap/v1/main

// launchpad contract upgrade scenario test
package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"

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

func main(cur realm) {
	println("[SCENARIO] 1. Initialize launchpad contract with v1")
	initializeV1(cur)
	println()

	println("[SCENARIO] 2. Create project with v1")
	projectId := createProject(cur)
	println()

	println("[SCENARIO] 3. Verify project info with v1")
	verifyProjectInfo(cur, projectId)
	println()

	println("[SCENARIO] 4. Upgrade launchpad contract to test version")
	testLaunchpadUpgrade(cur)
	println()

	println("[SCENARIO] 5. Verify project info with v3 valid")
	verifyProjectInfo(cur, projectId)
	println()
}

func initializeV1(cur realm) {
	ufmt.Println("[INFO] Setting implementation to v1")
	testing.SetRealm(adminRealm)
	launchpad.UpgradeImpl(cross(cur), launchpadV1Path)

	ufmt.Printf("[EXPECTED] launchpad upgraded to: %s\n", launchpadV1Path)
}

func createProject(cur realm) string {
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
	startTime := int64(time.Now().Unix() + 604800) // 7 days from now

	println("[INFO] Admin creating OBL project")
	testing.SetRealm(adminRealm)
	launchpadAddr := access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())
	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	projectId := launchpad.CreateProject(
		cross(cur),
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

func testLaunchpadUpgrade(cur realm) {
	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading launchpad contract to test version")
	testing.SetRealm(adminRealm)
	launchpad.UpgradeImpl(cross(cur), launchpadTestPath)
	ufmt.Printf("[EXPECTED] launchpad upgraded to: %s\n", launchpadTestPath)
}

func verifyProjectInfo(cur realm, projectId string) {
	testing.SetRealm(adminRealm)
	projectInfo, _ := launchpad.GetProject(projectId)
	ufmt.Printf("[EXPECTED] Project ID: %s\n", projectInfo.ID())
	ufmt.Printf("[EXPECTED] Project name: %s\n", projectInfo.Name())
	ufmt.Printf("[EXPECTED] Project info: %s\n", projectInfo.TokenPath())
	ufmt.Printf("[EXPECTED] Project deposit amount: %d\n", projectInfo.DepositAmount())
	ufmt.Printf("[EXPECTED] Project recipient: %s\n", projectInfo.Recipient())
	ufmt.Printf("[EXPECTED] Project created height: %d\n", projectInfo.CreatedHeight())
	ufmt.Printf("[EXPECTED] Project created time: %d\n", projectInfo.CreatedAt())
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
// [EXPECTED] Project ID: gno.land/r/onbloc/obl:123
// [EXPECTED] Project name: Test OBL Project
// [EXPECTED] Project info: gno.land/r/onbloc/obl
// [EXPECTED] Project deposit amount: 10000000
// [EXPECTED] Project recipient: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [EXPECTED] Project created height: 123
// [EXPECTED] Project created time: 1234567890
//
// [SCENARIO] 4. Upgrade launchpad contract to test version
// [INFO] Upgrading launchpad contract to test version
// [EXPECTED] launchpad upgraded to: gno.land/r/gnoswap/launchpad/v3_valid
//
// [SCENARIO] 5. Verify project info with v3 valid
// [EXPECTED] Project ID: gno.land/r/onbloc/obl:123
// [EXPECTED] Project name: Test OBL Project
// [EXPECTED] Project info: gno.land/r/onbloc/obl
// [EXPECTED] Project deposit amount: 10000000
// [EXPECTED] Project recipient: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [EXPECTED] Project created height: 123
// [EXPECTED] Project created time: 1234567890
