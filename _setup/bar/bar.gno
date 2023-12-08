package bar

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	"gno.land/p/demo/testutils"
)

var (
	bar   *grc20.AdminToken
	admin std.Address = "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5" // TODO: helper to change admin
)

func init() {
	bar = grc20.NewAdminToken("Bar", "BAR", 6)
	bar.Mint(admin, 1000000*10000) // @administrator (1M)

	// for swap > pool
	var (
		lp01     = testutils.TestAddress("lp01") // Liquidity Provider 01
		lp02     = testutils.TestAddress("lp02") // Liquidity Provider 02
		lp03     = testutils.TestAddress("lp03") // Liquidity Provider 03
		tr01     = testutils.TestAddress("tr01") // Trader 01
		poolAddr = std.DerivePkgAddr("gno.land/r/pool")
		posAddr  = std.DerivePkgAddr("gno.land/r/position")
	)

	bar.Mint(lp01, 50000000000)
	bar.Mint(lp02, 50000000000)
	bar.Mint(lp03, 50000000000)
	bar.Mint(tr01, 50000000000)

	bar.Approve(lp01, poolAddr, 50000000000)
	bar.Approve(lp02, poolAddr, 50000000000)
	bar.Approve(lp03, poolAddr, 50000000000)
	bar.Approve(tr01, poolAddr, 50000000000)

	// bar.Approve(poolAddr, registryAddr, 50000000000)
}

// method proxies as public functions.
//

// getters.
func GetGRC20() *grc20.AdminToken {
	return bar
}

func TotalSupply() uint64 {
	return bar.TotalSupply()
}

func BalanceOf(owner users.AddressOrName) uint64 {
	balance, err := bar.BalanceOf(owner.Resolve())
	if err != nil {
		panic(err)
	}
	return balance
}

func Allowance(owner, spender users.AddressOrName) uint64 {
	allowance, err := bar.Allowance(owner.Resolve(), spender.Resolve())
	if err != nil {
		panic(err)
	}
	return allowance
}

// setters.

func Transfer(to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := bar.Transfer(caller, to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := bar.Approve(caller, spender.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := bar.TransferFrom(caller, from.Resolve(), to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

// faucet.

func Faucet() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	caller := std.PrevRealm().Addr()
	bar.Mint(caller, 1000*10000) // 1k
}

func FaucetL() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	caller := std.PrevRealm().Addr()
	bar.Mint(caller, 50000000000000) // 50_000_000_000
}

// administration.

func Mint(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	bar.Mint(address.Resolve(), amount)
}

func Burn(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	bar.Burn(address.Resolve(), amount)
}

// render.
//

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return bar.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := users.AddressOrName(parts[1])
		balance, _ := bar.BalanceOf(owner.Resolve())
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
