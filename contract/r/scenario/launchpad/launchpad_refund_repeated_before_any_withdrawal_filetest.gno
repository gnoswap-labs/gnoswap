// launchpad admin refund: repeated refund before any depositor withdraws

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	"gno.land/r/onbloc/obl"
)

const (
	blockTime         = int64(5)
	activationSeconds = int64(7 * 24 * 60 * 60)
	projectSeconds    = int64(180 * 24 * 60 * 60)
	endGraceBlocks    = int64(6)
	depositAmount     = int64(1_000_000)
	rewardAmount      = int64(30_000_000)
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	userAddr         = testutils.TestAddress("withdrawal-user")
	userRealm        = testing.NewUserRealm(userAddr)
	projectAddr      = testutils.TestAddress("withdrawal-project")
)

// With 3 active deposits that have never been withdrawn, the first refund
// reserves the active-claim aggregate and moves the rest. Calling refund a
// second time right after, with no deposit/withdraw/claim in between, must
// not double-spend the reserved amount depositors can still claim.
func main(cur realm) {
	println("[SCENARIO] Same-time deposits, no withdrawal: repeat the admin refund")
	projectID := createProject(cur, "no withdrawal repeated refund")
	depositThreeTimes(cur, projectID)

	println("[STEP] skip until after the project end time")
	testing.SkipHeights(projectSeconds/blockTime + endGraceBlocks)

	println("[STEP] Launchpad project ends: admin refunds the remaining reward")
	endProjectAndRefund(cur, projectID)

	println("[STEP] trigger a second admin refund with no withdrawal in between")
	endProjectAndRefund(cur, projectID)

	println("[RESULT] Repeated refund before any withdrawal passed")
}

func createProject(cur realm, name string) string {
	startTime := time.Now().Unix() + activationSeconds

	testing.SetRealm(adminRealm)
	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	projectID := launchpad.CreateProject(
		cross(cur),
		name,
		"gno.land/r/onbloc/obl.OBL",
		projectAddr,
		rewardAmount,
		"",
		"",
		30,
		30,
		40,
		startTime,
	)
	testing.SkipHeights(activationSeconds / blockTime)
	return projectID
}

func depositThreeTimes(cur realm, projectID string) {
	for i := int64(0); i < 3; i++ {
		testing.SetRealm(adminRealm)
		gns.Transfer(cross(cur), userAddr, depositAmount)

		testing.SetRealm(userRealm)
		gns.Approve(cross(cur), launchpadAddr, depositAmount)
		depositID := launchpad.DepositGns(cross(cur), projectID+":30", depositAmount, "")
		ufmt.Printf("[INFO] deposit created: id=%s\n", depositID)
	}
}

func endProjectAndRefund(cur realm, projectID string) {
	active, err := launchpad.GetProjectActiveStatus(projectID)
	if err != nil {
		panic(err.Error())
	}
	ufmt.Printf("[INFO] project active status before refund: %t\n", active)

	testing.SetRealm(adminRealm)

	launchpadBefore := obl.BalanceOf(launchpadAddr)
	recipientBefore := obl.BalanceOf(projectAddr)

	refunded := launchpad.TransferLeftFromProjectByAdmin(cross(cur), projectID, projectAddr)

	launchpadAfter := obl.BalanceOf(launchpadAddr)
	recipientAfter := obl.BalanceOf(projectAddr)

	ufmt.Printf("[INFO] admin refund: %d OBL (launchpad %d -> %d, recipient %d -> %d)\n",
		refunded, launchpadBefore, launchpadAfter, recipientBefore, recipientAfter)
}

// Output:
// [SCENARIO] Same-time deposits, no withdrawal: repeat the admin refund
// [INFO] deposit created: id=1
// [INFO] deposit created: id=2
// [INFO] deposit created: id=3
// [STEP] skip until after the project end time
// [STEP] Launchpad project ends: admin refunds the remaining reward
// [INFO] project active status before refund: false
// [INFO] admin refund: 21000001 OBL (launchpad 30000000 -> 8999999, recipient 0 -> 21000001)
// [STEP] trigger a second admin refund with no withdrawal in between
// [INFO] project active status before refund: false
// [INFO] admin refund: 0 OBL (launchpad 8999999 -> 8999999, recipient 21000001 -> 21000001)
// [RESULT] Repeated refund before any withdrawal passed
