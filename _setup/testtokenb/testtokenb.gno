package testtokenb

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"
)

var (
	testtokenb *grc20.AdminToken
	admin      std.Address = "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5" // TODO: helper to change admin
)

func init() {
	testtokenb = grc20.NewAdminToken("Test Token B", "TEB", 6)
	testtokenb.Mint(admin, 500_000_000_000_000) // @administrator (1M)
}

// method proxies as public functions.
//

// getters.
func GetGRC20() *grc20.AdminToken {
	return testtokenb
}

func TotalSupply() uint64 {
	return testtokenb.TotalSupply()
}

func BalanceOf(owner users.AddressOrName) uint64 {
	balance, err := testtokenb.BalanceOf(owner.Resolve())
	if err != nil {
		panic(err)
	}
	return balance
}

func Allowance(owner, spender users.AddressOrName) uint64 {
	allowance, err := testtokenb.Allowance(owner.Resolve(), spender.Resolve())
	if err != nil {
		panic(err)
	}
	return allowance
}

// setters.

func Transfer(to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := testtokenb.Transfer(caller, to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := testtokenb.Approve(caller, spender.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := testtokenb.TransferFrom(caller, from.Resolve(), to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

// faucet.
func Faucet() {
	caller := std.PrevRealm().Addr()
	testtokenb.Mint(caller, 1_000_000_000)
}

// administration.
func Mint(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	testtokenb.Mint(address.Resolve(), amount)
}

func Burn(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	testtokenb.Burn(address.Resolve(), amount)
}

// render.
//

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return testtokenb.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := users.AddressOrName(parts[1])
		balance, _ := testtokenb.BalanceOf(owner.Resolve())
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
