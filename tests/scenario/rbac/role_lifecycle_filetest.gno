package main

import (
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/r/gnoswap/v1/rbac"
)

func main() {
	println("[SCENARIO] 1. Initialize RBAC system and create custom role")
	initializeAndCreateRole()
	println()

	println("[SCENARIO] 2. Grant role to multiple addresses")
	grantRoleToAddresses()
	println()

	println("[SCENARIO] 3. Verify role assignments")
	verifyRoleAssignments()
	println()

	println("[SCENARIO] 4. Revoke role from specific address")
	revokeRoleFromAddress()
	println()

	println("[SCENARIO] 5. Remove all addresses from role")
	removeAllAddresses()
	println()

	println("[SCENARIO] 6. Delete custom role")
	deleteCustomRole()
	println()

	println("[SCENARIO] 7. Verify role no longer exists")
	verifyRoleDeletion()
	println()
}

var (
	customRole = "developer"
	addr1      = testutils.TestAddress("dev1")
	addr2      = testutils.TestAddress("dev2")
	addr3      = testutils.TestAddress("dev3")
)

func initializeAndCreateRole() {
	manager := rbac.GlobalManager()
	originalOwner := manager.Owner()

	testing.SetOriginCaller(originalOwner)

	err := rbac.DeclareRole(cross, customRole)

	if err != nil {
		println("[INFO] Role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Custom role created:", customRole)
	}
	println("[INFO] System owner:", originalOwner)
}

func grantRoleToAddresses() {
	manager := rbac.GlobalManager()

	err := manager.GrantRoleAndSetAddressByOwner(customRole, addr1)
	if err != nil {
		println("[INFO] Failed to grant role to addr1:", err.Error())
	} else {
		println("[EXPECTED] Role granted to addr1:", addr1)
	}

	// grant role to second address
	err = manager.GrantRoleAndSetAddressByOwner(customRole, addr2)
	if err != nil {
		println("[INFO] Failed to grant role to addr2:", err.Error())
	} else {
		println("[EXPECTED] Role granted to addr2:", addr2)
	}

	// grant role to third address
	err = manager.GrantRoleAndSetAddressByOwner(customRole, addr3)
	if err != nil {
		println("[INFO] Failed to grant role to addr3:", err.Error())
	} else {
		println("[EXPECTED] Role granted to addr3:", addr3)
	}

	println("[INFO] Total addresses with role:", 3)
}

func verifyRoleAssignments() {
	manager := rbac.GlobalManager()

	// check each address
	hasRole1 := manager.HasRole(customRole, addr1)
	println("[EXPECTED] addr1 has role:", hasRole1)

	hasRole2 := manager.HasRole(customRole, addr2)
	println("[EXPECTED] addr2 has role:", hasRole2)

	hasRole3 := manager.HasRole(customRole, addr3)
	println("[EXPECTED] addr3 has role:", hasRole3)

	// check non-assigned address
	nonAssigned := testutils.TestAddress("notdev")
	hasRoleNon := manager.HasRole(customRole, nonAssigned)
	println("[EXPECTED] non-assigned address has role:", hasRoleNon)
}

func revokeRoleFromAddress() {
	manager := rbac.GlobalManager()

	// revoke role from addr2
	err := manager.RevokeRole(customRole, addr2)

	if err != nil {
		println("[INFO] Failed to revoke role from addr2:", err.Error())
	} else {
		println("[EXPECTED] Role revoked from addr2")
	}

	// verify addr2 no longer has the role
	hasRole2 := manager.HasRole(customRole, addr2)
	println("[EXPECTED] addr2 has role after revocation:", hasRole2)

	// verify other addresses still have role
	hasRole1 := manager.HasRole(customRole, addr1)
	println("[EXPECTED] addr1 still has role:", hasRole1)

	hasRole3 := manager.HasRole(customRole, addr3)
	println("[EXPECTED] addr3 still has role:", hasRole3)
}

