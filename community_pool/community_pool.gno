package community_pool

import (
	"std"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v2/consts"
)

func TransferToken(pkgPath string, to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"only admin(%s) or governance(%s) can transfer community pool's balance, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	_, found := registered[pkgPath]
	if !found {
		panic(ufmt.Sprintf("[COMMUNITY_POOL] community_pool.gno__TransferToken() || pkgPath(%s) not registered", pkgPath))
	}

	registered[pkgPath].Transfer()(a2u(to), amount)
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}
