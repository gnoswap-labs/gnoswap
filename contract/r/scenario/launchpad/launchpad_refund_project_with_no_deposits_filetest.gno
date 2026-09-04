// launchpad admin refund: project ends without ever receiving a deposit

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
	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	"gno.land/r/onbloc/obl"
)

const (
	blockTime         = int64(5)
	activationSeconds = int64(7 * 24 * 60 * 60)
	projectSeconds    = int64(180 * 24 * 60 * 60)
	endGraceBlocks    = int64(6)
	rewardAmount      = int64(30_000_000)
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	projectAddr      = testutils.TestAddress("withdrawal-project")
)

// With zero active deposits, the aggregate liability is zero, so the admin
// refund should return the full reward with no dust withheld.
func main(cur realm) {
	println("[SCENARIO] End a project that never received any deposit")
	projectID := createProject(cur, "no deposits")

	println("[STEP] skip until after the project end time")
	testing.SkipHeights(projectSeconds/blockTime + endGraceBlocks)

	println("[STEP] Launchpad project ends: admin refunds the remaining reward")
	endProjectAndRefund(cur, projectID)

	println("[RESULT] No-deposit project refund passed")
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
// [SCENARIO] End a project that never received any deposit
// [STEP] skip until after the project end time
// [STEP] Launchpad project ends: admin refunds the remaining reward
// [INFO] project active status before refund: false
// [INFO] admin refund: 30000000 OBL (launchpad 30000000 -> 0, recipient 0 -> 30000000)
// [RESULT] No-deposit project refund passed
