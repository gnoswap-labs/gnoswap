package gns

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"
)

var (
	gns   *grc20.AdminToken
	admin []string
)

func init() {
	gns = grc20.NewAdminToken("Gnoswap Token", "GNS", 6)

	// for swap > staker
	var (
		poolAddr = std.Address("g1ee305k8yk0pjz443xpwtqdyep522f9g5r7d63w")
		pc01     = std.Address("g1wp3nqv2lta047h6lta047h6lta047h6ltup4ax") // Pool Creator 01

		lp01 = std.Address("g1d3crqv2lta047h6lta047h6lta047h6lnjw069") // Liquidity Provider 01

		tr01 = std.Address("g1w3erqv2lta047h6lta047h6lta047h6lfmmdyv") // Trader 01

		stakerAddr = std.Address("g13h5s9utqcwg3a655njen0p89txusjpfrs3vxp8")
		ira        = std.Address("g1d9exzh6lta047h6lta047h6lta047h6l8ylkpa") // INTERNAL REWARD ACCOUNT
	)

	// CreatePool needs 500 GNS
	gns.Mint(pc01, 50000000000)
	gns.Approve(pc01, poolAddr, 50000000000) // owner, spender, amount

	gns.Mint(ira, 50000000000)
	gns.Approve(ira, stakerAddr, 50000000000)

	// PoolCreate & Mint
	gns.Mint(lp01, 50000000000)
	gns.Approve(lp01, poolAddr, 50000000000)

	// Swap
	gns.Mint(tr01, 50000000000)
	gns.Approve(tr01, poolAddr, 50000000000)

	// default minter
	gns.Mint(std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"), 1000000*10000)

	admin = append(admin, string(stakerAddr))
}

// method proxies as public functions.
//

// getters.
func GetGRC20() *grc20.AdminToken {
	return gns
}

func TotalSupply() uint64 {
	return gns.TotalSupply()
}

func BalanceOf(owner users.AddressOrName) uint64 {
	balance, err := gns.BalanceOf(owner.Resolve())
	if err != nil {
		panic(err)
	}
	return balance
}

func Allowance(owner, spender users.AddressOrName) uint64 {
	allowance, err := gns.Allowance(owner.Resolve(), spender.Resolve())
	if err != nil {
		panic(err)
	}
	return allowance
}

// setters.

func Transfer(to users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	err := gns.Transfer(caller, to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	err := gns.Approve(caller, spender.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	err := gns.TransferFrom(caller, from.Resolve(), to.Resolve(), amount)
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
	gns.Mint(caller, 1000*10000) // 1k
}

func FaucetL() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	gns.Mint(caller, 50000000000) // 50_000_000_000
}

// administration.

func Mint(address users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	gns.Mint(address.Resolve(), amount)
}

func Burn(address users.AddressOrName, amount uint64) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	gns.Burn(address.Resolve(), amount)
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
		return gns.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := users.AddressOrName(parts[1])
		balance, _ := gns.BalanceOf(owner.Resolve())
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
