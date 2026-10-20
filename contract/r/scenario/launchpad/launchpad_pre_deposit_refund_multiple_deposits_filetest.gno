// launchpad pre-deposit reward refund: multiple deposits, refund before withdrawal
//
// The admin refund runs after the project ends but before any withdrawal, so
// active deposit rewards stay reserved and only unallocated rewards are refunded.
//
// - tier 30: alice at day 10, bob at day 20 -> 4.5M / 1.5M, 3M unallocated
// - tier 90: carol and dave at day 30 -> 3M / 3M, 3M unallocated
// - tier 180: no deposit -> 12M unallocated

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

	println("[SCENARIO] 1. Create project")
	projectID := createProject(cur, "multiple deposits", startTime)

	println("[SCENARIO] 2. Alice deposits to tier 30 at day 10")
	skipUntil(startTime + 10*daySeconds)
	aliceDepositID := depositGns(cur, aliceAddr, projectID+":30")

	println("[SCENARIO] 3. Bob deposits to tier 30 at day 20")
	skipUntil(startTime + 20*daySeconds)
	bobDepositID := depositGns(cur, bobAddr, projectID+":30")

	println("[SCENARIO] 4. Carol and Dave deposit to tier 90 at day 30")
	skipUntil(startTime + 30*daySeconds)
	carolDepositID := depositGns(cur, carolAddr, projectID+":90")
	daveDepositID := depositGns(cur, daveAddr, projectID+":90")

	println("[SCENARIO] 5. Refund after the project end before any withdrawal")
	skipUntil(startTime + 180*daySeconds + blockTime)
	refunded := refundProject(cur, projectID, refundAddr)
	assertRefund("refund keeps active rewards reserved", tier30Amount*10/30+tier90Amount*30/90+tier180Amount, refunded)

	println("[SCENARIO] 6. Collect deposits after the refund")
	aliceReward := collectDepositGns(cur, aliceAddr, aliceDepositID)
	assertReward("alice reward", tier30Amount*10/30+tier30Amount*10/30/2, aliceReward)
	bobReward := collectDepositGns(cur, bobAddr, bobDepositID)
	assertReward("bob reward", tier30Amount*10/30/2, bobReward)
	carolReward := collectDepositGns(cur, carolAddr, carolDepositID)
	assertReward("carol reward", tier90Amount*60/90/2, carolReward)
	daveReward := collectDepositGns(cur, daveAddr, daveDepositID)
	assertReward("dave reward", tier90Amount*60/90/2, daveReward)

	assertSettled("project settled", projectID, aliceReward+bobReward+carolReward+daveReward+refunded, tolerance)
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
// [SCENARIO] 1. Create project
// [SCENARIO] 2. Alice deposits to tier 30 at day 10
// [SCENARIO] 3. Bob deposits to tier 30 at day 20
// [SCENARIO] 4. Carol and Dave deposit to tier 90 at day 30
// [SCENARIO] 5. Refund after the project end before any withdrawal
// [EXPECTED] refund keeps active rewards reserved: 18000002 (exact 18000000)
// [SCENARIO] 6. Collect deposits after the refund
// [EXPECTED] alice reward: 4499999 (exact 4500000)
// [EXPECTED] bob reward: 1499999 (exact 1500000)
// [EXPECTED] carol reward: 2999999 (exact 3000000)
// [EXPECTED] dave reward: 2999999 (exact 3000000)
// [EXPECTED] project settled: paid 29999998 + left 2 = 30000000
