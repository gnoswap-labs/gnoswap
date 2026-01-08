package community_pool

import (
	"chain"
	"chain/runtime"
	"strconv"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
)

// GetBalanceOf returns the balance of a specific token held by the community pool.
//
// Parameters:
//   - tokenPath: the path to the token contract (e.g., "gno.land/r/gnoswap/gns")
//
// Returns the balance of the specified token held by the community pool.
func GetBalanceOf(tokenPath string) int64 {
	return common.BalanceOf(tokenPath, runtime.CurrentRealm().Address())
}

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
