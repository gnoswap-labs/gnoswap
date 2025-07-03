// launchpad create project by invalid condition token

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
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(access.ROLE_LAUNCHPAD)
)

func main() {
	// [SCENARIO] Init environment
	println("[SCENARIO] 1. Init environment")
	initEnvironment()
	println()

	// [SCENARIO] Admin attempts to create project with invalid condition token
	println("[SCENARIO] 2. Admin attempts to create project with invalid condition token")
	createProjectByInvalidConditionToken()
	println()
}

func initEnvironment() {}

// Admin attempts to create project with invalid condition token
func createProjectByInvalidConditionToken() {
	testing.SetOriginCaller(adminAddr)

	projectName := "OBL Launchpad Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	recipientAddr := testutils.TestAddress("project-owner")
	rewardAmount := uint64(1_000_000_000)
	conditionPath := "gno.land/r/gnoswap/v1/gov/xgns*PAD*"
	conditionsAmount := "1000000*PAD*0"
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

	testing.SetRealm(adminRealm)
	obl.Approve(cross, launchpadAddr, int64(rewardAmount))

	expectedPanicMessage := "[GNOSWAP-LAUNCHPAD-007] invalid input data || invalid token()"

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

	ufmt.Printf("[EXPECTED] Should abort with input data error: %s\n", expectedPanicMessage)
}

// Output:
// [SCENARIO] 1. Init environment
//
// [SCENARIO] 2. Admin attempts to create project with invalid condition token
// [INFO] non-admin attempting to create project
// [INFO] create project with project name: OBL Launchpad Project
// [INFO] create project with reward token path: gno.land/r/onbloc/obl
// [INFO] create project with recipient: g1wpex76n9vd6z6mmhdejhyh6lta047h6lwfg09t
// [INFO] create project with reward amount: 1000000000
// [INFO] create project with conditions token: gno.land/r/gnoswap/v1/gov/xgns*PAD*
// [INFO] create project with conditions amount: 1000000*PAD*0
// [INFO] create project with tier30 ratio: 10
// [INFO] create project with tier90 ratio: 20
// [INFO] create project with tier180 ratio: 70
// [INFO] create project with start time: 1234567900
// [EXPECTED] Should abort with input data error: [GNOSWAP-LAUNCHPAD-007] invalid input data || invalid token()
