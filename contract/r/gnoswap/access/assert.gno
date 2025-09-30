package access

import (
	"std"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"
)

// AssertIsAdminOrGovernance panics if the caller is not admin or governance.
// Used for functions that require elevated privileges.
func AssertIsAdminOrGovernance(caller std.Address) {
	if IsAuthorized(prbac.ROLE_ADMIN.String(), caller) || IsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller) {
		return
	}

	panic(ufmt.Errorf("unauthorized: caller %s is not admin or governance", caller))
}

// AssertIsAdmin panics if the caller is not admin.
// Used for admin-only functions.
func AssertIsAdmin(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_ADMIN.String(), caller)
}

// AssertIsGovernance panics if the caller is not governance.
// Used for governance-only functions.
func AssertIsGovernance(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller)
}

// AssertIsGovStaker panics if the caller is not governance staker.
// Used for governance staking functions.
func AssertIsGovStaker(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_GOV_STAKER.String(), caller)
}

// AssertIsRouter panics if the caller is not router.
// Used for router-only functions.
func AssertIsRouter(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_ROUTER.String(), caller)
}

// AssertIsPool panics if the caller is not pool.
// Used for pool-only functions.
func AssertIsPool(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_POOL.String(), caller)
}

// AssertIsPosition panics if the caller is not position.
// Used for position-only functions.
func AssertIsPosition(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_POSITION.String(), caller)
}

// AssertIsStaker panics if the caller is not staker.
// Used for staker-only functions.
func AssertIsStaker(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_STAKER.String(), caller)
}

// AssertIsLaunchpad panics if the caller is not launchpad.
// Used for launchpad-only functions.
func AssertIsLaunchpad(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_LAUNCHPAD.String(), caller)
}

// AssertIsEmission panics if the caller is not emission.
// Used for emission-only functions.
func AssertIsEmission(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_EMISSION.String(), caller)
}

// AssertIsProtocolFee panics if the caller is not protocol fee.
// Used for protocol fee management functions.
func AssertIsProtocolFee(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_PROTOCOL_FEE.String(), caller)
}

// AssertIsGovXGNS panics if the caller is not xGNS governance.
// Used for xGNS governance functions.
func AssertIsGovXGNS(caller std.Address) {
	AssertIsAuthorized(prbac.ROLE_XGNS.String(), caller)
}

// AssertIsAdminOrGovernance panics if the caller is not admin or governance.
// Used for functions that require elevated privileges.
func AssertIsAdminOrGovernanceWithVersion(version int, caller std.Address) {
	if !IsAuthorized(prbac.ROLE_ADMIN.String(), caller) && !IsAuthorizedWithVersion(prbac.ROLE_GOVERNANCE.String(), version, caller) {
		panic(ufmt.Errorf("unauthorized: caller %s is not admin or governance", caller))
	}
}

// AssertIsGovernanceWithVersion panics if the caller is not governance.
// Used for governance-only functions.
func AssertIsGovernanceWithVersion(version int, caller std.Address) {
	AssertIsAuthorizedWithVersion(prbac.ROLE_GOVERNANCE.String(), version, caller)
}

// AssertIsGovStakerWithVersion panics if the caller is not governance staker.
// Used for governance staking functions.
func AssertIsGovStakerWithVersion(version int, caller std.Address) {
	AssertIsAuthorizedWithVersion(prbac.ROLE_GOV_STAKER.String(), version, caller)
}

// AssertIsRouterWithVersion panics if the caller is not router.
// Used for router-only functions.
func AssertIsRouterWithVersion(version int, caller std.Address) {
	AssertIsAuthorizedWithVersion(prbac.ROLE_ROUTER.String(), version, caller)
}

// AssertIsPoolWithVersion panics if the caller is not pool.
// Used for pool-only functions.
func AssertIsPoolWithVersion(version int, caller std.Address) {
	AssertIsAuthorizedWithVersion(prbac.ROLE_POOL.String(), version, caller)
}

// AssertIsPositionWithVersion panics if the caller is not position.
// Used for position-only functions.
func AssertIsPositionWithVersion(version int, caller std.Address) {
	AssertIsAuthorizedWithVersion(prbac.ROLE_POSITION.String(), version, caller)
}

// AssertIsStakerWithVersion panics if the caller is not staker.
// Used for staker-only functions.
func AssertIsStakerWithVersion(version int, caller std.Address) {
	AssertIsAuthorizedWithVersion(prbac.ROLE_STAKER.String(), version, caller)
}

