// launchpad pre-deposit reward refund: projects sharing the reward token
//
// Projects A and B distribute the same token from one launchpad balance.
// Refunding A, including its pre-deposit rewards, must not touch the rewards
// reserved for B, which is still running.
//
// - project A: alice to tier 30 at day 20 -> 3M, refund 27M
// - project B (starts at day 107 of A): bob to tier 30 at the start -> 9M,
//   carol to tier 180 at day 10 -> 11.33M, refund 9.67M

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

	aliceAddr   = testutils.TestAddress("alice")
	bobAddr     = testutils.TestAddress("bob")
	carolAddr   = testutils.TestAddress("carol")
	refundAAddr = testutils.TestAddress("refundA")
	refundBAddr = testutils.TestAddress("refundB")
)

func main(cur realm) {
	println("[SCENARIO] 1. Create project A")
	startTimeA := time.Now().Unix() + startDelay
	projectA := createProject(cur, "shared token A", startTimeA)

	println("[SCENARIO] 2. Alice deposits to A tier 30 at day 20")
	skipUntil(startTimeA + 20*daySeconds)
	aliceDepositID := depositGns(cur, aliceAddr, projectA+":30")

	println("[SCENARIO] 3. Create project B at day 100 of A")
	skipUntil(startTimeA + 100*daySeconds)
	startTimeB := time.Now().Unix() + startDelay
	projectB := createProject(cur, "shared token B", startTimeB)
	assertLaunchpadBalance("launchpad balance after creating B", projectA, projectB)

	println("[SCENARIO] 4. Bob deposits to B tier 30 at the start, Carol to B tier 180 at day 10")
	skipUntil(startTimeB)
	bobDepositID := depositGns(cur, bobAddr, projectB+":30")
	skipUntil(startTimeB + 10*daySeconds)
	carolDepositID := depositGns(cur, carolAddr, projectB+":180")

	println("[SCENARIO] 5. Refund A after it ends while B is running")
	skipUntil(startTimeA + 180*daySeconds + blockTime)
	refundedA := refundProject(cur, projectA, refundAAddr)
	assertRefund("A refund", tier30Amount*20/30+tier90Amount+tier180Amount, refundedA)
	assertLaunchpadBalance("launchpad balance after refunding A", projectA, projectB)

	println("[SCENARIO] 6. Alice and Bob collect while B is running")
	aliceReward := collectDepositGns(cur, aliceAddr, aliceDepositID)
	assertReward("A alice reward", tier30Amount*10/30, aliceReward)
	assertSettled("A settled", projectA, aliceReward+refundedA, tolerance)
	bobReward := collectDepositGns(cur, bobAddr, bobDepositID)
	assertReward("B bob reward", tier30Amount, bobReward)
	assertLaunchpadBalance("launchpad balance after A and B tier 30 collections", projectA, projectB)

	println("[SCENARIO] 7. Carol collects and B is refunded after B ends")
	skipUntil(startTimeB + 180*daySeconds + blockTime)
	carolReward := collectDepositGns(cur, carolAddr, carolDepositID)
	assertReward("B carol reward", tier180Amount*170/180, carolReward)
	refundedB := refundProject(cur, projectB, refundBAddr)
	assertRefund("B refund", tier90Amount+tier180Amount*10/180, refundedB)
	assertSettled("B settled", projectB, bobReward+carolReward+refundedB, 0)
	assertLaunchpadBalance("launchpad balance after every settlement", projectA, projectB)
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
// [SCENARIO] 1. Create project A
// [SCENARIO] 2. Alice deposits to A tier 30 at day 20
// [SCENARIO] 3. Create project B at day 100 of A
// [EXPECTED] launchpad balance after creating B: 60000000
// [SCENARIO] 4. Bob deposits to B tier 30 at the start, Carol to B tier 180 at day 10
// [SCENARIO] 5. Refund A after it ends while B is running
// [EXPECTED] A refund: 27000001 (exact 27000000)
// [EXPECTED] launchpad balance after refunding A: 32999999
// [SCENARIO] 6. Alice and Bob collect while B is running
// [EXPECTED] A alice reward: 2999999 (exact 3000000)
// [EXPECTED] A settled: paid 30000000 + left 0 = 30000000
// [EXPECTED] B bob reward: 8999999 (exact 9000000)
// [EXPECTED] launchpad balance after A and B tier 30 collections: 21000001
// [SCENARIO] 7. Carol collects and B is refunded after B ends
// [EXPECTED] B carol reward: 11333333 (exact 11333333)
// [EXPECTED] B refund: 9666668 (exact 9666666)
// [EXPECTED] B settled: paid 30000000 + left 0 = 30000000
// [EXPECTED] launchpad balance after every settlement: 0
