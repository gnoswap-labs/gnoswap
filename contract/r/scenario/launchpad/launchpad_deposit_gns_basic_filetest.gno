// launchpad deposit gns basic test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/obl"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	launchpadRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/launchpad")

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = testing.NewUserRealm(user1Addr)

	user2Addr  = testutils.TestAddress("user2")
	user2Realm = testing.NewUserRealm(user2Addr)

	projectAddr  = testutils.TestAddress("project1")
	projectRealm = testing.NewUserRealm(projectAddr)
)

var t *testing.T

func main() {
	println("[SCENARIO] 1. Create OBL launchpad project")
	projectId := createOBLProject()
	projectTier30Id := projectId + ":30"
	projectTier90Id := projectId + ":90"
	projectTier180Id := projectId + ":180"
	println()

	println("[SCENARIO] 2. Successful deposit with valid project and tier (30 days)")
	depositGnsSuccessful(projectTier30Id, 1_000_000)
	println()

	println("[SCENARIO] 3. Successful deposit with referrer (90 days)")
	depositGnsWithReferrer(projectTier90Id, 2_000_000)
	println()

	println("[SCENARIO] 4. Successful deposit with 180 day tier")
	depositGns180Days(projectTier180Id, 3_000_000)
	println()

	println("[SCENARIO] 5. Fail with zero amount")
	depositGnsFailZeroAmount(projectTier30Id)
	println()

	println("[SCENARIO] 6. Fail with negative amount")
	depositGnsFailNegativeAmount(projectTier30Id)
	println()

	println("[SCENARIO] 7. Fail with invalid project tier ID format")
	depositGnsFailInvalidFormat()
	println()

	println("[SCENARIO] 8. Fail with non-existent project")
	depositGnsFailNonExistent()
	println()
}

// Create OBL launchpad project
func createOBLProject() string {
	println("[INFO] Creating OBL launchpad project")

	recipientAddr := projectAddr
	projectName := "Test OBL Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	rewardAmount := int64(10_000_000)
	conditionPath := ""
	conditionsAmount := ""
	tier30Ratio := int64(30)
	tier90Ratio := int64(30)
	tier180Ratio := int64(40)
	startTime := int64(time.Now().Unix() + 604800) // 7 days from now

	println("[INFO] Admin creating OBL project")
	testing.SetRealm(adminRealm)
	obl.Approve(cross, launchpadAddr, rewardAmount)
	projectId := launchpad.CreateProject(
		cross,
		projectName,
		rewardTokenPath,
		recipientAddr,
		rewardAmount,
		conditionPath,
		conditionsAmount,
		tier30Ratio,
		tier90Ratio,
		tier180Ratio,
		startTime,
	)

	println("[INFO] Skipping 120960 blocks to activate project")
	testing.SkipHeights(120960)

	println("[EXPECTED] Project created with ID:", projectId)
	return projectId
}

// Successful deposit with valid project and tier
func depositGnsSuccessful(projectTierId string, depositAmount int64) {
	println("[INFO] Testing successful GNS deposit")

	// Setup user with GNS tokens
	println("[INFO] Admin transferring GNS to user1")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, user1Addr, depositAmount*2)

	// User approves launchpad to spend GNS
	println("[INFO] User1 approving launchpad to spend GNS")
	testing.SetRealm(user1Realm)
	gns.Approve(cross, launchpadAddr, depositAmount*2)

	// Deposit GNS
	println("[INFO] User1 depositing GNS to project tier")
	depositId := launchpad.DepositGns(cross, projectTierId, depositAmount, "")

	println("[EXPECTED] Deposit successful with ID:", depositId)
	println("[EXPECTED] User1 GNS balance after deposit:", gns.BalanceOf(user1Addr))
}

// Successful deposit with referrer
func depositGnsWithReferrer(projectTierId string, depositAmount int64) {
	println("[INFO] Testing GNS deposit with referrer")

	// Setup user with GNS tokens
	println("[INFO] Admin transferring GNS to user2")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, user2Addr, depositAmount*2)

	// User approves launchpad to spend GNS
	println("[INFO] User2 approving launchpad to spend GNS")
	testing.SetRealm(user2Realm)
	gns.Approve(cross, launchpadAddr, depositAmount*2)

	// Deposit GNS with referrer
	referrerAddr := "g1referrer"
	println("[INFO] User2 depositing GNS with referrer:", referrerAddr)
	depositId := launchpad.DepositGns(cross, projectTierId, depositAmount, referrerAddr)

	println("[EXPECTED] Deposit successful with ID:", depositId)
	println("[EXPECTED] User2 GNS balance after deposit:", gns.BalanceOf(user2Addr))
}

// Deposit with 180 day tier
func depositGns180Days(projectTierId string, depositAmount int64) {
	println("[INFO] Testing GNS deposit to 180 day tier")

	user3Addr := testutils.TestAddress("user3")
	user3Realm := testing.NewUserRealm(user3Addr)

	// Setup user with GNS tokens
	println("[INFO] Admin transferring GNS to user3")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, user3Addr, depositAmount*2)

	// User approves launchpad to spend GNS
	println("[INFO] User3 approving launchpad to spend GNS")
	testing.SetRealm(user3Realm)
	gns.Approve(cross, launchpadAddr, depositAmount*2)

	// Deposit GNS
	println("[INFO] User3 depositing GNS to 180 day tier")
	depositId := launchpad.DepositGns(cross, projectTierId, depositAmount, "")

	println("[EXPECTED] Deposit successful with ID:", depositId)
	println("[EXPECTED] User3 GNS balance after deposit:", gns.BalanceOf(user3Addr))
}

