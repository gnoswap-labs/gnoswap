package xgns

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/users"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

var (
	banker *grc20.Banker
	admin  *ownable.Ownable
	token  grc20.Token
)

func init() {
	admin = ownable.NewWithAddress(std.DerivePkgAddr(consts.GOV_STAKER_PATH))

	banker = grc20.NewBanker("XGNS", "xGNS", 6)
	token = banker.Token()
}

func TotalSupply() uint64 { return token.TotalSupply() }

func VotingSupply() uint64 {
	total := token.TotalSupply() // this is entire amount of xGNS minted

	// this is amount of xGNS held by launchpad
	// this xGNS doesn't participate in voting
	launchpad := token.BalanceOf(consts.LAUNCHPAD_ADDR)
	return total - launchpad
}

func BalanceOf(owner pusers.AddressOrName) uint64 {
	ownerAddr := users.Resolve(owner)
	return token.BalanceOf(ownerAddr)
}

// xGNS is non-transferable
// Therefore it doesn't have transfer and transferFrom functions

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return banker.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := pusers.AddressOrName(parts[1])
		ownerAddr := users.Resolve(owner)
		balance := banker.BalanceOf(ownerAddr)
		return ufmt.Sprintf("%d\n", balance)
	default:
		return "404\n"
	}
}

func Mint(to pusers.AddressOrName, amount uint64) {
	common.IsHalted()

	// only (gov staker) or (launchpad) contract can call Mint
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_STAKER_ADDR && caller != consts.LAUNCHPAD_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only gov/staker(%s) or launchpad(%s) contract can call Mint, called from %s", consts.GOV_STAKER_ADDR.String(), consts.LAUNCHPAD_ADDR.String(), caller.String()),
		))
	}

	checkErr(banker.Mint(users.Resolve(to), amount))
}

func Burn(from pusers.AddressOrName, amount uint64) {
	common.IsHalted()

	// only (gov staker) or (launchpad) contract can call Mint
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_STAKER_ADDR && caller != consts.LAUNCHPAD_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only gov/staker(%s) or launchpad(%s) contract can call Burn, called from %s", consts.GOV_STAKER_ADDR.String(), consts.LAUNCHPAD_ADDR.String(), caller.String()),
		))
	}

	checkErr(banker.Burn(users.Resolve(from), amount))
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}
