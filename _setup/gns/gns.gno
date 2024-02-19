package gns

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"
)

var (
	gns    *grc20.AdminToken
	admins []string
)

const (
	admin                   std.Address = "g12l9splsyngcgefrwa52x5a7scc29e9v086m6p4" // r3v4_xxx: CHANGE WHEN DEPLOYING TO OFFICIAL NETWORK
	INTERNAL_REWARD_ACCOUNT std.Address = "g1paqttvcjcluuya9n9twyw7yacv54mt7ld3gvzm" // r3v4_xxx: CHANGE WHEN DEPLOYING TO OFFICIAL NETWORK
)

func init() {
	// r3v4_xxx: SET MAXIMUM SUPPLY

	gns = grc20.NewAdminToken("Gnoswap", "GNS", 6)
	// gns.Mint(admin, 100_000_000_000_000)                                            // @administrator
	gns.Mint(INTERNAL_REWARD_ACCOUNT, 400_000_000_000_000)                             // @INTERNAL_REWARD_ACCOUNT
	gns.Mint(std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"), 100_000_000_000) // default test1

	stakerAddr := std.DerivePkgAddr("gno.land/r/demo/staker")
	admins = append(admins, string(stakerAddr))
	admins = append(admins, string(admin))

	gns.Approve(INTERNAL_REWARD_ACCOUNT, stakerAddr, 9_223_372_036_854_775_807) // max uint64
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
	caller := std.PrevRealm().Addr()
	err := gns.Transfer(caller, to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := gns.Approve(caller, spender.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := gns.TransferFrom(caller, from.Resolve(), to.Resolve(), amount)
	if err != nil {
		panic(err.Error())
	}
}

// faucet.
func Faucet(addr std.Address) { // r3v4_xxx: REMOVE FAUCET WHEN DEPLOYING TO OFFICIAL NETWORK
	gns.Mint(addr, 100_000_000)
}

func FaucetL() { // r3v4_xxx: REMOVE FAUCET WHEN DEPLOYING TO OFFICIAL NETWORK
	caller := std.PrevRealm().Addr()
	gns.Mint(caller, 1_000_000_000_000)
}

// administration.
func Mint(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	gns.Mint(address.Resolve(), amount)
}

func Burn(address users.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	gns.Burn(address.Resolve(), amount)
}

func AppendAdmin(address users.AddressOrName) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	admins = append(admins, string(address.Resolve()))
}

func RemoveAdmin(address users.AddressOrName) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	for i, v := range admins {
		if v == string(address.Resolve()) {
			admins = append(admins[:i], admins[i+1:]...)
			return
		}
	}
}

// render.
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
	if !continas(admins, string(address)) {
		panic("not one of admins")
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
