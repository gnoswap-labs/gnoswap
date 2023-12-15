package st2

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"
)

var (
	st2   *grc20.AdminToken
	admin std.Address = "g16kvq0mra3atvr07lkdwc2x6jqmna8a4kt0e85d" // TODO: helper to change admin
)

func init() {
	st2 = grc20.NewAdminToken("SwapTest2", "ST2", 6)
	st2.Mint(admin, 10_000_000_000_000) // @administrator (1M)
}

// method proxies as public functions.
//

// getters.
func GetGRC20() *grc20.AdminToken {
	return st2
}

func TotalSupply() uint64 {
	return st2.TotalSupply()
}

func BalanceOf(owner users.AddressOrName) uint64 {
	balance, err := st2.BalanceOf(owner.Resolve())
	if err != nil {
		panic(err)
	}
	return balance
}

func Allowance(owner, spender users.AddressOrName) uint64 {
	allowance, err := st2.Allowance(owner.Resolve(), spender.Resolve())
	if err != nil {
		panic(err)
	}
	return allowance
}

// setters.

func Transfer(to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := st2.Transfer(caller, to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := st2.Approve(caller, spender.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := st2.TransferFrom(caller, from.Resolve(), to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

// faucet.
func Faucet() {
	caller := std.PrevRealm().Addr()
	st2.Mint(caller, 1_000_000_000)
}

// administration.
func Mint(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	st2.Mint(address.Resolve(), amount)
}

func Burn(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	st2.Burn(address.Resolve(), amount)
}

// render.
//

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return st2.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := users.AddressOrName(parts[1])
		balance, _ := st2.BalanceOf(owner.Resolve())
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
