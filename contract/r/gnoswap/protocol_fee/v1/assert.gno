package protocol_fee

import (
	prbac "gno.land/p/gnoswap/rbac/v1"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
)

// Order protocol role names. They are not RBAC system roles: admin or
// governance registers them via rbac.RegisterRole, mapped to the order proxy
// realm addresses (gno.land/r/gnoswap/order/dca and gno.land/r/gnoswap/order/limit).
const (
	roleOrderDCA   = "order_dca"
	roleOrderLimit = "order_limit"
)

// assertIsAuthorizedFeeCaller panics unless the caller is a fee-producing realm:
// pool, position, router, staker, or the DCA/limit order realms.
func assertIsAuthorizedFeeCaller(caller address) {
	if access.IsAuthorized(prbac.ROLE_POOL.String(), caller) ||
		access.IsAuthorized(prbac.ROLE_POSITION.String(), caller) ||
		access.IsAuthorized(prbac.ROLE_ROUTER.String(), caller) ||
		access.IsAuthorized(prbac.ROLE_STAKER.String(), caller) ||
		access.IsAuthorized(roleOrderDCA, caller) ||
		access.IsAuthorized(roleOrderLimit, caller) {
		return
	}

	panic(ufmt.Errorf("unauthorized: caller %s is not pool or position or router or staker or order", caller))
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

func assertNotImplementYet() {
	panic("NotImplementYet")
}
