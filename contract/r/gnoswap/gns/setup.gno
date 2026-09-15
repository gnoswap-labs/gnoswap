package gns

import (
	"gno.land/p/gnoswap/rbac/v1"
	"gno.land/r/gnoswap/access"
)

// setupPreMint mints the initial GNS supply
// (INITIAL_MINT_AMOUNT = 100_000_000_000_000, i.e. 100M GNS with 6 decimals) at realm init.
//
// The full amount is minted to the ADMIN role address.
func setupPreMint(cur realm) {
	adminAddr := access.MustGetAddress(rbac.ROLE_ADMIN.String())
	err := privateLedger.Mint(adminAddr, INITIAL_MINT_AMOUNT)
	if err != nil {
		panic(err.Error())
	}
}
