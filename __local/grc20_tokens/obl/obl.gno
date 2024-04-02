package obl

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	pusers "gno.land/p/demo/users"
)

var (
	obl   *grc20.AdminToken
	admin std.Address = "g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq" // TODO: helper to change admin
)

func init() {
	obl = grc20.NewAdminToken("Obl", "OBL", 4)
	obl.Mint(admin, 500_000_000_000_000)
}

// method proxies as public functions.
//

// getters.

func TotalSupply() uint64 {
	return obl.TotalSupply()
}

func BalanceOf(owner pusers.AddressOrName) uint64 {
	balance, err := obl.BalanceOf(users.Resolve(owner))
	if err != nil {
		panic(err.Error())
	}
	return balance
}

func Allowance(owner, spender pusers.AddressOrName) uint64 {
	allowance, err := obl.Allowance(users.Resolve(owner), users.Resolve(spender))
	if err != nil {
		panic(err.Error())
	}
	return allowance
}

// setters.

func Transfer(to pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := obl.Transfer(caller, users.Resolve(to), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := obl.Approve(caller, users.Resolve(spender), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := obl.TransferFrom(caller, users.Resolve(from), users.Resolve(to), amount)
	if err != nil {
		panic(err.Error())
	}
}

// faucet.

func Faucet() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	caller := std.PrevRealm().Addr()
	err := obl.Mint(caller, 100*1_000_000) // 100M
	if err != nil {
		panic(err.Error())
	}
}

// administration.

func Mint(address pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := obl.Mint(users.Resolve(address), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Burn(address pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := obl.Burn(users.Resolve(address), amount)
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
		return obl.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := pusers.AddressOrName(parts[1])
		balance, _ := obl.BalanceOf(users.Resolve(owner))
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
