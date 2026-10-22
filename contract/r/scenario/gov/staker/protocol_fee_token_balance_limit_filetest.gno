// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"math"
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/r/gnoswap/access/v1"
	protocolFee "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/onbloc/bar"
)

// With real registered-token balances backing pending fees, an intake that
// would exceed int64 cannot be funded. The token transfer rejects it even
// though lifetime-counter addition deliberately permits rollover.
func main(cur realm) {
	const tokenPath = "gno.land/r/onbloc/bar.BAR"
	admin := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	feeSource := access.MustGetAddress(prbac.ROLE_STAKER.String())
	feeAddress := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())

	testing.SetRealm(testing.NewUserRealm(admin))
	protocolFee.SetDevOpsPct(cross(cur), 10_000)
	bar.Burn(cross(cur), admin, bar.TotalSupply())
	bar.Mint(cross(cur), feeSource, math.MaxInt64)

	testing.SetRealm(testing.NewUserRealm(feeSource))
	bar.Approve(cross(cur), feeAddress, math.MaxInt64)
	protocolFee.AddToProtocolFee(cross(cur), tokenPath, math.MaxInt64-1)
	if bar.TotalSupply() != math.MaxInt64 || bar.BalanceOf(feeAddress) != math.MaxInt64-1 || bar.BalanceOf(feeSource) != 1 {
		panic("fee balance boundary was not backed by the real token ledger")
	}
	if protocolFee.GetAccuTransferToDevOpsByTokenPath(tokenPath) != math.MaxInt64-1 {
		panic("pending fee does not match the funded balance")
	}

	// Leave enough allowance so this rejection proves the balance check.
	bar.Approve(cross(cur), feeAddress, 2)
	println("pending fees are MaxInt64-1; the remaining token balance is 1")
	protocolFee.AddToProtocolFee(cross(cur), tokenPath, 2)
}

// Output:
// pending fees are MaxInt64-1; the remaining token balance is 1

// Error:
// insufficient balance
