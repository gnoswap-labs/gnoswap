// launchpad repeated admin refund must not drain another project

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
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/onbloc/obl"
)

var (
	t *testing.T

	blockTimeSeconds int64 = 5
	secondsInDay     int64 = 24 * 60 * 60
	skipBlocks180Day int64 = 180 * secondsInDay / blockTimeSeconds

	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

	projectAAddr = testutils.TestAddress("project-a")
	projectBAddr = testutils.TestAddress("project-b")
)

func main(cur realm) {
	println("[SCENARIO] Repeated admin refund is idempotent per project")
	println("[INFO] Two ended launchpad projects share the same OBL balance in the launchpad realm")
	println()

	println("[SCENARIO] 1. Create project A with 1,000,000 OBL")
	projectAID := createOBLProject(cur, "Project A", projectAAddr, 1_000_000)
	println()

	println("[SCENARIO] 2. Create project B with 1,000,000 OBL")
	projectBID := createOBLProject(cur, "Project B", projectBAddr, 1_000_000)
	println()

	println("[SCENARIO] 3. Skip to end both projects")
	testing.SkipHeights(skipBlocks180Day + 6)
	ufmt.Printf("[INFO] Launchpad OBL balance before refunds: %d\n", obl.BalanceOf(launchpadAddr))
	println()

	println("[SCENARIO] 4. Refund project A once")
	refundProject(cur, projectAID, projectAAddr)
	ufmt.Printf("[INFO] Project A OBL after first refund: %d\n", obl.BalanceOf(projectAAddr))
	ufmt.Printf("[INFO] Launchpad OBL after first refund: %d\n", obl.BalanceOf(launchpadAddr))
	println()

	println("[SCENARIO] 5. Repeat project A refund")
	uassert.AbortsContains(t, cur, "project has no remaining amount", func() {
		refundProject(cur, projectAID, projectAAddr)
	})
	println("[EXPECTED] Repeated project A refund is blocked")
	ufmt.Printf("[INFO] Project A OBL after repeated refund attempt: %d\n", obl.BalanceOf(projectAAddr))
	ufmt.Printf("[INFO] Launchpad OBL after repeated refund attempt: %d\n", obl.BalanceOf(launchpadAddr))
	println()

	println("[SCENARIO] 6. Refund project B")
	refundProject(cur, projectBID, projectBAddr)
	ufmt.Printf("[INFO] Project B OBL after refund: %d\n", obl.BalanceOf(projectBAddr))
	ufmt.Printf("[INFO] Launchpad OBL after project B refund: %d\n", obl.BalanceOf(launchpadAddr))
	println()
}

func createOBLProject(cur realm, name string, recipient address, rewardAmount int64) string {
	rewardTokenPath := "gno.land/r/onbloc/obl.OBL"
	startTime := int64(time.Now().Unix() + 604800)

	testing.SetRealm(adminRealm)
	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	projectID := launchpad.CreateProject(
		cross(cur),
		name,
		rewardTokenPath,
		recipient,
		rewardAmount,
		"",
		"",
		0,
		0,
		100,
		startTime,
	)

	testing.SkipHeights(604800 / blockTimeSeconds)
	println("[INFO] Project created with ID:", projectID)
	return projectID
}

func refundProject(cur realm, projectID string, recipient address) {
	testing.SetRealm(adminRealm)
	launchpad.TransferLeftFromProjectByAdmin(cross(cur), projectID, recipient)
}

// Output:
// [SCENARIO] Repeated admin refund is idempotent per project
// [INFO] Two ended launchpad projects share the same OBL balance in the launchpad realm
//
// [SCENARIO] 1. Create project A with 1,000,000 OBL
// [INFO] Project created with ID: gno.land/r/onbloc/obl.OBL:123
//
// [SCENARIO] 2. Create project B with 1,000,000 OBL
// [INFO] Project created with ID: gno.land/r/onbloc/obl.OBL:121083
//
// [SCENARIO] 3. Skip to end both projects
// [INFO] Launchpad OBL balance before refunds: 2000000
//
// [SCENARIO] 4. Refund project A once
// [INFO] Project A OBL after first refund: 1000000
// [INFO] Launchpad OBL after first refund: 1000000
//
// [SCENARIO] 5. Repeat project A refund
// [EXPECTED] Repeated project A refund is blocked
// [INFO] Project A OBL after repeated refund attempt: 1000000
// [INFO] Launchpad OBL after repeated refund attempt: 1000000
//
// [SCENARIO] 6. Refund project B
// [INFO] Project B OBL after refund: 1000000
// [INFO] Launchpad OBL after project B refund: 0
//
