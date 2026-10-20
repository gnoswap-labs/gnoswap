// launchpad pre-deposit reward refund: many depositors at boundary times
//
// Tier 30 receives deposits before the start, in the same block, twice from
// the same user, and 5 seconds before the tier end. Because the first deposits
// are made before the start, no tier 30 reward is left unallocated.
//
// - tier 30: u0 (start-2d), u1 (start-1d), u2 and u3 (day 3, same block),
//   u4 (day 10 and day 15), u5 (end-5s)
// - tier 90: u0 at day 45 -> 4.5M, 4.5M refunded
// - tier 180: no deposit -> refunded

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

	u0Addr     = testutils.TestAddress("u0")
	u1Addr     = testutils.TestAddress("u1")
	u2Addr     = testutils.TestAddress("u2")
	u3Addr     = testutils.TestAddress("u3")
	u4Addr     = testutils.TestAddress("u4")
	u5Addr     = testutils.TestAddress("u5")
	refundAddr = testutils.TestAddress("refund")
)

func main(cur realm) {
	startTime := time.Now().Unix() + startDelay
	endTime30 := startTime + 30*daySeconds

	println("[SCENARIO] 1. Create project")
	projectID := createProject(cur, "many depositors", startTime)
	tier30ID := projectID + ":30"

	println("[SCENARIO] 2. Pre-start deposits")
	skipUntil(startTime - 2*daySeconds)
	u0DepositID := depositGns(cur, u0Addr, tier30ID)
	skipUntil(startTime - daySeconds)
	u1DepositID := depositGns(cur, u1Addr, tier30ID)

	println("[SCENARIO] 3. Same-block deposits at day 3")
	skipUntil(startTime + 3*daySeconds)
	u2DepositID := depositGns(cur, u2Addr, tier30ID)
	u3DepositID := depositGns(cur, u3Addr, tier30ID)

	println("[SCENARIO] 4. Two deposits from the same user at day 10 and day 15")
	skipUntil(startTime + 10*daySeconds)
	u4FirstDepositID := depositGns(cur, u4Addr, tier30ID)
	skipUntil(startTime + 15*daySeconds)
	u4SecondDepositID := depositGns(cur, u4Addr, tier30ID)

	println("[SCENARIO] 5. Deposit 5 seconds before the tier end")
	skipUntil(endTime30 - blockTime)
	u5DepositID := depositGns(cur, u5Addr, tier30ID)

	println("[SCENARIO] 6. u0 deposits to tier 90 at day 45")
	skipUntil(startTime + 45*daySeconds)
	u0Tier90DepositID := depositGns(cur, u0Addr, projectID+":90")

	println("[SCENARIO] 7. Refund after the project end before any withdrawal")
	skipUntil(startTime + 180*daySeconds + blockTime)
	refunded := refundProject(cur, projectID, refundAddr)
	assertRefund("refund", tier90Amount*45/90+tier180Amount, refunded)
	assertLaunchpadBalance("launchpad balance after refund", projectID)

	println("[SCENARIO] 8. Withdraw every deposit")
	// Exact rewards: tier 30 is shared by 2, 4, 5, 6, and 7 deposits over
	// [0, 3d), [3d, 10d), [10d, 15d), [15d, end-5s), and [end-5s, end).
	paid := refunded
	paid += assertWithdraw(cur, "u0 tier 30 reward", u0Addr, u0DepositID, 2_024_999)
	paid += assertWithdraw(cur, "u1 tier 30 reward", u1Addr, u1DepositID, 2_024_999)
	paid += assertWithdraw(cur, "u2 tier 30 reward", u2Addr, u2DepositID, 1_574_999)
	paid += assertWithdraw(cur, "u3 tier 30 reward", u3Addr, u3DepositID, 1_574_999)
	paid += assertWithdraw(cur, "u4 first tier 30 reward", u4Addr, u4FirstDepositID, 1_049_999)
	paid += assertWithdraw(cur, "u4 second tier 30 reward", u4Addr, u4SecondDepositID, 749_999)
	paid += assertWithdraw(cur, "u5 tier 30 reward", u5Addr, u5DepositID, 2)
	paid += assertWithdraw(cur, "u0 tier 90 reward", u0Addr, u0Tier90DepositID, tier90Amount*45/90)

	assertSettled("project settled", projectID, paid, tolerance)
	assertLaunchpadBalance("launchpad balance after withdrawals", projectID)
}

func assertWithdraw(cur realm, label string, depositor address, depositID string, expected int64) int64 {
	reward := collectDepositGns(cur, depositor, depositID)
	assertReward(label, expected, reward)

	return reward
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
// [SCENARIO] 2. Pre-start deposits
// [SCENARIO] 3. Same-block deposits at day 3
// [SCENARIO] 4. Two deposits from the same user at day 10 and day 15
// [SCENARIO] 5. Deposit 5 seconds before the tier end
// [SCENARIO] 6. u0 deposits to tier 90 at day 45
// [SCENARIO] 7. Refund after the project end before any withdrawal
// [EXPECTED] refund: 16500002 (exact 16500000)
// [EXPECTED] launchpad balance after refund: 13499998
// [SCENARIO] 8. Withdraw every deposit
// [EXPECTED] u0 tier 30 reward: 2024999 (exact 2024999)
// [EXPECTED] u1 tier 30 reward: 2024999 (exact 2024999)
// [EXPECTED] u2 tier 30 reward: 1574999 (exact 1574999)
// [EXPECTED] u3 tier 30 reward: 1574999 (exact 1574999)
// [EXPECTED] u4 first tier 30 reward: 1049999 (exact 1049999)
// [EXPECTED] u4 second tier 30 reward: 749999 (exact 749999)
// [EXPECTED] u5 tier 30 reward: 2 (exact 2)
// [EXPECTED] u0 tier 90 reward: 4499999 (exact 4500000)
// [EXPECTED] project settled: paid 29999997 + left 3 = 30000000
// [EXPECTED] launchpad balance after withdrawals: 3
