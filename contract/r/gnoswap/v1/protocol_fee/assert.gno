package protocol_fee

import (
	"std"

	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
)

// assertIsPoolOrRouterOrStaker panics if the caller is not the pool, router, or staker contract.
func assertIsPoolOrRouterOrStaker(caller std.Address) {
	access.AssertHasAnyRole(
		caller,
		prbac.ROLE_POOL.String(),
		prbac.ROLE_ROUTER.String(),
		prbac.ROLE_STAKER.String(),
	)
}

func assertIsAdminOrGovStaker(caller std.Address) {
	access.AssertHasAnyRole(
		caller,
		prbac.ROLE_ADMIN.String(),
		prbac.ROLE_GOV_STAKER.String(),
	)
}

func assertIsValidPercent(pct uint64) {
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