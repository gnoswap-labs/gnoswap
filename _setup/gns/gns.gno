package gns

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/consts"
)

const MAXIMUM_SUPPLY = uint64(1_000_000_000_000_000)

var (
	gns    *grc20.AdminToken
	admins []string
)

func init() {
	gns = grc20.NewAdminToken("Gnoswap", "GNS", 4)
	gns.Mint(consts.INTERNAL_REWARD_ACCOUNT, 500_000_000_000_000)

	gns.Mint(std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"), 100_000_000_000) // r3v4_xxx: default test1

	stakerAddr := consts.GOV_ADDR
	admins = append(admins, string(stakerAddr))
	admins = append(admins, string(consts.GNOSWAP_ADMIN))

	gns.Approve(consts.INTERNAL_REWARD_ACCOUNT, stakerAddr, consts.UINT64_MAX)
}

// method proxies as public functions.
//

// getters.

func TotalSupply() uint64 {
	return gns.TotalSupply()
}

func BalanceOf(owner pusers.AddressOrName) uint64 {
	balance, err := gns.BalanceOf(users.Resolve(owner))
	if err != nil {
		panic(err)
	}
	return balance
}

func Allowance(owner, spender pusers.AddressOrName) uint64 {
	allowance, err := gns.Allowance(users.Resolve(owner), users.Resolve(spender))
	if err != nil {
		panic(err)
	}
	return allowance
}

// setters.

func Transfer(to pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := gns.Transfer(caller, users.Resolve(to), amount)
	if err != nil {
		panic(err)
	}
}

func Approve(spender pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := gns.Approve(caller, users.Resolve(spender), amount)
	if err != nil {
		panic(err)
	}
}

func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := gns.TransferFrom(caller, users.Resolve(from), users.Resolve(to), amount)
	if err != nil {
		panic(err)
	}
}

// faucet.

func Faucet() {
	// FIXME: add limits?
	// FIXME: add payment in gnot?
	caller := std.PrevRealm().Addr()
	err := gns.Mint(caller, 1000*10000) // 1k
	if err != nil {
		panic(err)
	}
}

// administration.

func Mint(address pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)

	if gns.TotalSupply()+amount <= MAXIMUM_SUPPLY {
		gns.Mint(users.Resolve(address), amount)
	}
}

func Burn(address pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := gns.Burn(users.Resolve(address), amount)
	if err != nil {
		panic(err)
	}
}

func AppendAdmin(address pusers.AddressOrName) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	admins = append(admins, string(users.Resolve(address)))
}

func RemoveAdmin(address pusers.AddressOrName) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	for i, v := range admins {
		if v == string(users.Resolve(address)) {
			admins = append(admins[:i], admins[i+1:]...)
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
		owner := pusers.AddressOrName(parts[1])
		balance, _ := gns.BalanceOf(users.Resolve(owner))
		return ufmt.Sprintf("%d\n", balance)
	default:
		return "404\n"
	}
}

func assertIsAdmin(address std.Address) {
	if !contains(admins, string(address)) {
		panic("not one of admins")
	}
}
func contains(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}
	return false
}