// AssertIsLaunchpadWithVersion panics if the caller is not launchpad.
// Used for launchpad-only functions.
func AssertIsLaunchpadWithVersion(version int, caller std.Address) {
	AssertIsAuthorizedWithVersion(prbac.ROLE_LAUNCHPAD.String(), version, caller)
}

// AssertIsProtocolFeeWithVersion panics if the caller is not protocol fee.
// Used for protocol fee management functions.
func AssertIsProtocolFeeWithVersion(version int, caller std.Address) {
	AssertIsAuthorizedWithVersion(prbac.ROLE_PROTOCOL_FEE.String(), version, caller)
}

// AssertIsGovXGNSWithVersion panics if the caller is not xGNS governance.
// Used for xGNS governance functions.
func AssertIsGovXGNSWithVersion(version int, caller std.Address) {
	AssertIsAuthorizedWithVersion(prbac.ROLE_XGNS.String(), version, caller)
}

// AssertIsAuthorized panics if the caller does not have the specified role.
// Also panics if the role does not exist.
func AssertIsAuthorized(roleName string, caller std.Address) {
	if !IsAuthorized(roleName, caller) {
		if _, ok := GetAddress(roleName); !ok {
			panic(ufmt.Errorf("role %s does not exist", roleName))
		}

		panic(ufmt.Errorf("unauthorized: caller %s is not %s", caller, roleName))
	}
}

// AssertIsAuthorizedWithVersion panics if the caller does not have the specified role.
// Also panics if the role does not exist.
func AssertIsAuthorizedWithVersion(roleName string, version int, caller std.Address) {
	if !IsAuthorizedWithVersion(roleName, version, caller) {
		if _, ok := GetAddressWithVersion(roleName, version); !ok {
			panic(ufmt.Errorf("role %s does not exist", roleName))
		}

		panic(ufmt.Errorf("unauthorized: caller %s is not %s", caller, roleName))
	}
}

// AssertHasAnyRole panics if the caller does not have any of the specified roles.
// Also panics if any of the roles do not exist.
func AssertHasAnyRole(caller std.Address, roleNames ...string) {
	for _, roleName := range roleNames {
		if _, ok := GetAddress(roleName); !ok {
			panic(ufmt.Errorf("role %s does not exist", roleName))
		}

		if IsAuthorized(roleName, caller) {
			return
		}
	}

	panic(ufmt.Errorf("unauthorized: caller %s is not any of the roles %v", caller, roleNames))
}

// AssertHasAnyRoleWithVersion panics if the caller does not have any of the specified roles.
// Also panics if any of the roles do not exist.
func AssertHasAnyRoleWithVersion(version int, caller std.Address, roleNames ...string) {
	for _, roleName := range roleNames {
		if _, ok := GetAddressWithVersion(roleName, version); !ok {
			panic(ufmt.Errorf("role %s does not exist", roleName))
		}

		if IsAuthorizedWithVersion(roleName, version, caller) {
			return
		}
	}

	panic(ufmt.Errorf("unauthorized: caller %s is not any of the roles %v", caller, roleNames))
}

// AssertIsValidAddress panics if the provided address is invalid.
func AssertIsValidAddress(addr std.Address) {
	if !addr.IsValid() {
		panic(ufmt.Errorf("invalid address: %s", addr))
	}
}

// AssertIsUser panics if the caller is not a user realm.
// Used to ensure calls come from user accounts, not other contracts.
func AssertIsUser(r std.Realm) {
	if !r.IsUser() {
		panic(ufmt.Errorf("caller is not user"))
	}
}

// AssertIsSwapWhitelisted panics if the caller is not on the swap whitelist.
// Used to restrict swap operations to authorized routers only.
func AssertIsSwapWhitelisted(caller std.Address) {
	if !IsSwapWhitelisted(caller) {
		panic(ufmt.Errorf("unauthorized: caller %s is not a whitelisted router", caller))
	}
}

// assertIsRBAC panics if the caller is not the RBAC contract.
// Used internally to protect role management functions.
func assertIsRBAC(caller std.Address) {
	rbacAddress := std.DerivePkgAddr(rbacPackagePath)

	if caller != rbacAddress {
		panic(ufmt.Errorf("unauthorized: caller %s is not rbac", caller))
	}
}
