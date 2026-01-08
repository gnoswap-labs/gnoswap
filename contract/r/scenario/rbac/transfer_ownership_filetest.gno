// Scenario Test: RBAC Transfer Ownership Process
// Tests the complete ownership transfer cycle in the RBAC system
// including initiation, pending state, acceptance, and verification
//
// Key invariant: RBAC Owner and ROLE_ADMIN are unified
//   - Owner and ROLE_ADMIN always point to the same address
//   - When ownership is transferred, ROLE_ADMIN is automatically updated
//   - This ensures a single source of truth for admin authority

package main

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/rbac"
)

var t *testing.T

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	newOwnerAddr  = testutils.TestAddress("new_owner")
	newOwnerRealm = testing.NewUserRealm(newOwnerAddr)

	randomAddr  = testutils.TestAddress("random_user")
	randomRealm = testing.NewUserRealm(randomAddr)
)

func main() {
	println("[SCENARIO] RBAC Transfer Ownership Process - Full Cycle Test")
	println()

	println("[STEP 1] Verify initial ownership state")
	verifyInitialOwnershipState()
	println()

	println("[STEP 2] Non-owner cannot initiate ownership transfer")
	testNonOwnerCannotTransfer()
	println()

	println("[STEP 3] Owner initiates ownership transfer")
	testOwnerInitiatesTransfer()
	println()

	println("[STEP 4] Verify pending owner state")
	verifyPendingOwnerState()
	println()

	println("[STEP 5] Non-pending owner cannot accept ownership")
	testNonPendingOwnerCannotAccept()
	println()

	println("[STEP 6] Pending owner accepts ownership")
	testPendingOwnerAccepts()
	println()

	println("[STEP 7] Verify ownership transfer completed")
	verifyOwnershipTransferCompleted()
	println()

	println("[STEP 8] Verify ROLE_ADMIN updated in access module")
	verifyRoleAdminUpdated()
	println()

	println("[STEP 9] Previous owner can no longer transfer ownership")
	testPreviousOwnerCannotTransfer()
	println()

	println("[STEP 10] New owner can initiate another transfer")
	testNewOwnerCanTransfer()
	println()
}

func verifyInitialOwnershipState() {
	owner := rbac.GetOwner()
	pendingOwner := rbac.GetPendingOwner()
	roleAdminAddr, ok := access.GetAddress(prbac.ROLE_ADMIN.String())

	ufmt.Printf("[INFO] Current owner: %s\n", owner.String())
	ufmt.Printf("[INFO] ROLE_ADMIN address: %s\n", roleAdminAddr.String())
	ufmt.Printf("[INFO] Pending owner: %s\n", pendingOwner.String())

	// Verify Owner and ROLE_ADMIN are the same (unified)
	uassert.True(t, ok)
	uassert.Equal(t, owner, roleAdminAddr)
	ufmt.Printf("[INFO] Owner == ROLE_ADMIN: %t\n", owner == roleAdminAddr)

	uassert.Equal(t, adminAddr, owner)
	uassert.Equal(t, address(""), pendingOwner)

	isOwner := rbac.IsOwner(adminAddr)
	uassert.True(t, isOwner)

	println("[SUCCESS] Initial state verified - Owner and ROLE_ADMIN are unified")
}

func testNonOwnerCannotTransfer() {
	testing.SetRealm(randomRealm)

	ufmt.Printf("[INFO] Attempting transfer by non-owner (%s)\n", randomAddr.String())

	uassert.AbortsContains(t, "caller is not owner", func() {
		rbac.TransferOwnership(cross, newOwnerAddr)
	})

	println("[SUCCESS] Non-owner correctly blocked from initiating transfer")
}

func testOwnerInitiatesTransfer() {
	testing.SetRealm(adminRealm)

	ufmt.Printf("[INFO] Owner (%s) initiating transfer to new owner (%s)\n", adminAddr.String(), newOwnerAddr.String())

	rbac.TransferOwnership(cross, newOwnerAddr)

	println("[SUCCESS] Ownership transfer initiated by current owner")
}

