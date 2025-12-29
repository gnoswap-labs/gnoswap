package access

import (
	"chain"
	"chain/runtime"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"
)

// AssertIsAdminOrGovernance panics if the caller is not admin or governance.
// Used for functions that require elevated privileges.
func AssertIsAdminOrGovernance(caller address) {
	if IsAuthorized(prbac.ROLE_ADMIN.String(), caller) || IsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller) {
		return
	}

	panic(ufmt.Errorf("unauthorized: caller %s is not admin or governance", caller))
}

// AssertIsAdmin panics if the caller is not admin.
// Used for admin-only functions.
func AssertIsAdmin(caller address) {
	AssertIsAuthorized(prbac.ROLE_ADMIN.String(), caller)
}

// AssertIsGovernance panics if the caller is not governance.
// Used for governance-only functions.
func AssertIsGovernance(caller address) {
	AssertIsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller)
}

// AssertIsGovStaker panics if the caller is not governance staker.
// Used for governance staking functions.
func AssertIsGovStaker(caller address) {
	AssertIsAuthorized(prbac.ROLE_GOV_STAKER.String(), caller)
}

// AssertIsRouter panics if the caller is not router.
// Used for router-only functions.
func AssertIsRouter(caller address) {
	AssertIsAuthorized(prbac.ROLE_ROUTER.String(), caller)
}

// AssertIsPool panics if the caller is not pool.
// Used for pool-only functions.
func AssertIsPool(caller address) {
	AssertIsAuthorized(prbac.ROLE_POOL.String(), caller)
}

// AssertIsPosition panics if the caller is not position.
// Used for position-only functions.
func AssertIsPosition(caller address) {
	AssertIsAuthorized(prbac.ROLE_POSITION.String(), caller)
}

// AssertIsStaker panics if the caller is not staker.
// Used for staker-only functions.
func AssertIsStaker(caller address) {
	AssertIsAuthorized(prbac.ROLE_STAKER.String(), caller)
}

// AssertIsLaunchpad panics if the caller is not launchpad.
// Used for launchpad-only functions.
func AssertIsLaunchpad(caller address) {
	AssertIsAuthorized(prbac.ROLE_LAUNCHPAD.String(), caller)
}

// AssertIsEmission panics if the caller is not emission.
// Used for emission-only functions.
func AssertIsEmission(caller address) {
	AssertIsAuthorized(prbac.ROLE_EMISSION.String(), caller)
}

// AssertIsProtocolFee panics if the caller is not protocol fee.
// Used for protocol fee management functions.
func AssertIsProtocolFee(caller address) {
	AssertIsAuthorized(prbac.ROLE_PROTOCOL_FEE.String(), caller)
}

// AssertIsGovXGNS panics if the caller is not xGNS governance.
// Used for xGNS governance functions.
func AssertIsGovXGNS(caller address) {
	AssertIsAuthorized(prbac.ROLE_XGNS.String(), caller)
}

// AssertIsAuthorized panics if the caller does not have the specified role.
// Also panics if the role does not exist.
func AssertIsAuthorized(roleName string, caller address) {
	addr, ok := GetAddress(roleName)
	if !ok {
		panic(ufmt.Errorf("role %s does not exist", roleName))
	}

	if caller != addr {
		panic(ufmt.Errorf("unauthorized: caller %s is not %s", caller, roleName))
	}
}

// AssertHasAnyRole panics if the caller does not have any of the specified roles.
// Also panics if any of the roles do not exist.
func AssertHasAnyRole(caller address, roleNames ...string) {
	for _, roleName := range roleNames {
		addr, ok := GetAddress(roleName)
		if !ok {
			panic(ufmt.Errorf("role %s does not exist", roleName))
		}

		if caller == addr {
			return
		}
	}

	panic(ufmt.Errorf("unauthorized: caller %s is not any of the roles %v", caller, roleNames))
}

// AssertIsValidAddress panics if the provided address is invalid.
func AssertIsValidAddress(addr address) {
	if !addr.IsValid() {
		panic(ufmt.Errorf("invalid address: %s", addr))
	}
}

// AssertIsUser panics if the caller is not a user realm.
// Used to ensure calls come from user accounts, not other contracts.
func AssertIsUser(r runtime.Realm) {
	if !r.IsUser() {
		panic(ufmt.Errorf("caller is not user"))
	}
}

// assertIsRBAC panics if the caller is not the RBAC contract.
// Used internally to protect role management functions.
func assertIsRBAC(caller address) {
	rbacAddress := chain.PackageAddress(rbacPackagePath)

	if caller != rbacAddress {
		panic(ufmt.Errorf("unauthorized: caller %s is not rbac", caller))
	}
}
