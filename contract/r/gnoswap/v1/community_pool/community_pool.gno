package community_pool

import (
	"std"
	"strconv"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/halt"
)

// TransferToken transfers token to the given address.
// Only governance contract can execute this function via proposal
func TransferToken(cur realm, tokenPath string, to std.Address, amount int64) {
	halt.AssertIsNotHaltedCommunityPool()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	err := transferToken(tokenPath, to, amount)
	if err != nil {
		panic(err)
	}
}

// transferToken transfers token to the given address.
func transferToken(tokenPath string, to std.Address, amount int64) error {
	err := common.Transfer(cross, tokenPath, to, amount)
	if err != nil {
		return err
	}

	prevRealm := std.PreviousRealm()
	std.Emit(
		"TransferToken",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"tokenPath", tokenPath,
		"to", to.String(),
		"amount", strconv.FormatInt(amount, 10),
	)

	return nil
}