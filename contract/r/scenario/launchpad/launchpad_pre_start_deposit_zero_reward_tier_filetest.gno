// launchpad deposit before tier start is rejected for a zero-reward tier

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac/v1"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	_ "gno.land/r/gnoswap/rbac/v1"

	"gno.land/r/gnoswap/access/v1"
	_ "gno.land/r/gnoswap/common/v1"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	"gno.land/r/onbloc/obl"
)

var t *testing.T

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
	println("[SCENARIO] 1. Create project with the whole reward in the 30-day tier (100/0/0)")
	projectID, startTime := createProject(cur, 100, 0, 0)
	println()

	println("[SCENARIO] 2. Pre-start deposits into the zero-reward 90-day and 180-day tiers are rejected")
	assertDepositRejected(cur, aliceAddr, projectID+":90")
	skipTo(startTime - blockTime)
	assertDepositRejected(cur, bobAddr, projectID+":180")
	assertEqual("launchpad total staked GNS", 0, launchpad.GetTotalGNSStakedAmount())
	println()

	println("[SCENARIO] 3. The funded 30-day tier still accepts a pre-start deposit")
	charlieDepositID := depositGns(cur, charlieAddr, projectID+":30", depositUnit)
	println()

	println("[SCENARIO] 4. Deposits into the zero-reward tiers are still rejected after start")
	skipTo(startTime + dayTime)
	assertDepositRejected(cur, aliceAddr, projectID+":90")
	println()

	println("[SCENARIO] 5. Charlie withdraws after the 30-day tier end")
	skipTo(startTime + tier30Seconds + blockTime)
	gnsAmount, reward := withdrawDeposit(cur, charlieAddr, charlieDepositID)
	assertEqual("GNS principal returned", depositUnit, gnsAmount)
	assertEqual("Charlie reward", rewardAmount-1, reward)
	println()

	println("[SCENARIO] 6. Admin refund after the project end is not blocked by the zero-reward tiers")
	skipTo(startTime + tier180Seconds + blockTime)
	testing.SetRealm(adminRealm)
	refunded := launchpad.TransferLeftFromProjectByAdmin(cross(cur), projectID, projectAddr)
	assertEqual("refunded dust", rewardAmount-reward, refunded)
	assertEqual("launchpad OBL balance", 0, obl.BalanceOf(launchpadAddr))
}

func assertDepositRejected(cur realm, userAddr address, projectTierID string) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), userAddr, depositUnit)
	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross(cur), launchpadAddr, depositUnit)

	uassert.AbortsContains(t, cur, "[GNOSWAP-LAUNCHPAD-001] no left reward || ("+projectTierID+")", func() {
		testing.SetRealm(testing.NewUserRealm(userAddr))
		launchpad.DepositGns(cross(cur), projectTierID, depositUnit, "")
	})
	ufmt.Printf("[EXPECTED] deposit rejected: tier=%s\n", projectTierID)

	// The rejected deposit keeps the caller's GNS; return it so the next check starts clean.
	assertEqual("caller GNS balance kept", depositUnit, gns.BalanceOf(userAddr))
	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Transfer(cross(cur), adminAddr, depositUnit)
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
// [SCENARIO] 1. Create project with the whole reward in the 30-day tier (100/0/0)
// [INFO] project created: id=gno.land/r/onbloc/obl.OBL:123, startTime=now+604800
//
// [SCENARIO] 2. Pre-start deposits into the zero-reward 90-day and 180-day tiers are rejected
// [EXPECTED] deposit rejected: tier=gno.land/r/onbloc/obl.OBL:123:90
// [EXPECTED] caller GNS balance kept: 1000000
// [EXPECTED] deposit rejected: tier=gno.land/r/onbloc/obl.OBL:123:180
// [EXPECTED] caller GNS balance kept: 1000000
// [EXPECTED] launchpad total staked GNS: 0
//
// [SCENARIO] 3. The funded 30-day tier still accepts a pre-start deposit
// [INFO] deposit created: id=1, tier=gno.land/r/onbloc/obl.OBL:123:30, amount=1000000
//
// [SCENARIO] 4. Deposits into the zero-reward tiers are still rejected after start
// [EXPECTED] deposit rejected: tier=gno.land/r/onbloc/obl.OBL:123:90
// [EXPECTED] caller GNS balance kept: 1000000
//
// [SCENARIO] 5. Charlie withdraws after the 30-day tier end
// [INFO] deposit 1: GNS withdrawn=1000000, reward collected=999999999
// [EXPECTED] GNS principal returned: 1000000
// [EXPECTED] Charlie reward: 999999999
//
// [SCENARIO] 6. Admin refund after the project end is not blocked by the zero-reward tiers
// [EXPECTED] refunded dust: 1
// [EXPECTED] launchpad OBL balance: 0
