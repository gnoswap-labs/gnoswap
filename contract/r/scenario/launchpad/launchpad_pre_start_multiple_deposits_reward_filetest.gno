// launchpad multiple deposits before tier start share rewards from the start time

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

	println("[SCENARIO] 2. Three deposits at different times before tier start")
	aliceDepositID := depositGns(cur, aliceAddr, tierID, depositUnit)
	skipTo(startTime - dayTime)
	bobDepositID := depositGns(cur, bobAddr, tierID, 2*depositUnit)
	skipTo(startTime - blockTime)
	charlieDepositID := depositGns(cur, charlieAddr, tierID, depositUnit)
	println()

	println("[SCENARIO] 3. Collect at tier start + 1 day (first claimable time)")
	skipTo(startTime + dayTime)
	aliceFirst := collectReward(cur, aliceAddr, aliceDepositID)
	bobFirst := collectReward(cur, bobAddr, bobDepositID)
	charlieFirst := collectReward(cur, charlieAddr, charlieDepositID)
	// One day of a 30-day tier split 1:2:1 regardless of deposit time.
	dayReward := rewardAmount / 30
	assertEqual("Alice first-day reward (25%)", dayReward/4, aliceFirst)
	assertEqual("Bob first-day reward (50%)", dayReward/2, bobFirst)
	assertEqual("Charlie first-day reward (25%)", dayReward/4, charlieFirst)
	println()

	println("[SCENARIO] 4. Skip until after the tier end and withdraw all")
	skipTo(startTime + tier30Seconds + blockTime)
	_, aliceRest := withdrawDeposit(cur, aliceAddr, aliceDepositID)
	_, bobRest := withdrawDeposit(cur, bobAddr, bobDepositID)
	_, charlieRest := withdrawDeposit(cur, charlieAddr, charlieDepositID)
	println()

	println("[SCENARIO] 5. Validate total rewards split 1:2:1 from the tier start")
	assertEqual("Alice total reward (25%)", rewardAmount/4-1, aliceFirst+aliceRest)
	assertEqual("Bob total reward (50%)", rewardAmount/2-1, bobFirst+bobRest)
	assertEqual("Charlie total reward (25%)", rewardAmount/4-1, charlieFirst+charlieRest)
	collected, _ := launchpad.GetProjectTierTotalCollectedAmount(projectID, 30)
	assertEqual("tier collected amount", aliceFirst+aliceRest+bobFirst+bobRest+charlieFirst+charlieRest, collected)
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
// [SCENARIO] 2. Three deposits at different times before tier start
// [INFO] deposit created: id=1, tier=gno.land/r/onbloc/obl.OBL:123:30, amount=1000000
// [INFO] deposit created: id=2, tier=gno.land/r/onbloc/obl.OBL:123:30, amount=2000000
// [INFO] deposit created: id=3, tier=gno.land/r/onbloc/obl.OBL:123:30, amount=1000000
//
// [SCENARIO] 3. Collect at tier start + 1 day (first claimable time)
// [INFO] deposit 1: reward collected=8333333
// [INFO] deposit 2: reward collected=16666666
// [INFO] deposit 3: reward collected=8333333
// [EXPECTED] Alice first-day reward (25%): 8333333
// [EXPECTED] Bob first-day reward (50%): 16666666
// [EXPECTED] Charlie first-day reward (25%): 8333333
//
// [SCENARIO] 4. Skip until after the tier end and withdraw all
// [INFO] deposit 1: GNS withdrawn=1000000, reward collected=241666666
// [INFO] deposit 2: GNS withdrawn=2000000, reward collected=483333333
// [INFO] deposit 3: GNS withdrawn=1000000, reward collected=241666666
//
// [SCENARIO] 5. Validate total rewards split 1:2:1 from the tier start
// [EXPECTED] Alice total reward (25%): 249999999
// [EXPECTED] Bob total reward (50%): 499999999
// [EXPECTED] Charlie total reward (25%): 249999999
// [EXPECTED] tier collected amount: 999999997
