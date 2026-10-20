// launchpad deposits before start in every tier, then admin refund leaves only dust

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
	println("[SCENARIO] 1. Create project with 10/20/70 tier ratios")
	projectID, startTime := createProject(cur, 10, 20, 70)
	println()

	println("[SCENARIO] 2. One depositor per tier before tier start")
	aliceDepositID := depositGns(cur, aliceAddr, projectID+":30", depositUnit)
	bobDepositID := depositGns(cur, bobAddr, projectID+":90", depositUnit)
	charlieDepositID := depositGns(cur, charlieAddr, projectID+":180", depositUnit)
	println()

	println("[SCENARIO] 3. Skip until after the 180-day tier end and withdraw all")
	skipTo(startTime + tier180Seconds + blockTime)
	_, aliceReward := withdrawDeposit(cur, aliceAddr, aliceDepositID)
	_, bobReward := withdrawDeposit(cur, bobAddr, bobDepositID)
	_, charlieReward := withdrawDeposit(cur, charlieAddr, charlieDepositID)
	println()

	println("[SCENARIO] 4. Each sole depositor took its whole tier reward")
	assertEqual("Alice 30-day tier reward", rewardAmount/10-1, aliceReward)
	assertEqual("Bob 90-day tier reward", rewardAmount/5-1, bobReward)
	assertEqual("Charlie 180-day tier reward", rewardAmount*7/10-1, charlieReward)
	println()

	println("[SCENARIO] 5. Admin refund returns only the truncation dust")
	testing.SetRealm(adminRealm)
	refunded := launchpad.TransferLeftFromProjectByAdmin(cross(cur), projectID, projectAddr)
	assertEqual("refunded dust", rewardAmount-aliceReward-bobReward-charlieReward, refunded)
	assertEqual("launchpad OBL balance", 0, obl.BalanceOf(launchpadAddr))
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
// [SCENARIO] 1. Create project with 10/20/70 tier ratios
// [INFO] project created: id=gno.land/r/onbloc/obl.OBL:123, startTime=now+604800
//
// [SCENARIO] 2. One depositor per tier before tier start
// [INFO] deposit created: id=1, tier=gno.land/r/onbloc/obl.OBL:123:30, amount=1000000
// [INFO] deposit created: id=2, tier=gno.land/r/onbloc/obl.OBL:123:90, amount=1000000
// [INFO] deposit created: id=3, tier=gno.land/r/onbloc/obl.OBL:123:180, amount=1000000
//
// [SCENARIO] 3. Skip until after the 180-day tier end and withdraw all
// [INFO] deposit 1: GNS withdrawn=1000000, reward collected=99999999
// [INFO] deposit 2: GNS withdrawn=1000000, reward collected=199999999
// [INFO] deposit 3: GNS withdrawn=1000000, reward collected=699999999
//
// [SCENARIO] 4. Each sole depositor took its whole tier reward
// [EXPECTED] Alice 30-day tier reward: 99999999
// [EXPECTED] Bob 90-day tier reward: 199999999
// [EXPECTED] Charlie 180-day tier reward: 699999999
//
// [SCENARIO] 5. Admin refund returns only the truncation dust
// [EXPECTED] refunded dust: 3
// [EXPECTED] launchpad OBL balance: 0
