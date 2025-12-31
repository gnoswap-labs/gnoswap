package community_pool

import (
	"chain"
	"chain/runtime"
	"strconv"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
)

// TransferToken transfers tokens from the community pool.
//
// Parameters:
//   - tokenPath: token contract path
//   - to: recipient address
//   - amount: transfer amount
//
// Only callable by admin or governance.
func TransferToken(cur realm, tokenPath string, to address, amount int64) {
	halt.AssertIsNotHaltedCommunityPool()
	halt.AssertIsNotHaltedWithdraw()

	prevRealm := runtime.PreviousRealm()
	caller := prevRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	common.SafeGRC20Transfer(cross, tokenPath, to, amount)

	chain.Emit(
		"TransferToken",
		"prevAddr", caller.String(),
		"prevRealm", prevRealm.PkgPath(),
		"tokenPath", tokenPath,
		"to", to.String(),
		"amount", strconv.FormatInt(amount, 10),
	)
}
