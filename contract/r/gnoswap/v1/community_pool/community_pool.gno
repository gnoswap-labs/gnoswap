package community_pool

import (
	"chain"
	"chain/runtime"
	"strconv"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"
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
	halt.AssertIsNotHaltedCommunityPoolWithVersion(1)
	halt.AssertIsNotHaltedWithdrawWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	err := transferToken(tokenPath, to, amount)
	if err != nil {
		panic(err)
	}
}

// transferToken performs actual token transfer.
func transferToken(tokenPath string, to address, amount int64) error {
	common.SafeGRC20Transfer(cross, tokenPath, to, amount)

	prevRealm := runtime.PreviousRealm()
	chain.Emit(
		"TransferToken",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"tokenPath", tokenPath,
		"to", to.String(),
		"amount", strconv.FormatInt(amount, 10),
	)

	return nil
}
