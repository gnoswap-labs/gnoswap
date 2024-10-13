package community_pool

import (
	"std"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"
)

// TransferTokenByAdmin transfers token to the given address.
// Panics if the caller is not the admin.
func TransferTokenByAdmin(pkgPath string, to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN {
		panic(
			ufmt.Sprintf(
				"[COMMUNITY_POOL] community_pool.gno__TransferTokenByAdmin() || only admin(%s) can transfer token, called from %s",
				consts.GNOSWAP_ADMIN,
				caller,
			),
		)
	}

	transferToken(pkgPath, to, amount)

	prevAddr, prevRealm := common.GetPrev()
	std.Emit(
		"TransferTokenByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pkgPath", pkgPath,
		"to", to,
		"amount", amount,
	)
}

// TransferToken transfers token to the given address.
// Panics if the caller is not the governance contract.
func TransferToken(pkgPath string, to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"[COMMUNITY_POOL] community_pool.gno__TransferToken() || only governance(%s) can transfer token, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	transferToken(pkgPath, to, amount)

	prevAddr, prevRealm := common.GetPrev()
	std.Emit(
		"TransferToken",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pkgPath", pkgPath,
		"to", to,
		"amount", amount,
	)
}

func transferToken(pkgPath string, to std.Address, amount uint64) {
	common.IsHalted()

	_, found := registered[pkgPath]
	if !found {
		panic(ufmt.Sprintf("[COMMUNITY_POOL] community_pool.gno__transferToken() || pkgPath(%s) not registered", pkgPath))
	}

	registered[pkgPath].Transfer()(a2u(to), amount)
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}
