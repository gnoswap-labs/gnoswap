// launchpad pre-deposit reward refund: pre-start and late deposits
//
// A pre-start deposit accrues from the tier start, so nothing is unallocated.
// A tier whose first deposit comes after the start refunds the earlier period.
//
// - tier 30: alice 1 day before the start, bob at day 15 -> 6.75M / 2.25M
// - tier 90: carol at day 45 -> 4.5M, 4.5M unallocated
// - tier 180: dave at project creation -> 12M

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac/v1"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	_ "gno.land/r/gnoswap/common/v1"
	_ "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac/v1"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	"gno.land/r/onbloc/obl"
)

const (
	blockTime  = int64(5)
	daySeconds = int64(24 * 60 * 60)
	startDelay = 7 * daySeconds
	oblPath    = "gno.land/r/onbloc/obl.OBL"

	rewardAmount  = int64(30_000_000)
	tier30Amount  = int64(9_000_000)  // 30%
	tier90Amount  = int64(9_000_000)  // 30%
	tier180Amount = int64(12_000_000) // 40%
	depositAmount = int64(1_000_000)
	tolerance     = int64(10)
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	projectAddr      = testutils.TestAddress("project")

	aliceAddr  = testutils.TestAddress("alice")
	bobAddr    = testutils.TestAddress("bob")
	carolAddr  = testutils.TestAddress("carol")
	daveAddr   = testutils.TestAddress("dave")
	refundAddr = testutils.TestAddress("refund")
)

func main(cur realm) {
	startTime := time.Now().Unix() + startDelay

	println("[SCENARIO] 1. Create project and Dave deposits to tier 180")
	projectID := createProject(cur, "pre-start deposit", startTime)
	daveDepositID := depositGns(cur, daveAddr, projectID+":180")

	println("[SCENARIO] 2. Alice deposits to tier 30 1 day before the start")
	skipUntil(startTime - daySeconds)
	aliceDepositID := depositGns(cur, aliceAddr, projectID+":30")

	println("[SCENARIO] 3. Bob deposits to tier 30 at day 15")
	skipUntil(startTime + 15*daySeconds)
	bobDepositID := depositGns(cur, bobAddr, projectID+":30")

	println("[SCENARIO] 4. Carol deposits to tier 90 at day 45")
	skipUntil(startTime + 45*daySeconds)
	carolDepositID := depositGns(cur, carolAddr, projectID+":90")

	println("[SCENARIO] 5. Collect deposits after the project end")
	skipUntil(startTime + 180*daySeconds + blockTime)
	aliceReward := collectDepositGns(cur, aliceAddr, aliceDepositID)
	assertReward("alice reward", tier30Amount*15/30+tier30Amount*15/30/2, aliceReward)
	bobReward := collectDepositGns(cur, bobAddr, bobDepositID)
	assertReward("bob reward", tier30Amount*15/30/2, bobReward)
	carolReward := collectDepositGns(cur, carolAddr, carolDepositID)
	assertReward("carol reward", tier90Amount*45/90, carolReward)
	daveReward := collectDepositGns(cur, daveAddr, daveDepositID)
	assertReward("dave reward", tier180Amount, daveReward)

	println("[SCENARIO] 6. Refund the remaining reward")
	refunded := refundProject(cur, projectID, refundAddr)
	assertRefund("refund", tier90Amount*45/90, refunded)
	assertSettled("project settled", projectID, aliceReward+bobReward+carolReward+daveReward+refunded, 0)
}

func skipUntil(targetTime int64) {
	now := time.Now().Unix()
	if targetTime <= now {
		panic(ufmt.Sprintf("target time %d is not after now %d", targetTime, now))
	}

	testing.SkipHeights((targetTime - now) / blockTime)
}

func createProject(cur realm, name string, startTime int64) string {
	testing.SetRealm(adminRealm)
	obl.Approve(cross(cur), launchpadAddr, rewardAmount)

	return launchpad.CreateProject(
		cross(cur),
		name,
		oblPath,
		projectAddr,
		rewardAmount,
		"",
		"",
		30,
		30,
		40,
		startTime,
	)
}

