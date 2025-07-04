// launchpad create project by non admin

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/launchpad"
	"gno.land/r/onbloc/obl"
)

var t *testing.T

var (
	nonAdminAddr  = testutils.TestAddress("non-admin")
	nonAdminRealm = std.NewUserRealm(nonAdminAddr)

	launchpadAddr, _ = access.GetAddress(access.ROLE_LAUNCHPAD)
)

func main() {
	// [SCENARIO] Init environment
	println("[SCENARIO] 1. Init environment")
	initEnvironment()
	println()

	// [SCENARIO] Non-admin user attempts to create project
	println("[SCENARIO] 2. Non-admin user attempts to create project")
	createProjectByNonAdmin()
	println()
}

func initEnvironment() {}

// Non-admin user attempts to create project
func createProjectByNonAdmin() {
	testing.SetOriginCaller(nonAdminAddr)

	projectName := "OBL Launchpad Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	recipientAddr := testutils.TestAddress("project-owner")
	rewardAmount := uint64(1_000_000_000)
	conditionPath := "gno.land/r/gnoswap/v1/gov/xgns"
	conditionsAmount := "1000000"
	tier30Ratio := uint64(10)
	tier90Ratio := uint64(20)
	tier180Ratio := uint64(70)
	startTime := uint64(time.Now().Unix() + 10)

	println("[INFO] non-admin attempting to create project")
	println("[INFO] create project with project name:", projectName)
	println("[INFO] create project with reward token path:", rewardTokenPath)
	println("[INFO] create project with recipient:", recipientAddr)
	println("[INFO] create project with reward amount:", rewardAmount)
	println("[INFO] create project with conditions token:", conditionPath)
	println("[INFO] create project with conditions amount:", conditionsAmount)
	println("[INFO] create project with tier30 ratio:", tier30Ratio)
	println("[INFO] create project with tier90 ratio:", tier90Ratio)
	println("[INFO] create project with tier180 ratio:", tier180Ratio)
	println("[INFO] create project with start time:", startTime)

	testing.SetRealm(nonAdminRealm)
	obl.Approve(cross, launchpadAddr, int64(rewardAmount))

	expectedPanicMessage := "[GNOSWAP-LAUNCHPAD-002] invalid address || caller(g1dehkuttpv3kkjmjlta047h6lta047h6lj8fjdj) is not authorized for role admin"
	uassert.AbortsWithMessage(t, expectedPanicMessage, func() {
		launchpad.CreateProject(
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
	})

	ufmt.Printf("[EXPECTED] Should abort with authorization error: %s\n", expectedPanicMessage)
}

// Output:
// [SCENARIO] 1. Init environment
//
// [SCENARIO] 2. Non-admin user attempts to create project
// [INFO] non-admin attempting to create project
// [INFO] create project with project name: OBL Launchpad Project
// [INFO] create project with reward token path: gno.land/r/onbloc/obl
// [INFO] create project with recipient: g1wpex76n9vd6z6mmhdejhyh6lta047h6lwfg09t
// [INFO] create project with reward amount: 1000000000
// [INFO] create project with conditions token: gno.land/r/gnoswap/v1/gov/xgns
// [INFO] create project with conditions amount: 1000000
// [INFO] create project with tier30 ratio: 10
// [INFO] create project with tier90 ratio: 20
// [INFO] create project with tier180 ratio: 70
// [INFO] create project with start time: 1234567900
// [EXPECTED] Should abort with authorization error: [GNOSWAP-LAUNCHPAD-002] invalid address || caller(g1dehkuttpv3kkjmjlta047h6lta047h6lj8fjdj) is not authorized for role admin
