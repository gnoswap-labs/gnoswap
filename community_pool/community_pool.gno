package community_pool

import (
	"std"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/gns"

	"gno.land/r/gnoswap/consts"
)

func TransferGns(to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"[COMMUNITY_POOL] community_pool.gno__TransferGns() || only admin(%s) or governance(%s) can set transfer gns, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	gns.Transfer(a2u(to), amount)
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}
