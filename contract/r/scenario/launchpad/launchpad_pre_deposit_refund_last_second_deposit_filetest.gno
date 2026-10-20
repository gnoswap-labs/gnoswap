// launchpad pre-deposit reward refund: first deposit right before the tier end
//
// A first deposit 5 seconds before the tier end earns only those 5 seconds of
// reward, and almost the whole tier reward is refunded. The reward is claimable
// at the tier end, and the withdrawal afterwards settles a zero reward.
//
// - tier 30: alice at end-5s -> 17 (9M * 5 / 2,592,000)
// - tier 90: bob at end-5s -> 5 (9M * 5 / 7,776,000)
// - tier 180: no deposit

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
	refundAddr = testutils.TestAddress("refund")
)

func main(cur realm) {
	startTime := time.Now().Unix() + startDelay
	endTime30 := startTime + 30*daySeconds
	endTime90 := startTime + 90*daySeconds

	println("[SCENARIO] 1. Create project")
	projectID := createProject(cur, "last second", startTime)

	println("[SCENARIO] 2. Alice makes the first deposit to tier 30 5 seconds before its end")
	skipUntil(endTime30 - blockTime)
	aliceDepositID := depositGns(cur, aliceAddr, projectID+":30")

	println("[SCENARIO] 3. Alice claims at the tier end")
	skipUntil(endTime30)
	aliceClaim := collectReward(cur, aliceAddr, aliceDepositID)
	assertReward("alice claim at the tier end", tier30Amount*blockTime/(30*daySeconds), aliceClaim)

	println("[SCENARIO] 4. Bob makes the first deposit to tier 90 5 seconds before its end")
	skipUntil(endTime90 - blockTime)
	bobDepositID := depositGns(cur, bobAddr, projectID+":90")

	println("[SCENARIO] 5. Withdraw after the project end")
	skipUntil(startTime + 180*daySeconds + blockTime)
	aliceReward := collectDepositGns(cur, aliceAddr, aliceDepositID)
	assertAmount("alice reward on withdrawal after the claim", 0, aliceReward)
	bobReward := collectDepositGns(cur, bobAddr, bobDepositID)
	assertReward("bob reward", tier90Amount*blockTime/(90*daySeconds), bobReward)

	println("[SCENARIO] 6. Refund the remaining reward")
	refunded := refundProject(cur, projectID, refundAddr)
	exactPaid := tier30Amount*blockTime/(30*daySeconds) + tier90Amount*blockTime/(90*daySeconds)
	assertRefund("refund", rewardAmount-exactPaid-2, refunded)
	assertSettled("project settled", projectID, aliceClaim+aliceReward+bobReward+refunded, 0)
	assertLaunchpadBalance("launchpad balance after settlement", projectID)
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
// [SCENARIO] 2. Alice makes the first deposit to tier 30 5 seconds before its end
// [SCENARIO] 3. Alice claims at the tier end
// [EXPECTED] alice claim at the tier end: 17 (exact 17)
// [SCENARIO] 4. Bob makes the first deposit to tier 90 5 seconds before its end
// [SCENARIO] 5. Withdraw after the project end
// [EXPECTED] alice reward on withdrawal after the claim: 0
// [EXPECTED] bob reward: 5 (exact 5)
// [SCENARIO] 6. Refund the remaining reward
// [EXPECTED] refund: 29999978 (exact 29999976)
// [EXPECTED] project settled: paid 30000000 + left 0 = 30000000
// [EXPECTED] launchpad balance after settlement: 0
