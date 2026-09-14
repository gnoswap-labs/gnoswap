package community_pool

import (
	"chain"
	"strconv"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
)

// GetBalanceOf returns the community pool's balance for a registered token.
//
// Parameters:
//   - tokenPath: path of the registered token contract
//
// Returns:
//   - balance: token balance held by the community pool
//   - err: non-nil when tokenPath is not registered
func GetBalanceOf(tokenPath string) (int64, error) {
	communityPoolAddr := access.MustGetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	if err := common.IsRegistered(tokenPath); err != nil {
		return 0, err
	}

	return common.BalanceOf(tokenPath, communityPoolAddr), nil
}

// TransferToken transfers a registered token from the community pool.
//
// Parameters:
//   - cur: pass `cross` as argument
//   - tokenPath: path of the registered token contract
//   - to: recipient address
//   - amount: token amount to transfer
//
// Only callable by admin or governance while withdrawals are not halted.
func TransferToken(cur realm, tokenPath string, to address, amount int64) {
	halt.AssertIsNotHaltedWithdraw()

	prevRealm := cur.Previous()
	caller := prevRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	common.SafeGRC20Transfer(0, cur, tokenPath, to, amount)

	chain.Emit(
		"TransferToken",
		"prevAddr", caller.String(),
		"prevRealm", prevRealm.PkgPath(),
		"tokenPath", tokenPath,
		"to", to.String(),
		"amount", strconv.FormatInt(amount, 10),
	)
}
