package access

import (
	"std"

	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"
)

// AssertIsAdminOrGovernance checks if the caller is the admin or governance and optionally updates the admin or governance address
func AssertIsAdminOrGovernance(caller std.Address) {
	if !IsAuthorized(prbac.ROLE_ADMIN.String(), caller) && !IsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller) {
		panic(ufmt.Errorf("unauthorized: caller %s is not admin or governance", caller))
	}
}

// AssertIsAdmin checks if the caller is the admin and optionally updates the admin address
func AssertIsAdmin(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_ADMIN.String(), caller)
}

// AssertIsGovernance checks if the caller is the governance and optionally updates the governance address
func AssertIsGovernance(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller)
}

// AssertIsGovStaker checks if the caller is the gov staker and optionally updates the gov staker address
func AssertIsGovStaker(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_GOV_STAKER.String(), caller)
}

// AssertIsRouter checks if the caller is the router and optionally updates the router address
func AssertIsRouter(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_ROUTER.String(), caller)
}

// AssertIsPool checks if the caller is the pool and optionally updates the pool address
func AssertIsPool(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_POOL.String(), caller)
}

// AssertIsPosition checks if the caller is the position and optionally updates the position address
func AssertIsPosition(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_POSITION.String(), caller)
}

// AssertIsStaker checks if the caller is the staker and optionally updates the staker address
func AssertIsStaker(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_STAKER.String(), caller)
}

// AssertIsLaunchpad checks if the caller is the launchpad and optionally updates the launchpad address
func AssertIsLaunchpad(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_LAUNCHPAD.String(), caller)
}

// AssertIsEmission checks if the caller is the emission and optionally updates the emission address
func AssertIsEmission(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_EMISSION.String(), caller)
}

// AssertIsProtocolFee checks if the caller is the protocol fee and optionally updates the protocol fee address
func AssertIsProtocolFee(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_PROTOCOL_FEE.String(), caller)
}

// AssertIsGovXGNS checks if the caller is the gov xgns and optionally updates the gov xgns address
func AssertIsGovXGNS(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_XGNS.String(), caller)
}

// AssertIsAuthorized checks if the caller has the given role by comparing addresses
func AssertIsAuthorized(roleName string, caller std.Address) {
	roleAddr, ok := GetAddress(roleName)
	if !ok {
		panic(ufmt.Errorf("role %s does not exist", roleName))
	}

	if caller != roleAddr {
		panic(ufmt.Errorf("unauthorized: caller %s is not %s", caller, roleName))
	}
}

// AssertHasAnyRole checks if the caller has any of the given roles by comparing address
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

// AssertIsValidAddress checks if the address is valid
func AssertIsValidAddress(addr std.Address) {
	if !addr.IsValid() {
		panic(ufmt.Errorf("invalid address: %s", addr))
	}
}

// AssertIsUser checks if the caller is the user and optionally updates the user address
func AssertIsUser(r std.Realm) {
	if !r.IsUser() {
		panic(ufmt.Errorf("caller is not user"))
	}
}

// assertIsRBAC checks if the caller is the rbac and optionally updates the rbac address
func assertIsRBAC(caller std.Address) {
	rbacAddress := std.DerivePkgAddr(rbacPackagePath)

	if caller != rbacAddress {
		panic(ufmt.Errorf("unauthorized: caller %s is not rbac", caller))
	}
}