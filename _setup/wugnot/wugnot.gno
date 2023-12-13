// ** IMPORTANT **
/*
This realm is meant to be support swapping between GRC20 tokens and native coins.
It is not meant to be used as a standalone token.
User can not call transfer not transferFrom only gnoswap can.

All of admin related funcitons and Facuet() will be removed in the future.
*/

package wugnot

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	"gno.land/p/demo/testutils"
)

var (
	wugnot *grc20.AdminToken
	admin  std.Address = "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5" // TODO: helper to change admin

	poolAddr   = std.DerivePkgAddr("gno.land/r/demo/pool")
	posAddr    = std.DerivePkgAddr("gno.land/r/demo/position")
	routerAddr = std.DerivePkgAddr("gno.land/r/demo/router")
	stakerAddr = std.DerivePkgAddr("gno.land/r/demo/staker")
)

func init() {
	wugnot = grc20.NewAdminToken("WrappedUGNOT", "WUGNOT", 6)

	// for swap
	var (
		lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
		lp02 = testutils.TestAddress("lp02") // Liquidity Provider 02
		lp03 = testutils.TestAddress("lp03") // Liquidity Provider 03
		tr01 = testutils.TestAddress("tr01") // Trader 01
		ci01 = testutils.TestAddress("ci01") // Create Incentive Caller
	)

	wugnot.Approve(lp01, poolAddr, 50000000000)
	wugnot.Approve(lp02, poolAddr, 50000000000)
	wugnot.Approve(lp03, poolAddr, 50000000000)
	wugnot.Approve(tr01, poolAddr, 50000000000)

	wugnot.Approve(ci01, stakerAddr, 50000000000)
}

// method proxies as public functions.
//

// getters.
func GetGRC20() *grc20.AdminToken {
	return wugnot
}

func TotalSupply() uint64 {
	return wugnot.TotalSupply()
}

func BalanceOf(owner users.AddressOrName) uint64 {
	balance, err := wugnot.BalanceOf(owner.Resolve())
	if err != nil {
		panic(err)
	}
	return balance
}

func Allowance(owner, spender users.AddressOrName) uint64 {
	allowance, err := wugnot.Allowance(owner.Resolve(), spender.Resolve())
	if err != nil {
		panic(err)
	}
	return allowance
}

// setters.

// faucet.

func Faucet() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	caller := std.PrevRealm().Addr()
	wugnot.Mint(caller, 1000*10000) // 1k
}

func FaucetL() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	caller := std.PrevRealm().Addr()
	wugnot.Mint(caller, 50000000000000) // 50_000_000_000
}

// administration.

func Mint(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	wugnot.Mint(address.Resolve(), amount)
}

func Burn(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	wugnot.Burn(address.Resolve(), amount)
}

// render.
//

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return wugnot.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := users.AddressOrName(parts[1])
		balance, _ := wugnot.BalanceOf(owner.Resolve())
		return ufmt.Sprintf("%d\n", balance)
	default:
		return "404\n"
	}
}

func assertIsAdmin(address std.Address) {
	if address != admin {
		panic("restricted access")
	}
}

// WRAP & UNWRAP
func Wrap(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	if !(caller == poolAddr || caller == posAddr || caller == routerAddr || caller == stakerAddr) {
		panic("only pool, position, router, staker contract can wrap")
	}

	wugnot.Mint(address.Resolve(), amount) // mint to user
}

func Unwrap(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	if !(caller == poolAddr || caller == posAddr || caller == routerAddr || caller == stakerAddr) {
		panic("only pool, position, router, staker contract can unwrap")
	}

	wugnot.Burn(address.Resolve(), amount) // burn from user
}

func Transfer(to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	if !(caller == poolAddr || caller == posAddr || caller == routerAddr || caller == stakerAddr) {
		panic("only pool, position, router, staker contract can transfer")
	}
	err := wugnot.Transfer(caller, to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	if !(caller == poolAddr || caller == posAddr || caller == routerAddr || caller == stakerAddr) {
		panic("only pool, position, router, staker contract can transferFrom")
	}
	err := wugnot.TransferFrom(caller, from.Resolve(), to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := wugnot.Approve(caller, spender.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}
