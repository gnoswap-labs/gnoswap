package v2

import (
	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
)

// assertIsPoolOrPositionOrRouterOrStaker panics if the caller is not the pool, router, or staker contract.
func assertIsPoolOrPositionOrRouterOrStaker(caller address) {
	if access.IsAuthorized(prbac.ROLE_POOL.String(), caller) ||
		access.IsAuthorized(prbac.ROLE_POSITION.String(), caller) ||
		access.IsAuthorized(prbac.ROLE_ROUTER.String(), caller) ||
		access.IsAuthorized(prbac.ROLE_STAKER.String(), caller) {
		return
	}

	panic(ufmt.Errorf("unauthorized: caller %s is not pool or position or router or staker", caller))
}

// assertIsAdminOrGovStaker panics if the caller is not admin or gov/staker.
func assertIsAdminOrGovStaker(caller address) {
	if access.IsAuthorized(prbac.ROLE_ADMIN.String(), caller) {
		return
	}

	if access.IsAuthorized(prbac.ROLE_GOV_STAKER.String(), caller) {
		return
	}

	panic(ufmt.Errorf("unauthorized: caller %s is not admin or gov/staker", caller))
}

// assertIsValidPercent panics if the percentage is invalid (not between 0-10000).
func assertIsValidPercent(pct int64) {
	if pct > 10000 {
		panic(makeErrorWithDetail(
			errInvalidPct,
			ufmt.Sprintf("pct(%d) should not be bigger than 10000", pct),
		))
	}

	if pct < 0 {
		panic(makeErrorWithDetail(
			errInvalidPct,
			ufmt.Sprintf("pct(%d) should not be smaller than 0", pct),
		))
	}
}
