package access

import (
	"chain"

	prbac "gno.land/p/gnoswap/rbac/v1"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// rbacPackagePath is the package path of the RBAC contract
// Used to verify that role management functions are called only by RBAC
const rbacPackagePath = "gno.land/r/gnoswap/rbac/v1"

// AssertIsRlmCurrent panics if the realm token is not the current crossing frame.
//
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0
//   - rlm: realm context token that must represent the current crossing frame
func AssertIsRlmCurrent(_ int, rlm realm) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}
}

// AssertIsAdminOrGovernance panics unless caller is the configured admin or governance address.
//
// Parameters:
//   - caller: address whose authorization is checked against the admin and governance roles
func AssertIsAdminOrGovernance(caller address) {
	if IsAuthorized(prbac.ROLE_ADMIN.String(), caller) || IsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller) {
		return
	}

	panic(ufmt.Errorf(errUnauthorizedAdminOrGov, caller))
}

// AssertIsAdmin panics unless caller is the configured admin address.
//
// Parameters:
//   - caller: address whose authorization is checked against the admin role
func AssertIsAdmin(caller address) {
	AssertIsAuthorized(prbac.ROLE_ADMIN.String(), caller)
}

// AssertIsGovernance panics unless caller is the configured governance address.
//
// Parameters:
//   - caller: address whose authorization is checked against the governance role
func AssertIsGovernance(caller address) {
	AssertIsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller)
}

// AssertIsGovStaker panics unless caller is the configured governance-staker address.
//
// Parameters:
//   - caller: address whose authorization is checked against the governance-staker role
func AssertIsGovStaker(caller address) {
	AssertIsAuthorized(prbac.ROLE_GOV_STAKER.String(), caller)
}

// AssertIsRouter panics unless caller is the configured router address.
//
// Parameters:
//   - caller: address whose authorization is checked against the router role
func AssertIsRouter(caller address) {
	AssertIsAuthorized(prbac.ROLE_ROUTER.String(), caller)
}

// AssertIsPool panics unless caller is the configured pool address.
//
// Parameters:
//   - caller: address whose authorization is checked against the pool role
func AssertIsPool(caller address) {
	AssertIsAuthorized(prbac.ROLE_POOL.String(), caller)
}

// AssertIsPosition panics unless caller is the configured position address.
//
// Parameters:
//   - caller: address whose authorization is checked against the position role
func AssertIsPosition(caller address) {
	AssertIsAuthorized(prbac.ROLE_POSITION.String(), caller)
}

// AssertIsStaker panics unless caller is the configured staker address.
//
// Parameters:
//   - caller: address whose authorization is checked against the staker role
func AssertIsStaker(caller address) {
	AssertIsAuthorized(prbac.ROLE_STAKER.String(), caller)
}

// AssertIsLaunchpad panics unless caller is the configured launchpad address.
//
// Parameters:
//   - caller: address whose authorization is checked against the launchpad role
func AssertIsLaunchpad(caller address) {
	AssertIsAuthorized(prbac.ROLE_LAUNCHPAD.String(), caller)
}

// AssertIsEmission panics unless caller is the configured emission address.
//
// Parameters:
//   - caller: address whose authorization is checked against the emission role
func AssertIsEmission(caller address) {
	AssertIsAuthorized(prbac.ROLE_EMISSION.String(), caller)
}

// AssertIsProtocolFee panics unless caller is the configured protocol-fee address.
//
// Parameters:
//   - caller: address whose authorization is checked against the protocol-fee role
func AssertIsProtocolFee(caller address) {
	AssertIsAuthorized(prbac.ROLE_PROTOCOL_FEE.String(), caller)
}

// AssertIsGovXGNS panics unless caller is the configured xGNS governance address.
//
// Parameters:
//   - caller: address whose authorization is checked against the xGNS governance role
func AssertIsGovXGNS(caller address) {
	AssertIsAuthorized(prbac.ROLE_XGNS.String(), caller)
}

// AssertIsAuthorized panics if caller does not have the specified role or if the role is absent.
//
// Parameters:
//   - roleName: role identifier whose configured address is required
//   - caller: address that must match the configured address for roleName
func AssertIsAuthorized(roleName string, caller address) {
	addr, ok := GetAddress(roleName)
	if !ok {
		panic(ufmt.Errorf(errRoleNotFound, roleName))
	}

	if caller != addr {
		panic(ufmt.Errorf(errUnauthorized, caller, roleName))
	}
}

// AssertHasAnyRole checks roleNames in order and panics unless caller matches one.
// It panics immediately if a checked role is absent, even if a later role might match.
//
// Parameters:
//   - caller: address compared against each configured role address
//   - roleNames: ordered role identifiers to check; each missing role causes a panic
func AssertHasAnyRole(caller address, roleNames ...string) {
	for _, roleName := range roleNames {
		addr, ok := GetAddress(roleName)
		if !ok {
			panic(ufmt.Errorf(errRoleNotFound, roleName))
		}

		if caller == addr {
			return
		}
	}

	panic(ufmt.Errorf(errUnauthorizedAnyRole, caller, roleNames))
}

// AssertIsValidAddress panics if addr is not a valid address.
//
// Parameters:
//   - addr: address value to validate
func AssertIsValidAddress(addr address) {
	if !addr.IsValid() {
		panic(ufmt.Errorf(errInvalidAddressShort, addr))
	}
}

// assertIsRBAC panics if the caller is not the RBAC contract.
// Used internally to protect role management functions.
func assertIsRBAC(caller address) {
	rbacAddress := chain.PackageAddress(rbacPackagePath)

	if caller != rbacAddress {
		panic(ufmt.Errorf(errUnauthorizedRBAC, caller))
	}
}
