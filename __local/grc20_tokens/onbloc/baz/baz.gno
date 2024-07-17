package baz

import (
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"
	"gno.land/r/demo/users"
)

var (
	banker *grc20.Banker
	admin  *ownable.Ownable
	token  grc20.Token
)

func init() {
	admin = ownable.NewWithAddress("g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c") // GNOSWAP_ADMIN
	banker = grc20.NewBanker("Baz", "BAZ", 6)
	banker.Mint(admin.Owner(), 100_000_000_000_000)
	token = banker.Token()
}

func TotalSupply() uint64 { return token.TotalSupply() }

func BalanceOf(owner pusers.AddressOrName) uint64 {
	ownerAddr := users.Resolve(owner)
	return token.BalanceOf(ownerAddr)
}

func Allowance(owner, spender pusers.AddressOrName) uint64 {
	ownerAddr := users.Resolve(owner)
	spenderAddr := users.Resolve(spender)
	return token.Allowance(ownerAddr, spenderAddr)
}

func Transfer(to pusers.AddressOrName, amount uint64) {
	toAddr := users.Resolve(to)
	checkErr(token.Transfer(toAddr, amount))
}

func Approve(spender pusers.AddressOrName, amount uint64) {
	spenderAddr := users.Resolve(spender)
	checkErr(token.Approve(spenderAddr, amount))
}

func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
	fromAddr := users.Resolve(from)
	toAddr := users.Resolve(to)
	checkErr(token.TransferFrom(fromAddr, toAddr, amount))
}

func Burn(from pusers.AddressOrName, amount uint64) {
	admin.AssertCallerIsOwner()
	fromAddr := users.Resolve(from)
	checkErr(banker.Burn(fromAddr, amount))
}

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

func checkErr(err error) {
	if err != nil {
		panic(err)
	}
}
