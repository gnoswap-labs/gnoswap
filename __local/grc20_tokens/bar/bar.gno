package bar

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	pusers "gno.land/p/demo/users"
)

var (
	bar   *grc20.AdminToken
	admin std.Address = "g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq" // TODO: helper to change admin
)

func init() {
	bar = grc20.NewAdminToken("Bar", "BAR", 6)
	bar.Mint(admin, 500_000_000_000_000)
}

// method proxies as public functions.
//

// getters.

func TotalSupply() uint64 {
	return bar.TotalSupply()
}

func BalanceOf(owner pusers.AddressOrName) uint64 {
	balance, err := bar.BalanceOf(users.Resolve(owner))
	if err != nil {
		panic(err)
	}
	return balance
}

func Allowance(owner, spender pusers.AddressOrName) uint64 {
	allowance, err := bar.Allowance(users.Resolve(owner), users.Resolve(spender))
	if err != nil {
		panic(err)
	}
	return allowance
}

// setters.

func Transfer(to pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := bar.Transfer(caller, users.Resolve(to), amount)
	if err != nil {
		panic(err)
	}
}

func Approve(spender pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := bar.Approve(caller, users.Resolve(spender), amount)
	if err != nil {
		panic(err)
	}
}

func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := bar.TransferFrom(caller, users.Resolve(from), users.Resolve(to), amount)
	if err != nil {
		panic(err)
	}
}

// faucet.

func Faucet() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	caller := std.PrevRealm().Addr()
	err := bar.Mint(caller, 100*1_000_000) // 100M
	if err != nil {
		panic(err)
	}
}

// administration.

func Mint(address pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := bar.Mint(users.Resolve(address), amount)
	if err != nil {
		panic(err)
	}
}

func Burn(address pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := bar.Burn(users.Resolve(address), amount)
	if err != nil {
		panic(err)
	}
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
		owner := pusers.AddressOrName(parts[1])
		balance, _ := bar.BalanceOf(users.Resolve(owner))
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
