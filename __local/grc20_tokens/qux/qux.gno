package qux

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	pusers "gno.land/p/demo/users"
)

var (
	qux   *grc20.AdminToken
	admin std.Address = "g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq"
)

func init() {
	qux = grc20.NewAdminToken("Qux", "QUX", 6)
	qux.Mint(admin, 100_000_000_000_000)
}

// method proxies as public functions.
//

// getters.

func TotalSupply() uint64 {
	return qux.TotalSupply()
}

func BalanceOf(owner pusers.AddressOrName) uint64 {
	balance, err := qux.BalanceOf(users.Resolve(owner))
	if err != nil {
		panic(err.Error())
	}
	return balance
}

func Allowance(owner, spender pusers.AddressOrName) uint64 {
	allowance, err := qux.Allowance(users.Resolve(owner), users.Resolve(spender))
	if err != nil {
		panic(err.Error())
	}
	return allowance
}

// setters.

func Transfer(to pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := qux.Transfer(caller, users.Resolve(to), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := qux.Approve(caller, users.Resolve(spender), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := qux.TransferFrom(caller, users.Resolve(from), users.Resolve(to), amount)
	if err != nil {
		panic(err.Error())
	}
}

// faucet.

func Faucet() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	caller := std.PrevRealm().Addr()
	err := qux.Mint(caller, 100*1_000_000) // 100M
	if err != nil {
		panic(err.Error())
	}
}

// administration.

func Mint(address pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := qux.Mint(users.Resolve(address), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Burn(address pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := qux.Burn(users.Resolve(address), amount)
	if err != nil {
		panic(err.Error())
	}
}

// render.
//

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return qux.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := pusers.AddressOrName(parts[1])
		balance, _ := qux.BalanceOf(users.Resolve(owner))
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
