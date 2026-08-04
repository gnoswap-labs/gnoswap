package community_pool

import (
	"chain"
	"strconv"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
)

// GetBalanceOf returns the balance of a specific token held by the community pool.
//
// Parameters:
//   - tokenPath: the path to the token contract (e.g., "gno.land/r/gnoswap/gns")
//
// Returns the balance of the specified token held by the community pool, or an error
// if the token is not registered.
func GetBalanceOf(tokenPath string) (int64, error) {
	communityPoolAddr := access.MustGetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	if err := common.IsRegistered(tokenPath); err != nil {
		return 0, err
	}

	return common.BalanceOf(tokenPath, communityPoolAddr), nil
}

// TransferToken transfers tokens from the community pool.
//
// Parameters:
//   - cur: current realm
//   - tokenPath: token contract path
//   - to: recipient address
//   - amount: transfer amount
//
// Only callable by admin or governance.
func TransferToken(cur realm, tokenPath string, to address, amount int64) {
	halt.AssertIsNotHaltedWithdraw()

	prevRealm := cur.Previous()
	caller := prevRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	common.SafeGRC20Transfer(cross(cur), tokenPath, to, amount)

	chain.Emit(
		"TransferToken",
		"prevAddr", caller.String(),
		"prevRealm", prevRealm.PkgPath(),
		"tokenPath", tokenPath,
		"to", to.String(),
		"amount", strconv.FormatInt(amount, 10),
	)
}
