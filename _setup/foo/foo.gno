package foo

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	"gno.land/p/demo/testutils"
)

var (
	foo   *grc20.AdminToken
	admin std.Address = "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5" // TODO: helper to change admin
)

func init() {
	foo = grc20.NewAdminToken("Foo", "FOO", 6)
	foo.Mint(admin, 1000000*10000) // @administrator (1M)

	// for swap > pool
	var (
		lp01     = testutils.TestAddress("lp01") // Liquidity Provider 01
		lp02     = testutils.TestAddress("lp02") // Liquidity Provider 02
		lp03     = testutils.TestAddress("lp03") // Liquidity Provider 03
		tr01     = testutils.TestAddress("tr01") // Trader 01
		poolAddr = std.DerivePkgAddr("gno.land/r/pool")
		posAddr  = std.DerivePkgAddr("gno.land/r/position")
	)

	foo.Mint(lp01, 50000000000)
	foo.Mint(lp02, 50000000000)
	foo.Mint(lp03, 50000000000)
	foo.Mint(tr01, 50000000000)

	foo.Approve(lp01, poolAddr, 50000000000)
	foo.Approve(lp02, poolAddr, 50000000000)
	foo.Approve(lp03, poolAddr, 50000000000)
	foo.Approve(tr01, poolAddr, 50000000000)

	// foo.Approve(posAddr, poolAddr, 50000000000)
}

// method proxies as public functions.
//

// getters.
func GetGRC20() *grc20.AdminToken {
	return foo
}

func TotalSupply() uint64 {
	return foo.TotalSupply()
}

func BalanceOf(owner users.AddressOrName) uint64 {
	balance, err := foo.BalanceOf(owner.Resolve())
	if err != nil {
		panic(err)
	}
	return balance
}

func Allowance(owner, spender users.AddressOrName) uint64 {
	allowance, err := foo.Allowance(owner.Resolve(), spender.Resolve())
	if err != nil {
		panic(err)
	}
	return allowance
}

// setters.

func Transfer(to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := foo.Transfer(caller, to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := foo.Approve(caller, spender.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := foo.TransferFrom(caller, from.Resolve(), to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

// faucet.

func Faucet() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	caller := std.PrevRealm().Addr()
	foo.Mint(caller, 1000*10000) // 1k
}

func FaucetL() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	caller := std.PrevRealm().Addr()
	foo.Mint(caller, 50000000000) // 50_000_000_000
}

// administration.

func Mint(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	foo.Mint(address.Resolve(), amount)
}

func Burn(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	foo.Burn(address.Resolve(), amount)
}

// render.
//

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return foo.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := users.AddressOrName(parts[1])
		balance, _ := foo.BalanceOf(owner.Resolve())
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
