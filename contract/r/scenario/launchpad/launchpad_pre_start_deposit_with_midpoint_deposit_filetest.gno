// launchpad deposit before tier start plus a deposit at the tier midpoint

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac/v1"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	_ "gno.land/r/gnoswap/rbac/v1"

	"gno.land/r/gnoswap/access/v1"
	_ "gno.land/r/gnoswap/common/v1"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	"gno.land/r/onbloc/obl"
)

const (
	blockTime         = int64(5)
	dayTime           = int64(24 * 60 * 60)
	activationSeconds = int64(7) * dayTime
	tier30Seconds     = int64(30) * dayTime
	tier180Seconds    = int64(180) * dayTime
	rewardAmount      = int64(1_000_000_000)
	depositUnit       = int64(1_000_000)
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	projectAddr      = testutils.TestAddress("pre-start-project")

	aliceAddr   = testutils.TestAddress("alice")
	bobAddr     = testutils.TestAddress("bob")
	charlieAddr = testutils.TestAddress("charlie")
)

func main(cur realm) {
	println("[SCENARIO] 1. Create project with the whole reward in the 30-day tier")
	projectID, startTime := createProject(cur, 100, 0, 0)
	tierID := projectID + ":30"
	println()

	println("[SCENARIO] 2. Alice deposits before tier start")
	aliceDepositID := depositGns(cur, aliceAddr, tierID, depositUnit)
	println()

	println("[SCENARIO] 3. Bob deposits the same amount at the tier midpoint")
	skipTo(startTime + tier30Seconds/2)
	bobDepositID := depositGns(cur, bobAddr, tierID, depositUnit)
	println()

	println("[SCENARIO] 4. Skip until after the tier end and withdraw both")
	skipTo(startTime + tier30Seconds + blockTime)
	_, aliceReward := withdrawDeposit(cur, aliceAddr, aliceDepositID)
	_, bobReward := withdrawDeposit(cur, bobAddr, bobDepositID)
	println()

	println("[SCENARIO] 5. Validate distribution: Alice 100% for the first half + 50% for the second half")
	// Alice: 1/2 + 1/4 = 75%, Bob: 25%, each minus Q128 truncation dust.
	assertEqual("Alice reward (75%)", rewardAmount*3/4-1, aliceReward)
	assertEqual("Bob reward (25%)", rewardAmount/4-1, bobReward)
	collected, _ := launchpad.GetProjectTierTotalCollectedAmount(projectID, 30)
	assertEqual("tier collected amount", aliceReward+bobReward, collected)
}

func createProject(cur realm, tier30Ratio, tier90Ratio, tier180Ratio int64) (string, int64) {
	startTime := time.Now().Unix() + activationSeconds

	testing.SetRealm(adminRealm)
	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	projectID := launchpad.CreateProject(
		cross(cur),
		"Pre Start Deposit Project",
		"gno.land/r/onbloc/obl.OBL",
		projectAddr,
		rewardAmount,
		"",
		"",
		tier30Ratio,
		tier90Ratio,
		tier180Ratio,
		startTime,
	)
	ufmt.Printf("[INFO] project created: id=%s, startTime=now+%d\n", projectID, activationSeconds)
	return projectID, startTime
}

func depositGns(cur realm, userAddr address, projectTierID string, amount int64) string {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), userAddr, amount)

	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross(cur), launchpadAddr, amount)
	depositID := launchpad.DepositGns(cross(cur), projectTierID, amount, "")
	ufmt.Printf("[INFO] deposit created: id=%s, tier=%s, amount=%d\n", depositID, projectTierID, amount)
	return depositID
}

func collectReward(cur realm, userAddr address, depositID string) int64 {
	testing.SetRealm(testing.NewUserRealm(userAddr))
	reward := launchpad.CollectRewardByDepositId(cross(cur), depositID)
	ufmt.Printf("[INFO] deposit %s: reward collected=%d\n", depositID, reward)
	return reward
}

func withdrawDeposit(cur realm, userAddr address, depositID string) (int64, int64) {
	testing.SetRealm(testing.NewUserRealm(userAddr))
	oblBefore := obl.BalanceOf(userAddr)
	gnsAmount, _ := launchpad.CollectDepositGns(cross(cur), depositID)
	reward := obl.BalanceOf(userAddr) - oblBefore
	ufmt.Printf("[INFO] deposit %s: GNS withdrawn=%d, reward collected=%d\n", depositID, gnsAmount, reward)
	return gnsAmount, reward
}

func skipTo(targetTime int64) {
	testing.SkipHeights((targetTime - time.Now().Unix()) / blockTime)
}

func assertEqual(label string, expected, actual int64) {
	if expected != actual {
		panic(ufmt.Sprintf("%s: expected %d, got %d", label, expected, actual))
	}
	ufmt.Printf("[EXPECTED] %s: %d\n", label, actual)
}

// Output:
// [SCENARIO] 1. Create project with the whole reward in the 30-day tier
// [INFO] project created: id=gno.land/r/onbloc/obl.OBL:123, startTime=now+604800
//
// [SCENARIO] 2. Alice deposits before tier start
// [INFO] deposit created: id=1, tier=gno.land/r/onbloc/obl.OBL:123:30, amount=1000000
//
// [SCENARIO] 3. Bob deposits the same amount at the tier midpoint
// [INFO] deposit created: id=2, tier=gno.land/r/onbloc/obl.OBL:123:30, amount=1000000
//
// [SCENARIO] 4. Skip until after the tier end and withdraw both
// [INFO] deposit 1: GNS withdrawn=1000000, reward collected=749999999
// [INFO] deposit 2: GNS withdrawn=1000000, reward collected=249999999
//
// [SCENARIO] 5. Validate distribution: Alice 100% for the first half + 50% for the second half
// [EXPECTED] Alice reward (75%): 749999999
// [EXPECTED] Bob reward (25%): 249999999
// [EXPECTED] tier collected amount: 999999998
