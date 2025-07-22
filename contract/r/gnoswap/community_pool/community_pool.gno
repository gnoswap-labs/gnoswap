package community_pool

import (
	"std"
	"strconv"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/halt"
)

// TransferTokenByAdmin transfers token to the given address.
func TransferTokenByAdmin(cur realm, tokenPath string, to std.Address, amount int64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsHaltedCommunityPool()
	halt.AssertIsHaltedWithdraw()
	access.AssertIsAdmin(caller)

	transferToken(tokenPath, to, amount)
}

// TransferToken transfers token to the given address.
// Only governance contract can execute this function via proposal
func TransferToken(cur realm, tokenPath string, to std.Address, amount int64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsHaltedCommunityPool()
	halt.AssertIsHaltedWithdraw()
	access.AssertIsGovernance(caller)

	transferToken(tokenPath, to, amount)
}

// transferToken transfers token to the given address.
func transferToken(tokenPath string, to std.Address, amount int64) {
	checkErr(common.Transfer(cross, tokenPath, to, amount))

	prevRealm := std.PreviousRealm()

	std.Emit(
		"TransferToken",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"tokenPath", tokenPath,
		"to", to.String(),
		"amount", strconv.FormatInt(amount, 10),
	)
}

// checkErr panics if the error is not nil.
func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}