func verifyPendingOwnerState() {
	owner := rbac.GetOwner()
	pendingOwner := rbac.GetPendingOwner()

	ufmt.Printf("[INFO] Current owner (should be unchanged): %s\n", owner.String())
	ufmt.Printf("[INFO] Pending owner (should be new owner): %s\n", pendingOwner.String())

	// Owner should not change until acceptance
	uassert.Equal(t, adminAddr, owner)
	// Pending owner should be set
	uassert.Equal(t, newOwnerAddr, pendingOwner)

	// Verify helper functions
	uassert.True(t, rbac.IsOwner(adminAddr))
	uassert.False(t, rbac.IsOwner(newOwnerAddr))
	uassert.True(t, rbac.IsPendingOwner(newOwnerAddr))
	uassert.False(t, rbac.IsPendingOwner(adminAddr))

	println("[SUCCESS] Pending owner state verified correctly")
}

func testNonPendingOwnerCannotAccept() {
	testing.SetRealm(randomRealm)

	ufmt.Printf("[INFO] Attempting accept by non-pending owner (%s)\n", randomAddr.String())

	uassert.AbortsContains(t, "caller is not pending owner", func() {
		rbac.AcceptOwnership(cross)
	})

	// Also verify original owner cannot accept
	testing.SetRealm(adminRealm)

	ufmt.Printf("[INFO] Attempting accept by original owner (%s)\n", adminAddr.String())

	uassert.AbortsContains(t, "caller is not pending owner", func() {
		rbac.AcceptOwnership(cross)
	})

	println("[SUCCESS] Non-pending owners correctly blocked from accepting")
}

func testPendingOwnerAccepts() {
	testing.SetRealm(newOwnerRealm)

	ufmt.Printf("[INFO] Pending owner (%s) accepting ownership\n", newOwnerAddr.String())

	rbac.AcceptOwnership(cross)

	println("[SUCCESS] Ownership accepted by pending owner")
}

func verifyOwnershipTransferCompleted() {
	owner := rbac.GetOwner()
	pendingOwner := rbac.GetPendingOwner()
	roleAdminAddr, ok := access.GetAddress(prbac.ROLE_ADMIN.String())

	ufmt.Printf("[INFO] New owner: %s\n", owner.String())
	ufmt.Printf("[INFO] New ROLE_ADMIN: %s\n", roleAdminAddr.String())
	ufmt.Printf("[INFO] Pending owner (should be empty): %s\n", pendingOwner.String())

	// Owner should now be the new owner
	uassert.Equal(t, newOwnerAddr, owner)
	// Pending owner should be cleared
	uassert.Equal(t, address(""), pendingOwner)

	// Verify Owner and ROLE_ADMIN are still unified after transfer
	uassert.True(t, ok)
	uassert.Equal(t, owner, roleAdminAddr)
	ufmt.Printf("[INFO] Owner == ROLE_ADMIN after transfer: %t\n", owner == roleAdminAddr)

	// Verify helper functions
	uassert.True(t, rbac.IsOwner(newOwnerAddr))
	uassert.False(t, rbac.IsOwner(adminAddr))
	uassert.False(t, rbac.IsPendingOwner(newOwnerAddr))
	uassert.False(t, rbac.IsPendingOwner(adminAddr))

	println("[SUCCESS] Ownership transfer completed - Owner and ROLE_ADMIN remain unified")
}

func verifyRoleAdminUpdated() {
	// Verify that previous owner is no longer ROLE_ADMIN
	accessAdminAddr, ok := access.GetAddress(prbac.ROLE_ADMIN.String())

	ufmt.Printf("[INFO] Previous owner address: %s\n", adminAddr.String())
	ufmt.Printf("[INFO] Current ROLE_ADMIN address: %s\n", accessAdminAddr.String())
	ufmt.Printf("[INFO] Previous owner is ROLE_ADMIN: %t\n", adminAddr == accessAdminAddr)

	uassert.True(t, ok)
	uassert.NotEqual(t, adminAddr, accessAdminAddr)
	uassert.Equal(t, newOwnerAddr, accessAdminAddr)

	println("[SUCCESS] Previous owner is no longer ROLE_ADMIN - authority transferred")
}

