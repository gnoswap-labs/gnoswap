package xgns

import (
	"chain"
	"chain/runtime"
	"strings"

	"gno.land/p/demo/tokens/grc20"
	"gno.land/p/nt/ownable"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"

	prbac "gno.land/p/gnoswap/rbac"
)

var (
	admin         = ownable.NewWithAddress(chain.PackageAddress(prbac.ROLE_GOV_STAKER.String()))
	token, ledger = grc20.NewToken("XGNS", "xGNS", 6)
)

// TotalSupply returns the total supply of xGNS tokens.
func TotalSupply() int64 {
	return token.TotalSupply()
}

// VotingSupply returns total supply eligible for voting.
func VotingSupply() int64 {
	total := token.TotalSupply()
	launchpad, ok := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	if !ok {
		panic("launchpad address not found")
	}

	return total - token.BalanceOf(launchpad)
}

// BalanceOf returns token balance for address.
//
// Parameters:
//   - owner: address to check balance for
//
// Returns balance amount.
func BalanceOf(owner address) int64 {
	return token.BalanceOf(owner)
}

// Render returns a formatted representation of the token state.
func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return token.RenderHome()
	case c == 2 && parts[0] == "balance":
		balance := token.BalanceOf(address(parts[1]))
		return ufmt.Sprintf("%d\n", balance)
	default:
		return "404\n"
	}
}

// Mint mints tokens to address.
//
// Parameters:
//   - to: recipient address
//   - amount: amount to mint
//
// Only callable by governance staker contract.
func Mint(cur realm, to address, amount int64) {
	halt.AssertIsNotHaltedXGns()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)

	checkErr(ledger.Mint(to, amount))
}

// Burn burns tokens from address.
//
// Parameters:
//   - from: address to burn from
//   - amount: amount to burn
//
// Only callable by governance staker contract.
func Burn(cur realm, from address, amount int64) {
	halt.AssertIsNotHaltedXGns()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)

	checkErr(ledger.Burn(from, amount))
}

// BurnByLaunchPad burns tokens from address.
//
// Parameters:
//   - from: address to burn from
//   - amount: amount to burn
//
// Only callable by launchpad contract.
func BurnByLaunchPad(cur realm, from address, amount int64) {
	halt.AssertIsNotHaltedXGns()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsLaunchpad(caller)

	checkErr(ledger.Burn(from, amount))
}
