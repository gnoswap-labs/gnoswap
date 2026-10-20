// launchpad pre-deposit reward refund: reward claims during the tier
//
// Rewards claimed during the tier and the admin refund before withdrawal must
// not double count each other.
//
// - tier 30: alice at day 5, bob at day 10
//   alice claims at day 12 and 20, bob claims at day 15, both withdraw after the end
//   -> alice 4.5M, bob 3M, 1.5M refunded
// - tier 90, tier 180: no deposit -> refunded

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

	println("[SCENARIO] 1. Create project")
	projectID := createProject(cur, "claims", startTime)

	println("[SCENARIO] 2. Alice deposits at day 5, Bob at day 10")
	skipUntil(startTime + 5*daySeconds)
	aliceDepositID := depositGns(cur, aliceAddr, projectID+":30")
	skipUntil(startTime + 10*daySeconds)
	bobDepositID := depositGns(cur, bobAddr, projectID+":30")

	println("[SCENARIO] 3. Claim rewards during the tier")
	skipUntil(startTime + 12*daySeconds)
	aliceClaim1 := collectReward(cur, aliceAddr, aliceDepositID)
	assertNear("alice claim at day 12", tier30Amount*5/30+tier30Amount*2/30/2, aliceClaim1)
	skipUntil(startTime + 15*daySeconds)
	bobClaim := collectReward(cur, bobAddr, bobDepositID)
	assertNear("bob claim at day 15", tier30Amount*5/30/2, bobClaim)
	skipUntil(startTime + 20*daySeconds)
	aliceClaim2 := collectReward(cur, aliceAddr, aliceDepositID)
	assertNear("alice claim at day 20", tier30Amount*8/30/2, aliceClaim2)

	println("[SCENARIO] 4. Refund after the project end before any withdrawal")
	skipUntil(startTime + 180*daySeconds + blockTime)
	refunded := refundProject(cur, projectID, refundAddr)
	assertRefund("refund", tier30Amount*5/30+tier90Amount+tier180Amount, refunded)
	assertLaunchpadBalance("launchpad balance after refund", projectID)

	println("[SCENARIO] 5. Withdraw after the refund")
	aliceReward := collectDepositGns(cur, aliceAddr, aliceDepositID)
	assertNear("alice reward on withdrawal", tier30Amount*10/30/2, aliceReward)
	bobReward := collectDepositGns(cur, bobAddr, bobDepositID)
	assertNear("bob reward on withdrawal", tier30Amount*15/30/2, bobReward)

	assertReward("alice total reward", tier30Amount*5/30+tier30Amount*20/30/2, aliceClaim1+aliceClaim2+aliceReward)
	assertReward("bob total reward", tier30Amount*20/30/2, bobClaim+bobReward)
	assertSettled("project settled", projectID, aliceClaim1+aliceClaim2+aliceReward+bobClaim+bobReward+refunded, tolerance)
	assertLaunchpadBalance("launchpad balance after withdrawals", projectID)
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
// [SCENARIO] 2. Alice deposits at day 5, Bob at day 10
// [SCENARIO] 3. Claim rewards during the tier
// [EXPECTED] alice claim at day 12: 1799999 (exact 1800000)
// [EXPECTED] bob claim at day 15: 749999 (exact 750000)
// [EXPECTED] alice claim at day 20: 1200000 (exact 1200000)
// [SCENARIO] 4. Refund after the project end before any withdrawal
// [EXPECTED] refund: 22500001 (exact 22500000)
// [EXPECTED] launchpad balance after refund: 3750001
// [SCENARIO] 5. Withdraw after the refund
// [EXPECTED] alice reward on withdrawal: 1500000 (exact 1500000)
// [EXPECTED] bob reward on withdrawal: 2250000 (exact 2250000)
// [EXPECTED] alice total reward: 4499999 (exact 4500000)
// [EXPECTED] bob total reward: 2999999 (exact 3000000)
// [EXPECTED] project settled: paid 29999999 + left 1 = 30000000
// [EXPECTED] launchpad balance after withdrawals: 1
