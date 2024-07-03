package gns

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/gnoswap/consts"
)

const MAXIMUM_SUPPLY = uint64(1_000_000_000_000_000) // 1B

var (
	deployedHeight   int64
	deployedAt       time.Time
	lastMintedHeight int64
	amountToEmission uint64
)

var (
	gns *grc20.AdminToken
)

func init() {
	gns = grc20.NewAdminToken("Gnoswap", "GNS", 6)
	gns.Mint(consts.GNOSWAP_ADMIN, 100_000_000_000_000) // 100_000_000 GNS ≈ 0.1B

	amountToEmission = MAXIMUM_SUPPLY - uint64(100_000_000_000_000)

	height := std.GetHeight()
	deployedHeight = height
	deployedAt = time.Now()
	lastMintedHeight = 0
}

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

// Mint
func Mint(address pusers.AddressOrName) {
	// only emission contract can call Mint
	caller := std.PrevRealm().Addr()
	if caller != consts.EMISSION_ADDR {
		panic("only emission contract can call Mint")
	}

	nowHeight := std.GetHeight()
	for i := lastMintedHeight + 1; i <= nowHeight; i++ {
		amount := getAmountByHeight(i)
		err := gns.Mint(users.Resolve(address), amount)
		if err != nil {
			panic(err.Error())
		}
		lastMintedHeight = i

		// debug
		// println("height:", i, "minted:", amount)
	}
}

// ONLY FOR EMISSION TESTING, REMOVE THIS FUNCTION IN PRODUCTION
func TestSetLastMintedHeight(height int64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.EMISSION_ADDR {
		panic("only emission contract can call TestSetLastMintedHeight")
	}
	lastMintedHeight = height
}