func depositGns(cur realm, depositor address, projectTierID string) string {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), depositor, depositAmount)

	testing.SetRealm(testing.NewUserRealm(depositor))
	gns.Approve(cross(cur), launchpadAddr, depositAmount)

	return launchpad.DepositGns(cross(cur), projectTierID, depositAmount, "")
}

// collectDepositGns withdraws the principal and returns the settled reward.
func collectDepositGns(cur realm, depositor address, depositID string) int64 {
	testing.SetRealm(testing.NewUserRealm(depositor))

	before := obl.BalanceOf(depositor)
	if _, err := launchpad.CollectDepositGns(cross(cur), depositID); err != nil {
		panic(err.Error())
	}

	return obl.BalanceOf(depositor) - before
}

func refundProject(cur realm, projectID string, recipient address) int64 {
	testing.SetRealm(adminRealm)

	before := obl.BalanceOf(recipient)
	refunded := launchpad.TransferLeftFromProjectByAdmin(cross(cur), projectID, recipient)
	assertEqual("refund transferred to recipient", refunded, obl.BalanceOf(recipient)-before)

	return refunded
}

// leftReward returns the project reward that is neither collected nor refunded.
func leftReward(projectID string) int64 {
	left := int64(0)
	for _, tier := range []int64{30, 90, 180} {
		distributed, err := launchpad.GetProjectTierTotalDistributeAmount(projectID, tier)
		if err != nil {
			panic(err.Error())
		}

		collected, err := launchpad.GetProjectTierTotalCollectedAmount(projectID, tier)
		if err != nil {
			panic(err.Error())
		}

		left += distributed - collected
	}

	return left
}

func assertEqual(label string, expected, actual int64) {
	if expected != actual {
		panic(ufmt.Sprintf("%s: expected %d, got %d", label, expected, actual))
	}
}

// assertReward checks a depositor reward, which is truncated below the exact amount.
func assertReward(label string, expected, actual int64) {
	if actual > expected || actual < expected-tolerance {
		panic(ufmt.Sprintf("%s: expected [%d, %d], got %d", label, expected-tolerance, expected, actual))
	}

	ufmt.Printf("[EXPECTED] %s: %d (exact %d)\n", label, actual, expected)
}

// assertRefund checks a refund, which includes the truncation dust of rewards.
func assertRefund(label string, expected, actual int64) {
	if actual < expected || actual > expected+tolerance {
		panic(ufmt.Sprintf("%s: expected [%d, %d], got %d", label, expected, expected+tolerance, actual))
	}

	ufmt.Printf("[EXPECTED] %s: %d (exact %d)\n", label, actual, expected)
}

// assertSettled checks that rewards, refunds, and the remaining amount add up
// to the project reward.
func assertSettled(label string, projectID string, paid int64, maxLeft int64) {
	left := leftReward(projectID)
	if left < 0 || left > maxLeft {
		panic(ufmt.Sprintf("%s: left reward %d exceeds %d", label, left, maxLeft))
	}

	assertEqual(label, rewardAmount, paid+left)
	ufmt.Printf("[EXPECTED] %s: paid %d + left %d = %d\n", label, paid, left, rewardAmount)
}

// Output:
// [SCENARIO] 1. Create project and Dave deposits to tier 180
// [SCENARIO] 2. Alice deposits to tier 30 1 day before the start
// [SCENARIO] 3. Bob deposits to tier 30 at day 15
// [SCENARIO] 4. Carol deposits to tier 90 at day 45
// [SCENARIO] 5. Collect deposits after the project end
// [EXPECTED] alice reward: 6749999 (exact 6750000)
// [EXPECTED] bob reward: 2249999 (exact 2250000)
// [EXPECTED] carol reward: 4499999 (exact 4500000)
// [EXPECTED] dave reward: 11999999 (exact 12000000)
// [SCENARIO] 6. Refund the remaining reward
// [EXPECTED] refund: 4500004 (exact 4500000)
// [EXPECTED] project settled: paid 30000000 + left 0 = 30000000
