package community_pool

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

// TransferTokenByAdmin transfers token to the given address.
func TransferTokenByAdmin(pkgPath string, to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"community_pool.gno__TransferTokenByAdmin() || only admin(%s) can transfer token, called from %s",
				consts.ADMIN,
				caller,
			),
		))
	}

	transferToken(pkgPath, to, amount)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"TransferTokenByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pkgPath", pkgPath,
		"to", to.String(),
		"amount", ufmt.Sprintf("%d", amount),
	)
}

// TransferToken transfers token to the given address.
// Only governance contract can execute this function via proposal
func TransferToken(pkgPath string, to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"community_pool.gno__TransferToken() || only governance(%s) can transfer token, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		))
	}

	transferToken(pkgPath, to, amount)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"TransferToken",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pkgPath", pkgPath,
		"to", to.String(),
		"amount", ufmt.Sprintf("%d", amount),
	)
}

func transferToken(pkgPath string, to std.Address, amount uint64) {
	common.IsHalted()

	_, found := registered[pkgPath]
	if !found {
		panic(addDetailToError(
			errNotRegistered,
			ufmt.Sprintf("community_pool.gno__transferToken() || token(%s) not registered", pkgPath),
		))
	}

	registered[pkgPath].Transfer()(a2u(to), amount)
}
