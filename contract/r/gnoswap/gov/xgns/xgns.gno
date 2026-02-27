package xgns

import (
	"chain"
	"chain/runtime"
	"errors"
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
//
// Returns:
//   - supply: total xGNS token supply
func TotalSupply() int64 {
	return token.TotalSupply()
}

// BalanceOf returns token balance for address.
//
// Parameters:
//   - owner: address to check balance for
//
// Returns:
//   - balance: token balance amount
func BalanceOf(owner address) int64 {
	return token.BalanceOf(owner)
}

// Render returns a formatted representation of the token state.
//
// Parameters:
//   - path: render path for specific views
//
// Returns:
//   - output: formatted token state representation
func Render(path string) string {
	if path == "" {
		return token.RenderHome()
	}

	parts := strings.Split(path, "/")
	switch parts[0] {
	case "balance":
		if len(parts) != 2 {
			return "404\n"
		}
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

// SupplyInfo returns supply breakdown information.
//
// Returns:
//   - totalIssued: total xGNS tokens issued
//   - issuedByDelegate: tokens issued through governance delegation
//   - issuedByDepositGns: tokens issued through launchpad deposit
//   - error: error if launchpad address not found
func SupplyInfo() (totalIssued, issuedByDelegate, issuedByDepositGns int64, err error) {
	launchpad, ok := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	if !ok {
		return 0, 0, 0, errors.New("launchpad address not found")
	}

	totalIssued = token.TotalSupply()
	issuedByDepositGns = token.BalanceOf(launchpad)
	issuedByDelegate = totalIssued - issuedByDepositGns

	return totalIssued, issuedByDelegate, issuedByDepositGns, nil
}

func checkErr(err error) {
	if err != nil {
		panic(err)
	}
}
