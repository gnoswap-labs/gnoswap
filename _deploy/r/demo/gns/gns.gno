package gns

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/gnoswap/consts"
)

const MAXIMUM_SUPPLY = uint64(1_000_000_000_000_000) // 1B

var (
	gns *grc20.AdminToken
)

func init() {
	gns = grc20.NewAdminToken("Gnoswap", "GNS", 6)
	gns.Mint(consts.INTERNAL_REWARD_ACCOUNT, 500_000_000_000_000) // 500_000_000 GNS ≈ 0.5B
	gns.Mint(consts.GNOSWAP_ADMIN, 500_000_000_000_000)           // 500_000_000 GNS ≈ 0.5B

	gns.Approve(consts.INTERNAL_REWARD_ACCOUNT, consts.STAKER_ADDR, consts.UINT64_MAX)
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
		panic(err.Error())
	}
	return balance
}

func Allowance(owner, spender pusers.AddressOrName) uint64 {
	allowance, err := gns.Allowance(users.Resolve(owner), users.Resolve(spender))
	if err != nil {
		panic(err.Error())
	}
	return allowance
}

// setters.

func Transfer(to pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := gns.Transfer(caller, users.Resolve(to), amount)
	if err != nil {
		panic(err.Error())
	}
}

func Approve(spender pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := gns.Approve(caller, users.Resolve(spender), amount)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
	caller := std.PrevRealm().Addr()
	err := gns.TransferFrom(caller, users.Resolve(from), users.Resolve(to), amount)
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
		return gns.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := pusers.AddressOrName(parts[1])
		balance, _ := gns.BalanceOf(users.Resolve(owner))
		return ufmt.Sprintf("%d\n", balance)
	default:
		return "404\n"
	}
}
