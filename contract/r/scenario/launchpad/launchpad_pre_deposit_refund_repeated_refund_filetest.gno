// launchpad pre-deposit reward refund: repeated refunds drain only the remaining dust
//
// The first refund runs before withdrawal and keeps active rewards reserved.
// After every withdrawal, a second refund returns only the remaining truncation
// dust, and a further refund is rejected.
//
// - tier 30: alice at day 10, bob at day 20 -> 4.5M / 1.5M
// - tier 90: carol at day 45 -> 4.5M
// - tier 180: no deposit

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac/v1"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
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
	t *testing.T

	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	projectAddr      = testutils.TestAddress("project")

	aliceAddr  = testutils.TestAddress("alice")
	bobAddr    = testutils.TestAddress("bob")
	carolAddr  = testutils.TestAddress("carol")
	refundAddr = testutils.TestAddress("refund")
)

func main(cur realm) {
	startTime := time.Now().Unix() + startDelay

	println("[SCENARIO] 1. Create project")
	projectID := createProject(cur, "repeated refund", startTime)

	println("[SCENARIO] 2. Deposits after the start")
	skipUntil(startTime + 10*daySeconds)
	aliceDepositID := depositGns(cur, aliceAddr, projectID+":30")
	skipUntil(startTime + 20*daySeconds)
	bobDepositID := depositGns(cur, bobAddr, projectID+":30")
	skipUntil(startTime + 45*daySeconds)
	carolDepositID := depositGns(cur, carolAddr, projectID+":90")

	println("[SCENARIO] 3. First refund before any withdrawal")
	skipUntil(startTime + 180*daySeconds + blockTime)
	firstRefund := refundProject(cur, projectID, refundAddr)
	assertRefund("first refund", tier30Amount*10/30+tier90Amount*45/90+tier180Amount, firstRefund)
	assertLaunchpadBalance("launchpad balance after the first refund", projectID)

	println("[SCENARIO] 4. Withdraw every deposit")
	aliceReward := collectDepositGns(cur, aliceAddr, aliceDepositID)
	assertReward("alice reward", tier30Amount*10/30+tier30Amount*10/30/2, aliceReward)
	bobReward := collectDepositGns(cur, bobAddr, bobDepositID)
	assertReward("bob reward", tier30Amount*10/30/2, bobReward)
	carolReward := collectDepositGns(cur, carolAddr, carolDepositID)
	assertReward("carol reward", tier90Amount*45/90, carolReward)
	paid := firstRefund + aliceReward + bobReward + carolReward
	assertSettled("project settled before the second refund", projectID, paid, tolerance)

	println("[SCENARIO] 5. Second refund returns the remaining dust")
	dust := leftReward(projectID)
	ufmt.Printf("[INFO] remaining dust: %d\n", dust)
	if dust > 0 {
		secondRefund := refundProject(cur, projectID, refundAddr)
		assertAmount("second refund", dust, secondRefund)
		paid += secondRefund
	}
	assertSettled("project settled after the second refund", projectID, paid, 0)
	assertLaunchpadBalance("launchpad balance after the second refund", projectID)

	println("[SCENARIO] 6. A further refund is rejected")
	uassert.AbortsContains(t, cur, "project has no remaining amount", func() {
		refundProject(cur, projectID, refundAddr)
	})
	println("[EXPECTED] further refund rejected")
	assertLaunchpadBalance("launchpad balance after the rejected refund", projectID)
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

// collectReward collects the claimable reward without withdrawing the principal.
func collectReward(cur realm, depositor address, depositID string) int64 {
	testing.SetRealm(testing.NewUserRealm(depositor))

	before := obl.BalanceOf(depositor)
	collected := launchpad.CollectRewardByDepositId(cross(cur), depositID)
	assertEqual("collected reward transferred to depositor", collected, obl.BalanceOf(depositor)-before)

	return collected
}

func assertAmount(label string, expected, actual int64) {
	assertEqual(label, expected, actual)
	ufmt.Printf("[EXPECTED] %s: %d\n", label, actual)
}

// assertNear checks an intermediate claim, which can differ from the exact
// amount by the truncation of the previous claim.
func assertNear(label string, expected, actual int64) {
	if actual < expected-tolerance || actual > expected+tolerance {
		panic(ufmt.Sprintf("%s: expected %d +/- %d, got %d", label, expected, tolerance, actual))
	}

	ufmt.Printf("[EXPECTED] %s: %d (exact %d)\n", label, actual, expected)
}

// assertLaunchpadBalance checks that the launchpad holds exactly the reward
// that is neither collected nor refunded across the given projects.
func assertLaunchpadBalance(label string, projectIDs ...string) {
	left := int64(0)
	for _, projectID := range projectIDs {
		left += leftReward(projectID)
	}

	assertEqual(label, left, obl.BalanceOf(launchpadAddr))
	ufmt.Printf("[EXPECTED] %s: %d\n", label, left)
}

// Output:
// [SCENARIO] 1. Create project
// [SCENARIO] 2. Deposits after the start
// [SCENARIO] 3. First refund before any withdrawal
// [EXPECTED] first refund: 19500002 (exact 19500000)
// [EXPECTED] launchpad balance after the first refund: 10499998
// [SCENARIO] 4. Withdraw every deposit
// [EXPECTED] alice reward: 4499999 (exact 4500000)
// [EXPECTED] bob reward: 1499999 (exact 1500000)
// [EXPECTED] carol reward: 4499999 (exact 4500000)
// [EXPECTED] project settled before the second refund: paid 29999999 + left 1 = 30000000
// [SCENARIO] 5. Second refund returns the remaining dust
// [INFO] remaining dust: 1
// [EXPECTED] second refund: 1
// [EXPECTED] project settled after the second refund: paid 30000000 + left 0 = 30000000
// [EXPECTED] launchpad balance after the second refund: 0
// [SCENARIO] 6. A further refund is rejected
// [EXPECTED] further refund rejected
// [EXPECTED] launchpad balance after the rejected refund: 0
