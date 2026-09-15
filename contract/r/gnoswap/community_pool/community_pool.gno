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
//   - tokenPath: registry key/path of the token contract whose balance is queried
//
// Returns:
//   - balance: token units held by the configured community-pool address, or 0 when validation fails
//   - err: nil when tokenPath is valid and registered; non-nil for an invalid or unregistered tokenPath
func GetBalanceOf(tokenPath string) (int64, error) {
	communityPoolAddr := access.MustGetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	if err := common.IsRegistered(tokenPath); err != nil {
		return 0, err
	}

	return common.BalanceOf(tokenPath, communityPoolAddr), nil
}

// TransferToken transfers token units from the community pool to an address.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - tokenPath: registry key/path of the registered token to transfer
//   - to: recipient address for the token units
//   - amount: number of token units to transfer; transfer failure panics through the safe wrapper
//
// Only callable by admin or governance while withdrawals are not halted.
// Governance is the recommended normal route. While governance is not yet
// mature, admin access is retained for emergency-only use as an operational
// policy, not a contract-enforced condition. Admin calls do not require an
// approved proposal; emergency status is not checked and admin access does
// not expire automatically.
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
