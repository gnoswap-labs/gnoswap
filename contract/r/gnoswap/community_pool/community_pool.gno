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
	assertOnlyNotHalted()
	assertOnlyAdmin()

	transferToken(tokenPath, to, amount)
}

// TransferToken transfers token to the given address.
// Only governance contract can execute this function via proposal
func TransferToken(cur realm, tokenPath string, to std.Address, amount int64) {
	assertOnlyNotHalted()
	assertOnlyGovernance()

	transferToken(tokenPath, to, amount)
}

// transferToken transfers token to the given address.
func transferToken(tokenPath string, to std.Address, amount int64) {
	checkErr(common.Transfer(cross, tokenPath, to, amount))

	prevAddr, prevPkgPath := getPrevAsString()

	std.Emit(
		"TransferToken",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
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

// assertOnlyNotHalted panics if the contract is halted.
func assertOnlyNotHalted() {
	if halt.IsHaltedCommunityPool() {
		panic("community pool contract operations are currently disabled")
	}

	if halt.IsHaltedWithdraw() {
		panic("community pool contract withdrawals are currently disabled")
	}
}

// assertOnlyAdmin panics if the caller is not the admin.
func assertOnlyAdmin() {
	caller := getPrevAddr()
	access.AssertIsAdmin(caller)
}

// assertOnlyGovernance panics if the caller is not the governance.
func assertOnlyGovernance() {
	caller := getPrevAddr()
	access.AssertIsGovernance(caller)
}

// getPrevAddr returns the address of the caller.
func getPrevAddr() std.Address {
	return std.PreviousRealm().Address()
}

// getPrevAsString returns the address and realm of the caller as a string.
func getPrevAsString() (string, string) {
	prev := std.PreviousRealm()
	return prev.Address().String(), prev.PkgPath()
}
