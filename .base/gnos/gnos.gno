package gnos

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"
)

var (
	gnos  *grc20.AdminToken
	admin []string
)

func init() {
	gnos = grc20.NewAdminToken("Gnoswap Shares", "GNOS", 4)

	stakerAddr := std.DerivePkgAddr("gno.land/r/staker")
	admin = append(admin, string(stakerAddr))
}

// method proxies as public functions.
//

// getters.
func GetGRC20() *grc20.AdminToken {
	return gnos
}

func TotalSupply() uint64 {
	return gnos.TotalSupply()
}

func BalanceOf(owner users.AddressOrName) uint64 {
	balance, err := gnos.BalanceOf(owner.Resolve())
	if err != nil {
		panic(err)
	}
	return balance
}

func Allowance(owner, spender users.AddressOrName) uint64 {
	allowance, err := gnos.Allowance(owner.Resolve(), spender.Resolve())
	if err != nil {
		panic(err)
	}
	return allowance
}

// setters.

func Transfer(to users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	err := gnos.Transfer(caller, to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	err := gnos.Approve(caller, spender.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	err := gnos.TransferFrom(caller, from.Resolve(), to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

// faucet.

func Faucet() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	gnos.Mint(caller, 1000*10000) // 1k
}

func FaucetL() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	gnos.Mint(caller, 50000000000) // 50_000_000_000
}

// administration.

func Mint(address users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	gnos.Mint(address.Resolve(), amount)
}

func Burn(address users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	gnos.Burn(address.Resolve(), amount)
}

func AppendAdmin(address users.AddressOrName) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	admin = append(admin, string(address.Resolve()))
}

func RemoveAdmin(address users.AddressOrName) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	for i, v := range admin {
		if v == string(address.Resolve()) {
			admin = append(admin[:i], admin[i+1:]...)
			return
		}
	}
}

// render.
//

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return gnos.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := users.AddressOrName(parts[1])
		balance, _ := gnos.BalanceOf(owner.Resolve())
		return ufmt.Sprintf("%d\n", balance)
	default:
		return "404\n"
	}
}

func assertIsAdmin(address std.Address) {
	if !continas(admin, string(address)) {
		panic("not admin")
	}
}

func continas(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}
	return false
}
