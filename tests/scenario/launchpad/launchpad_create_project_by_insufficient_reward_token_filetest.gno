// launchpad create project by insufficient reward token

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/launchpad"
	"gno.land/r/onbloc/obl"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = std.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
)

func main() {
	// [SCENARIO] Init environment
	println("[SCENARIO] 1. Init environment")
	initEnvironment()
	println()

	// [SCENARIO] Admin attempts to create project with insufficient reward token
	println("[SCENARIO] 2. Admin attempts to create project with insufficient reward token")
	createProjectByInsufficientRewardToken()
	println()
}

func initEnvironment() {}

// Admin attempts to create project with insufficient reward token
func createProjectByInsufficientRewardToken() {
	testing.SetOriginCaller(adminAddr)

	oblBalance := obl.BalanceOf(adminAddr)

	projectName := "OBL Launchpad Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	recipientAddr := testutils.TestAddress("project-owner")
	rewardAmount := int64(oblBalance + 1)
	conditionPath := "gno.land/r/gnoswap/v1/gov/xgns"
	conditionsAmount := "1000000"
	tier30Ratio := int64(10)
	tier90Ratio := int64(20)
	tier180Ratio := int64(70)
	startTime := int64(time.Now().Unix() + 3600) // 1 hour

	println("[INFO] admin attempting to create project with insufficient reward token")
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

	expectedPanicMessage := "[GNOSWAP-LAUNCHPAD-010] insufficient balance || caller(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) balance(100000000000000) < depositAmount(100000000000001)"
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

	ufmt.Printf("[EXPECTED] Should abort with insufficient reward token error: %s\n", expectedPanicMessage)
}

// Output:
// [SCENARIO] 1. Init environment
//
// [SCENARIO] 2. Admin attempts to create project with insufficient reward token
// [INFO] admin attempting to create project with insufficient reward token
// [INFO] create project with project name: OBL Launchpad Project
// [INFO] create project with reward token path: gno.land/r/onbloc/obl
// [INFO] create project with recipient: g1wpex76n9vd6z6mmhdejhyh6lta047h6lwfg09t
// [INFO] create project with reward amount: 100000000000001
// [INFO] create project with conditions token: gno.land/r/gnoswap/v1/gov/xgns
// [INFO] create project with conditions amount: 1000000
// [INFO] create project with tier30 ratio: 10
// [INFO] create project with tier90 ratio: 20
// [INFO] create project with tier180 ratio: 70
// [INFO] create project with start time: 1234571490
// [EXPECTED] Should abort with insufficient reward token error: [GNOSWAP-LAUNCHPAD-010] insufficient balance || caller(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) balance(100000000000000) < depositAmount(100000000000001)
