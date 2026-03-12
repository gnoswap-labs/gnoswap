// launchpad refund stale reward gap
//
// Repro intent:
// 1) Keep an active tier-180 deposit until project end.
// 2) Create a long gap with no deposit/collect/withdraw updates.
// 3) Admin refunds left rewards first.
// 4) Depositor then tries CollectDepositGns (which internally collects reward first).
//
// On vulnerable code, admin can over-refund and step (4) may abort by insufficient reward balance.
// On fixed code, step (4) succeeds and depositor receives both reward and GNS withdrawal.
//
// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee/v1"

	_ "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	"gno.land/r/onbloc/obl"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

	aliceAddr = testutils.TestAddress("alice")

	projectAddr = testutils.TestAddress("project-owner")
)

const (
	projectID      = "gno.land/r/onbloc/obl:123"
	projectTier180 = "gno.land/r/onbloc/obl:123:180"
	totalReward    = int64(1_000_000_000)
	depositAmount  = int64(1_000_000)
)

func main() {
	println("[SCENARIO] 1. Create project and activate")
	createProjectAndActivate()
	println()

	println("[SCENARIO] 2. Alice deposits to tier-180")
	depositToTier180(aliceAddr, depositAmount)
	println()

	println("[SCENARIO] 3. Skip to project end with no reward update events")
	println("[INFO] Creating stale reward-manager gap: no collect/withdraw between deposit and refund")
	testing.SkipHeights(7776000)
	println()

	println("[SCENARIO] 4. Admin refunds remaining rewards first")
	adminRefundToProjectRecipient(projectID)
	println()

	println("[SCENARIO] 5. Alice collects deposit (reward+GNS in one flow)")
	collectDepositAndAssertSuccess(aliceAddr, "1")
	println()
}

func createProjectAndActivate() {
	testing.SetRealm(adminRealm)
	obl.Approve(cross, launchpadAddr, totalReward)

	createdID := launchpad.CreateProject(
		cross,
		"OBL Launchpad Project",
		"gno.land/r/onbloc/obl",
		projectAddr,
		totalReward,
		"",
		"",
		10,
		20,
		70,
		time.Now().Unix()+604800,
	)

	println("[INFO] Created project:", createdID)
	testing.SkipHeights(120960)
}

func depositToTier180(depositor address, amount int64) {
	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, depositor, amount)

	testing.SetRealm(testing.NewUserRealm(depositor))
	gns.Approve(cross, launchpadAddr, amount)
	depositID := launchpad.DepositGns(cross, projectTier180, amount, "")
	println("[INFO] Deposit ID:", depositID)

	testing.SkipHeights(1)
}

func adminRefundToProjectRecipient(id string) {
	testing.SetRealm(adminRealm)

	launchpadBefore := obl.BalanceOf(launchpadAddr)
	recipientBefore := obl.BalanceOf(projectAddr)

	launchpad.TransferLeftFromProjectByAdmin(cross, id, projectAddr)

	launchpadAfter := obl.BalanceOf(launchpadAddr)
	recipientAfter := obl.BalanceOf(projectAddr)

	ufmt.Printf("[INFO] Launchpad OBL before/after refund: %d -> %d\n", launchpadBefore, launchpadAfter)
	ufmt.Printf("[INFO] Recipient OBL before/after refund: %d -> %d\n", recipientBefore, recipientAfter)
	ufmt.Printf("[INFO] Refunded to recipient: %d\n", recipientAfter-recipientBefore)
}

func collectDepositAndAssertSuccess(owner address, depositID string) {
	testing.SetRealm(testing.NewUserRealm(owner))

	beforeReward := obl.BalanceOf(owner)
	beforeGNS := gns.BalanceOf(owner)

	withdrawnGNS, _ := launchpad.CollectDepositGns(cross, depositID)

	afterReward := obl.BalanceOf(owner)
	afterGNS := gns.BalanceOf(owner)

	rewardDelta := afterReward - beforeReward
	gnsDelta := afterGNS - beforeGNS

	ufmt.Printf("[INFO] User reward delta: %d\n", rewardDelta)
	ufmt.Printf("[INFO] User GNS delta: %d\n", gnsDelta)
	ufmt.Printf("[INFO] CollectDepositGns return: %d\n", withdrawnGNS)

	if rewardDelta <= 0 {
		panic("expected positive reward after admin refund")
	}
	if gnsDelta <= 0 {
		panic("expected positive GNS withdrawal")
	}
}

// Output:
// [SCENARIO] 1. Create project and activate
// [INFO] Created project: gno.land/r/onbloc/obl:123
//
// [SCENARIO] 2. Alice deposits to tier-180
// [INFO] Deposit ID: 1
//
// [SCENARIO] 3. Skip to project end with no reward update events
// [INFO] Creating stale reward-manager gap: no collect/withdraw between deposit and refund
//
// [SCENARIO] 4. Admin refunds remaining rewards first
// [INFO] Launchpad OBL before/after refund: 1000000000 -> 699999999
// [INFO] Recipient OBL before/after refund: 0 -> 300000001
// [INFO] Refunded to recipient: 300000001
//
// [SCENARIO] 5. Alice collects deposit (reward+GNS in one flow)
// [INFO] User reward delta: 699999999
// [INFO] User GNS delta: 1000000
// [INFO] CollectDepositGns return: 1000000
