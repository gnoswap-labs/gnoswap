// launchpad withdrawal around admin refund: same-time deposits

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

// This scenario exercises the exact interleaving the aggregate-liability fix
// has to get right: withdrawals happen both before and after the admin's
// leftover-reward refund, so the refund must not over- or under-reserve the
// still-pending withdrawals.
func main(cur realm) {
	println("[SCENARIO] Same-time deposits: withdraw around admin refund mid-sequence")
	projectID := createProject(cur, "same-time withdrawals")
	depositIDs := depositThreeTimes(cur, projectID, false)

	println("[STEP] skip until after the project end time")
	testing.SkipHeights(projectSeconds/blockTime + endGraceBlocks)

	println("[STEP] withdraw the first deposit")
	withdrawDeposit(cur, depositIDs[0])
	testing.SkipHeights(1)

	println("[STEP] Launchpad project ends: admin refunds the remaining reward")
	endProjectAndRefund(cur, projectID)
	testing.SkipHeights(1)

	println("[STEP] withdraw the second deposit")
	withdrawDeposit(cur, depositIDs[1])
	testing.SkipHeights(1)

	println("[STEP] withdraw the third deposit")
	withdrawDeposit(cur, depositIDs[2])

	println("[RESULT] Same-time deposit withdrawal lifecycle passed")
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

func depositThreeTimes(cur realm, projectID string, staggered bool) []string {
	depositIDs := make([]string, 0, 3)

	for i := int64(0); i < 3; i++ {
		testing.SetRealm(adminRealm)
		gns.Transfer(cross(cur), userAddr, depositAmount)

		testing.SetRealm(userRealm)
		gns.Approve(cross(cur), launchpadAddr, depositAmount)
		depositID := launchpad.DepositGns(cross(cur), projectID+":30", depositAmount, "")
		ufmt.Printf("[INFO] deposit created: id=%s\n", depositID)
		depositIDs = append(depositIDs, depositID)

		if staggered && i < 2 {
			testing.SkipHeights(1)
		}
	}

	return depositIDs
}

func withdrawDeposit(cur realm, depositID string) {
	testing.SetRealm(userRealm)

	oblBefore := obl.BalanceOf(userAddr)
	gnsBefore := gns.BalanceOf(userAddr)

	gnsAmount, _ := launchpad.CollectDepositGns(cross(cur), depositID)

	oblAfter := obl.BalanceOf(userAddr)
	gnsAfter := gns.BalanceOf(userAddr)

	ufmt.Printf("[INFO] deposit %s: GNS withdrawn=%d, OBL reward collected=%d\n",
		depositID, gnsAmount, oblAfter-oblBefore)
	ufmt.Printf("[INFO] deposit %s: GNS balance %d -> %d, OBL balance %d -> %d\n",
		depositID, gnsBefore, gnsAfter, oblBefore, oblAfter)
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
// [SCENARIO] Same-time deposits: withdraw around admin refund mid-sequence
// [INFO] deposit created: id=1
// [INFO] deposit created: id=2
// [INFO] deposit created: id=3
// [STEP] skip until after the project end time
// [STEP] withdraw the first deposit
// [INFO] deposit 1: GNS withdrawn=1000000, OBL reward collected=2999999
// [INFO] deposit 1: GNS balance 0 -> 1000000, OBL balance 0 -> 2999999
// [STEP] Launchpad project ends: admin refunds the remaining reward
// [INFO] project active status before refund: false
// [INFO] admin refund: 21000002 OBL (launchpad 27000001 -> 5999999, recipient 0 -> 21000002)
// [STEP] withdraw the second deposit
// [INFO] deposit 2: GNS withdrawn=1000000, OBL reward collected=2999999
// [INFO] deposit 2: GNS balance 1000000 -> 2000000, OBL balance 2999999 -> 5999998
// [STEP] withdraw the third deposit
// [INFO] deposit 3: GNS withdrawn=1000000, OBL reward collected=2999999
// [INFO] deposit 3: GNS balance 2000000 -> 3000000, OBL balance 5999998 -> 8999997
// [RESULT] Same-time deposit withdrawal lifecycle passed