func removeAllAddresses() {
	manager := rbac.GlobalManager()

	// revoke from remaining addresses
	err := manager.RevokeRole(customRole, addr1)
	if err != nil {
		println("[INFO] Failed to revoke role from addr1:", err.Error())
	} else {
		println("[EXPECTED] Role revoked from addr1")
	}

	err = manager.RevokeRole(customRole, addr3)
	if err != nil {
		println("[INFO] Failed to revoke role from addr3:", err.Error())
	} else {
		println("[EXPECTED] Role revoked from addr3")
	}

	// verify no addresses have the role
	hasRole1 := manager.HasRole(customRole, addr1)
	hasRole2 := manager.HasRole(customRole, addr2)
	hasRole3 := manager.HasRole(customRole, addr3)

	println("[EXPECTED] No addresses have role:", !hasRole1 && !hasRole2 && !hasRole3)
	println("[INFO] All addresses removed from role")
}

func deleteCustomRole() {
	manager := rbac.GlobalManager()

	// attempt to delete the custom role
	err := manager.RemoveRole(customRole)

	if err != nil {
		println("[INFO] Failed to delete role:", err.Error())
	} else {
		println("[EXPECTED] Custom role deleted successfully")
	}
}

func verifyRoleDeletion() {
	manager := rbac.GlobalManager()

	// try to grant deleted role
	newAddr := testutils.TestAddress("newdev")
	err := manager.GrantRoleAndSetAddressByOwner(customRole, newAddr)

	if err != nil {
		println("[EXPECTED] Cannot grant deleted role, error:", err.Error())
	} else {
		println("[INFO] Unexpected: Deleted role can still be granted")
	}

	// check if addresses have the deleted role
	hasRole1 := manager.HasRole(customRole, addr1)
	hasRole2 := manager.HasRole(customRole, addr2)
	hasRole3 := manager.HasRole(customRole, addr3)

	println("[EXPECTED] No address has deleted role:", !hasRole1 && !hasRole2 && !hasRole3)
	println("[INFO] Role lifecycle completed - role no longer exists")
}

// Output:
// [SCENARIO] 1. Initialize RBAC system and create custom role
// [EXPECTED] Custom role created: developer
// [INFO] System owner: g1daxvn8gfl5jyu0tpuyc4fuj6y5uccu7yvuhqxj
//
// [SCENARIO] 2. Grant role to multiple addresses
// [EXPECTED] Role granted to addr1: g1v3jhvv2lta047h6lta047h6lta047h6ltcstgm
// [EXPECTED] Role granted to addr2: g1v3jhvvjlta047h6lta047h6lta047h6l2e9py9
// [EXPECTED] Role granted to addr3: g1v3jhvv6lta047h6lta047h6lta047h6ljp38q0
// [INFO] Total addresses with role: 3
//
// [SCENARIO] 3. Verify role assignments
// [EXPECTED] addr1 has role: true
// [EXPECTED] addr2 has role: true
// [EXPECTED] addr3 has role: true
// [EXPECTED] non-assigned address has role: false
//
// [SCENARIO] 4. Revoke role from specific address
// [EXPECTED] Role revoked from addr2
// [EXPECTED] addr2 has role after revocation: false
// [EXPECTED] addr1 still has role: true
// [EXPECTED] addr3 still has role: true
//
// [SCENARIO] 5. Remove all addresses from role
// [EXPECTED] Role revoked from addr1
// [EXPECTED] Role revoked from addr3
// [EXPECTED] No addresses have role: true
// [INFO] All addresses removed from role
//
// [SCENARIO] 6. Delete custom role
// [EXPECTED] Custom role deleted successfully
//
// [SCENARIO] 7. Verify role no longer exists
// [EXPECTED] Cannot grant deleted role, error: role developer does not exist
// [EXPECTED] No address has deleted role: true
// [INFO] Role lifecycle completed - role no longer exists
