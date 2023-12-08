package obl

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/users"
)

var (
	obl   *grc20.AdminToken
	admin std.Address = "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5" // TODO: helper to change admin
)

func init() {
	obl = grc20.NewAdminToken("OnblocToken", "OBL", 6)
	obl.Mint(admin, 50000000000) // 50_000_000_000

	// for swap > staker
	var (
		ci01       = std.Address("g1vd5nqv2lta047h6lta047h6lta047h6lk0whcd")
		stakerAddr = std.Address("g13h5s9utqcwg3a655njen0p89txusjpfrs3vxp8")
		poolAddr   = std.Address("g1ee305k8yk0pjz443xpwtqdyep522f9g5r7d63w")
	)
	obl.Mint(ci01, 50000000000)                // 50_000_000_000
	obl.Approve(ci01, stakerAddr, 50000000000) // owner, spender, amount

	obl.Approve(poolAddr, stakerAddr, 50000000000) // owner, spender, amount
}

// method proxies as public functions.
//

// getters.
func GetGRC20() *grc20.AdminToken {
	return obl
}

func TotalSupply() uint64 {
	return obl.TotalSupply()
}

func BalanceOf(owner users.AddressOrName) uint64 {
	balance, err := obl.BalanceOf(owner.Resolve())
	if err != nil {
		panic(err)
	}
	return balance
}

func Allowance(owner, spender users.AddressOrName) uint64 {
	allowance, err := obl.Allowance(owner.Resolve(), spender.Resolve())
	if err != nil {
		panic(err)
	}
	return allowance
}

// setters.

func Transfer(to users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	err := obl.Transfer(caller, to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	err := obl.Approve(caller, spender.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	err := obl.TransferFrom(caller, from.Resolve(), to.Resolve(), amount)
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
	obl.Mint(caller, 1000*10000) // 1k
}

func FaucetL() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	obl.Mint(caller, 50000000000) // 50_000_000_000
}

// administration.

func Mint(address users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	obl.Mint(address.Resolve(), amount)
}

func Burn(address users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	obl.Burn(address.Resolve(), amount)
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
		owner := users.AddressOrName(parts[1])
		balance, _ := obl.BalanceOf(owner.Resolve())
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
