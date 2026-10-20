// launchpad pre-deposit reward refund: legacy and current projects across an upgrade
//
// Projects created by the legacy implementation keep paying the pre-deposit
// period to the first depositor after the upgrade. A project created by the
// current implementation refunds it.
//
// - project A (legacy): alice at day 10 (legacy), carol at day 20 (current)
//   -> 7.5M / 1.5M, refund 21M
// - project B (legacy): bob first deposit at day 10 (current) -> 9M, refund 21M
// - project C (current): dave at day 10 -> 6M, refund 24M

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
	_ "gno.land/r/gnoswap/launchpad/v1_legacy"
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

	legacyPath  = "gno.land/r/gnoswap/launchpad/v1_legacy"
	currentPath = "gno.land/r/gnoswap/launchpad/v1"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	projectAddr      = testutils.TestAddress("project")

	aliceAddr   = testutils.TestAddress("alice")
	bobAddr     = testutils.TestAddress("bob")
	carolAddr   = testutils.TestAddress("carol")
	daveAddr    = testutils.TestAddress("dave")
	refundAAddr = testutils.TestAddress("refundA")
	refundBAddr = testutils.TestAddress("refundB")
	refundCAddr = testutils.TestAddress("refundC")
)

func main(cur realm) {
	println("[SCENARIO] 1. Create projects A and B with the legacy implementation")
	upgradeImpl(cur, legacyPath)
	startTime := time.Now().Unix() + startDelay
	projectA := createProject(cur, "legacy A", startTime)
	testing.SkipHeights(1)
	projectB := createProject(cur, "legacy B", startTime)

	println("[SCENARIO] 2. Alice deposits to A tier 30 at day 10 with the legacy implementation")
	skipUntil(startTime + 10*daySeconds)
	aliceDepositID := depositGns(cur, aliceAddr, projectA+":30")

	println("[SCENARIO] 3. Upgrade to the current implementation")
	upgradeImpl(cur, currentPath)

	println("[SCENARIO] 4. Bob makes the first deposit to B tier 30 at day 10")
	bobDepositID := depositGns(cur, bobAddr, projectB+":30")

	println("[SCENARIO] 5. Create project C with the current implementation")
	startTimeC := time.Now().Unix() + startDelay
	projectC := createProject(cur, "current C", startTimeC)

	println("[SCENARIO] 6. Carol deposits to A tier 30 at day 20")
	skipUntil(startTime + 20*daySeconds)
	carolDepositID := depositGns(cur, carolAddr, projectA+":30")

	println("[SCENARIO] 7. Dave deposits to C tier 30 at day 10 of C")
	skipUntil(startTimeC + 10*daySeconds)
	daveDepositID := depositGns(cur, daveAddr, projectC+":30")

	println("[SCENARIO] 8. Collect deposits after every project ends")
	skipUntil(startTimeC + 180*daySeconds + blockTime)
	aliceReward := collectDepositGns(cur, aliceAddr, aliceDepositID)
	assertReward("A alice reward includes the pre-deposit period", tier30Amount*20/30+tier30Amount*10/30/2, aliceReward)
	carolReward := collectDepositGns(cur, carolAddr, carolDepositID)
	assertReward("A carol reward", tier30Amount*10/30/2, carolReward)
	bobReward := collectDepositGns(cur, bobAddr, bobDepositID)
	assertReward("B bob reward includes the pre-deposit period", tier30Amount, bobReward)
	daveReward := collectDepositGns(cur, daveAddr, daveDepositID)
	assertReward("C dave reward excludes the pre-deposit period", tier30Amount*20/30, daveReward)

	println("[SCENARIO] 9. Refund every project")
	refundedA := refundProject(cur, projectA, refundAAddr)
	assertRefund("A refund", tier90Amount+tier180Amount, refundedA)
	assertSettled("A settled", projectA, aliceReward+carolReward+refundedA, 0)

	refundedB := refundProject(cur, projectB, refundBAddr)
	assertRefund("B refund", tier90Amount+tier180Amount, refundedB)
	assertSettled("B settled", projectB, bobReward+refundedB, 0)

	refundedC := refundProject(cur, projectC, refundCAddr)
	assertRefund("C refund includes the pre-deposit period", tier30Amount*10/30+tier90Amount+tier180Amount, refundedC)
	assertSettled("C settled", projectC, daveReward+refundedC, 0)
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

func upgradeImpl(cur realm, packagePath string) {
	testing.SetRealm(adminRealm)
	launchpad.UpgradeImpl(cross(cur), packagePath)
	println("[INFO] launchpad implementation:", launchpad.GetImplementationPackagePath())
}

// Output:
// [SCENARIO] 1. Create projects A and B with the legacy implementation
// [INFO] launchpad implementation: gno.land/r/gnoswap/launchpad/v1_legacy
// [SCENARIO] 2. Alice deposits to A tier 30 at day 10 with the legacy implementation
// [SCENARIO] 3. Upgrade to the current implementation
// [INFO] launchpad implementation: gno.land/r/gnoswap/launchpad/v1
// [SCENARIO] 4. Bob makes the first deposit to B tier 30 at day 10
// [SCENARIO] 5. Create project C with the current implementation
// [SCENARIO] 6. Carol deposits to A tier 30 at day 20
// [SCENARIO] 7. Dave deposits to C tier 30 at day 10 of C
// [SCENARIO] 8. Collect deposits after every project ends
// [EXPECTED] A alice reward includes the pre-deposit period: 7499999 (exact 7500000)
// [EXPECTED] A carol reward: 1499999 (exact 1500000)
// [EXPECTED] B bob reward includes the pre-deposit period: 8999999 (exact 9000000)
// [EXPECTED] C dave reward excludes the pre-deposit period: 5999999 (exact 6000000)
// [SCENARIO] 9. Refund every project
// [EXPECTED] A refund: 21000002 (exact 21000000)
// [EXPECTED] A settled: paid 30000000 + left 0 = 30000000
// [EXPECTED] B refund: 21000001 (exact 21000000)
// [EXPECTED] B settled: paid 30000000 + left 0 = 30000000
// [EXPECTED] C refund includes the pre-deposit period: 24000001 (exact 24000000)
// [EXPECTED] C settled: paid 30000000 + left 0 = 30000000
