// launchpad pre-deposit reward refund: legacy project upgraded before its start
//
// A legacy project is upgraded before its start and then receives every
// deposit through the current implementation, side by side with a current
// project that has the same deposits.
//
// - tier 30: a deposit 1 day before the start -> 9M in both projects
// - tier 90: first deposit at day 30 -> 9M in A (legacy), 6M in C (current)
// - tier 180: no deposit -> refund A 12M, C 15M

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
	refundCAddr = testutils.TestAddress("refundC")
)

func main(cur realm) {
	println("[SCENARIO] 1. Create project A with the legacy implementation")
	upgradeImpl(cur, legacyPath)
	startTime := time.Now().Unix() + startDelay
	projectA := createProject(cur, "legacy A", startTime)

	println("[SCENARIO] 2. Upgrade and create project C with the same start time")
	upgradeImpl(cur, currentPath)
	testing.SkipHeights(1)
	projectC := createProject(cur, "current C", startTime)

	println("[SCENARIO] 3. Alice and Bob deposit to tier 30 1 day before the start")
	skipUntil(startTime - daySeconds)
	aliceDepositID := depositGns(cur, aliceAddr, projectA+":30")
	bobDepositID := depositGns(cur, bobAddr, projectC+":30")

	println("[SCENARIO] 4. Carol and Dave make the first deposit to tier 90 at day 30")
	skipUntil(startTime + 30*daySeconds)
	carolDepositID := depositGns(cur, carolAddr, projectA+":90")
	daveDepositID := depositGns(cur, daveAddr, projectC+":90")

	println("[SCENARIO] 5. Collect deposits after the projects end")
	skipUntil(startTime + 180*daySeconds + blockTime)
	aliceReward := collectDepositGns(cur, aliceAddr, aliceDepositID)
	assertReward("A pre-start reward", tier30Amount, aliceReward)
	bobReward := collectDepositGns(cur, bobAddr, bobDepositID)
	assertReward("C pre-start reward", tier30Amount, bobReward)
	carolReward := collectDepositGns(cur, carolAddr, carolDepositID)
	assertReward("A first deposit reward includes the pre-deposit period", tier90Amount, carolReward)
	daveReward := collectDepositGns(cur, daveAddr, daveDepositID)
	assertReward("C first deposit reward excludes the pre-deposit period", tier90Amount*60/90, daveReward)

	println("[SCENARIO] 6. Refund both projects")
	refundedA := refundProject(cur, projectA, refundAAddr)
	assertRefund("A refund", tier180Amount, refundedA)
	assertSettled("A settled", projectA, aliceReward+carolReward+refundedA, 0)

	refundedC := refundProject(cur, projectC, refundCAddr)
	assertRefund("C refund includes the pre-deposit period", tier90Amount*30/90+tier180Amount, refundedC)
	assertSettled("C settled", projectC, bobReward+daveReward+refundedC, 0)
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
// [SCENARIO] 1. Create project A with the legacy implementation
// [INFO] launchpad implementation: gno.land/r/gnoswap/launchpad/v1_legacy
// [SCENARIO] 2. Upgrade and create project C with the same start time
// [INFO] launchpad implementation: gno.land/r/gnoswap/launchpad/v1
// [SCENARIO] 3. Alice and Bob deposit to tier 30 1 day before the start
// [SCENARIO] 4. Carol and Dave make the first deposit to tier 90 at day 30
// [SCENARIO] 5. Collect deposits after the projects end
// [EXPECTED] A pre-start reward: 8999999 (exact 9000000)
// [EXPECTED] C pre-start reward: 8999999 (exact 9000000)
// [EXPECTED] A first deposit reward includes the pre-deposit period: 8999999 (exact 9000000)
// [EXPECTED] C first deposit reward excludes the pre-deposit period: 5999999 (exact 6000000)
// [SCENARIO] 6. Refund both projects
// [EXPECTED] A refund: 12000002 (exact 12000000)
// [EXPECTED] A settled: paid 30000000 + left 0 = 30000000
// [EXPECTED] C refund includes the pre-deposit period: 15000002 (exact 15000000)
// [EXPECTED] C settled: paid 30000000 + left 0 = 30000000