func testPreviousOwnerCannotTransfer() {
	testing.SetRealm(adminRealm)

	ufmt.Printf("[INFO] Previous owner (%s) attempting to transfer ownership\n", adminAddr.String())

	uassert.AbortsContains(t, "caller is not owner", func() {
		rbac.TransferOwnership(cross, randomAddr)
	})

	println("[SUCCESS] Previous owner correctly blocked from transferring")
}

func testNewOwnerCanTransfer() {
	testing.SetRealm(newOwnerRealm)

	ufmt.Printf("[INFO] New owner (%s) initiating transfer to another address (%s)\n", newOwnerAddr.String(), randomAddr.String())

	rbac.TransferOwnership(cross, randomAddr)

	// Verify pending owner is set
	pendingOwner := rbac.GetPendingOwner()
	uassert.Equal(t, randomAddr, pendingOwner)

	ufmt.Printf("[INFO] Pending owner set to: %s\n", pendingOwner.String())

	println("[SUCCESS] New owner can initiate another ownership transfer")
}

// Output:
// [SCENARIO] RBAC Transfer Ownership Process - Full Cycle Test
//
// [STEP 1] Verify initial ownership state
// [INFO] Current owner: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [INFO] ROLE_ADMIN address: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [INFO] Pending owner:
// [INFO] Owner == ROLE_ADMIN: true
// [SUCCESS] Initial state verified - Owner and ROLE_ADMIN are unified
//
// [STEP 2] Non-owner cannot initiate ownership transfer
// [INFO] Attempting transfer by non-owner (g1wfskuer0d40h2um9wf047h6lta047h6lmzq38v)
// [SUCCESS] Non-owner correctly blocked from initiating transfer
//
// [STEP 3] Owner initiates ownership transfer
// [INFO] Owner (g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5) initiating transfer to new owner (g1dejhwhm0wahx2ujlta047h6lta047h6l5la58j)
// [SUCCESS] Ownership transfer initiated by current owner
//
// [STEP 4] Verify pending owner state
// [INFO] Current owner (should be unchanged): g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [INFO] Pending owner (should be new owner): g1dejhwhm0wahx2ujlta047h6lta047h6l5la58j
// [SUCCESS] Pending owner state verified correctly
//
// [STEP 5] Non-pending owner cannot accept ownership
// [INFO] Attempting accept by non-pending owner (g1wfskuer0d40h2um9wf047h6lta047h6lmzq38v)
// [INFO] Attempting accept by original owner (g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5)
// [SUCCESS] Non-pending owners correctly blocked from accepting
//
// [STEP 6] Pending owner accepts ownership
// [INFO] Pending owner (g1dejhwhm0wahx2ujlta047h6lta047h6l5la58j) accepting ownership
// [SUCCESS] Ownership accepted by pending owner
//
// [STEP 7] Verify ownership transfer completed
// [INFO] New owner: g1dejhwhm0wahx2ujlta047h6lta047h6l5la58j
// [INFO] New ROLE_ADMIN: g1dejhwhm0wahx2ujlta047h6lta047h6l5la58j
// [INFO] Pending owner (should be empty):
// [INFO] Owner == ROLE_ADMIN after transfer: true
// [SUCCESS] Ownership transfer completed - Owner and ROLE_ADMIN remain unified
//
// [STEP 8] Verify ROLE_ADMIN updated in access module
// [INFO] Previous owner address: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [INFO] Current ROLE_ADMIN address: g1dejhwhm0wahx2ujlta047h6lta047h6l5la58j
// [INFO] Previous owner is ROLE_ADMIN: false
// [SUCCESS] Previous owner is no longer ROLE_ADMIN - authority transferred
//
// [STEP 9] Previous owner can no longer transfer ownership
// [INFO] Previous owner (g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5) attempting to transfer ownership
// [SUCCESS] Previous owner correctly blocked from transferring
//
// [STEP 10] New owner can initiate another transfer
// [INFO] New owner (g1dejhwhm0wahx2ujlta047h6lta047h6l5la58j) initiating transfer to another address (g1wfskuer0d40h2um9wf047h6lta047h6lmzq38v)
// [INFO] Pending owner set to: g1wfskuer0d40h2um9wf047h6lta047h6lmzq38v
// [SUCCESS] New owner can initiate another ownership transfer
