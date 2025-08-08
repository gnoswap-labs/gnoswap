package access

import (
	"std"

	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"
)

// AssertIsAdminOrGovernance requires caller to be admin or governance.
func AssertIsAdminOrGovernance(caller std.Address) {
	if !IsAuthorized(prbac.ROLE_ADMIN.String(), caller) && !IsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller) {
		panic(ufmt.Errorf("unauthorized: caller %s is not admin or governance", caller))
	}
}

// AssertIsAdmin requires caller to be admin.
func AssertIsAdmin(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_ADMIN.String(), caller)
}

// AssertIsGovernance requires caller to be governance.
func AssertIsGovernance(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller)
}

// AssertIsGovStaker requires caller to be governance staker.
func AssertIsGovStaker(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_GOV_STAKER.String(), caller)
}

// AssertIsRouter requires caller to be router.
func AssertIsRouter(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_ROUTER.String(), caller)
}

// AssertIsPool requires caller to be pool.
func AssertIsPool(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_POOL.String(), caller)
}

// AssertIsPosition requires caller to be position.
func AssertIsPosition(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_POSITION.String(), caller)
}

// AssertIsStaker requires caller to be staker.
func AssertIsStaker(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_STAKER.String(), caller)
}

// AssertIsLaunchpad requires caller to be launchpad.
func AssertIsLaunchpad(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_LAUNCHPAD.String(), caller)
}

// AssertIsEmission requires caller to be emission.
func AssertIsEmission(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_EMISSION.String(), caller)
}

// AssertIsProtocolFee requires caller to be protocol fee.
func AssertIsProtocolFee(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_PROTOCOL_FEE.String(), caller)
}

// AssertIsGovXGNS requires caller to be xGNS governance.
func AssertIsGovXGNS(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_XGNS.String(), caller)
}

// AssertIsAuthorized requires caller to have the specified role.
func AssertIsAuthorized(roleName string, caller std.Address) {
	roleAddr, ok := GetAddress(roleName)
	if !ok {
		panic(ufmt.Errorf("role %s does not exist", roleName))
	}

	if caller != roleAddr {
		panic(ufmt.Errorf("unauthorized: caller %s is not %s", caller, roleName))
	}
}

// AssertHasAnyRole requires caller to have at least one of the specified roles.
func AssertHasAnyRole(caller std.Address, roleNames ...string) {
	for _, roleName := range roleNames {
		roleAddr, ok := GetAddress(roleName)
		if !ok {
			panic(ufmt.Errorf("role %s does not exist", roleName))
		}

		if caller == roleAddr {
			return
		}
	}

	panic(ufmt.Errorf("unauthorized: caller %s is not any of the roles %v", caller, roleNames))
}

// AssertIsValidAddress requires a valid address.
func AssertIsValidAddress(addr std.Address) {
	if !addr.IsValid() {
		panic(ufmt.Errorf("invalid address: %s", addr))
	}
}

// AssertIsUser requires caller to be a user realm.
func AssertIsUser(r std.Realm) {
	if !r.IsUser() {
		panic(ufmt.Errorf("caller is not user"))
	}
}

// AssertIsSwapWhitelisted requires caller to be on the swap whitelist.
func AssertIsSwapWhitelisted(caller std.Address) {
	if !IsSwapWhitelisted(caller) {
		panic(ufmt.Errorf("unauthorized: caller %s is not a whitelisted router", caller))
	}
}

// assertIsRBAC requires caller to be the RBAC contract.
func assertIsRBAC(caller std.Address) {
	rbacAddress := std.DerivePkgAddr(rbacPackagePath)

	if caller != rbacAddress {
		panic(ufmt.Errorf("unauthorized: caller %s is not rbac", caller))
	}
}