// Fail with zero amount
func depositGnsFailZeroAmount(projectTierId string) {
	println("[INFO] Testing deposit with zero amount (should fail)")

	user4Addr := testutils.TestAddress("user4")
	user4Realm := testing.NewUserRealm(user4Addr)

	testing.SetRealm(user4Realm)

	expectedPanicMessage := "amount(0) should greater than minimum deposit amount(1000000)"
	uassert.AbortsContains(t, expectedPanicMessage, func() {
		launchpad.DepositGns(cross, projectTierId, 0, "")
	})
	println("[EXPECTED] Should abort with zero amount error:", expectedPanicMessage)
}

// Fail with negative amount
func depositGnsFailNegativeAmount(projectTierId string) {
	println("[INFO] Testing deposit with negative amount (should fail)")

	user5Addr := testutils.TestAddress("user5")
	user5Realm := testing.NewUserRealm(user5Addr)

	testing.SetRealm(user5Realm)
	expectedPanicMessage := "amount(-1000000) should greater than minimum deposit amount(1000000)"
	uassert.AbortsContains(t, expectedPanicMessage, func() {
		launchpad.DepositGns(cross, projectTierId, -1_000_000, "")
	})
	println("[EXPECTED] Should abort with negative amount error:", expectedPanicMessage)
}

// Fail with invalid project tier ID format
func depositGnsFailInvalidFormat() {
	println("[INFO] Testing deposit with invalid tier ID format (should fail)")

	user6Addr := testutils.TestAddress("user6")
	user6Realm := testing.NewUserRealm(user6Addr)

	testing.SetRealm(user6Realm)
	expectedPanicMessage := "(invalid_format)"
	uassert.AbortsContains(t, expectedPanicMessage, func() {
		launchpad.DepositGns(cross, "invalid_format", 1_000_000, "")
	})
	println("[EXPECTED] Should abort with invalid format error:", expectedPanicMessage)
}

// Fail with non-existent project
func depositGnsFailNonExistent() {
	println("[INFO] Testing deposit to non-existent project (should fail)")

	user7Addr := testutils.TestAddress("user7")
	user7Realm := testing.NewUserRealm(user7Addr)

	testing.SetRealm(user7Realm)
	expectedPanicMessage := "(non_existent_project:30)"
	uassert.AbortsContains(t, expectedPanicMessage, func() {
		launchpad.DepositGns(cross, "non_existent_project:30", 1_000_000, "")
	})
	println("[EXPECTED] Should abort with non-existent project error:", expectedPanicMessage)
}

// Output:
// [SCENARIO] 1. Create OBL launchpad project
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [INFO] Skipping 120960 blocks to activate project
// [EXPECTED] Project created with ID: gno.land/r/onbloc/obl:123
//
// [SCENARIO] 2. Successful deposit with valid project and tier (30 days)
// [INFO] Testing successful GNS deposit
// [INFO] Admin transferring GNS to user1
// [INFO] User1 approving launchpad to spend GNS
// [INFO] User1 depositing GNS to project tier
// [EXPECTED] Deposit successful with ID: 1
// [EXPECTED] User1 GNS balance after deposit: 1000000
//
// [SCENARIO] 3. Successful deposit with referrer (90 days)
// [INFO] Testing GNS deposit with referrer
// [INFO] Admin transferring GNS to user2
// [INFO] User2 approving launchpad to spend GNS
// [INFO] User2 depositing GNS with referrer: g1referrer
// [EXPECTED] Deposit successful with ID: 2
// [EXPECTED] User2 GNS balance after deposit: 2000000
//
// [SCENARIO] 4. Successful deposit with 180 day tier
// [INFO] Testing GNS deposit to 180 day tier
// [INFO] Admin transferring GNS to user3
// [INFO] User3 approving launchpad to spend GNS
// [INFO] User3 depositing GNS to 180 day tier
// [EXPECTED] Deposit successful with ID: 3
// [EXPECTED] User3 GNS balance after deposit: 3000000
//
// [SCENARIO] 5. Fail with zero amount
// [INFO] Testing deposit with zero amount (should fail)
// [EXPECTED] Should abort with zero amount error: amount(0) should greater than minimum deposit amount(1000000)
//
// [SCENARIO] 6. Fail with negative amount
// [INFO] Testing deposit with negative amount (should fail)
// [EXPECTED] Should abort with negative amount error: amount(-1000000) should greater than minimum deposit amount(1000000)
//
// [SCENARIO] 7. Fail with invalid project tier ID format
// [INFO] Testing deposit with invalid tier ID format (should fail)
// [EXPECTED] Should abort with invalid format error: (invalid_format)
//
// [SCENARIO] 8. Fail with non-existent project
// [INFO] Testing deposit to non-existent project (should fail)
// [EXPECTED] Should abort with non-existent project error: (non_existent_project:30)
