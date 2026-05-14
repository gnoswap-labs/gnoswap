package trx

import (
	"strings"

	"gno.land/p/demo/tokens/grc20"
	ownable "gno.land/p/nt/ownable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/demo/defi/grc20reg"
)

var (
	token, privateLedger = grc20.NewToken("Tron", "TRX", 6)
	owner                = ownable.NewWithAddressByPrevious("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5") // ADMIN
)

func init() {
	privateLedger.Mint(owner.Owner(), 100_000_000_000_000_000)
	grc20reg.Register(cross, token, "")
}

func TotalSupply() int64 {
	userTeller := token.CallerTeller()
	return userTeller.TotalSupply()
}

func BalanceOf(owner address) int64 {
	userTeller := token.CallerTeller()
	return userTeller.BalanceOf(owner)
}

func Allowance(owner, spender address) int64 {
	userTeller := token.CallerTeller()
	return userTeller.Allowance(owner, spender)
}

func Transfer(cur realm, to address, amount int64) {
	userTeller := token.CallerTeller()
	checkErr(userTeller.Transfer(to, amount))
}

func Approve(cur realm, spender address, amount int64) {
	userTeller := token.CallerTeller()
	checkErr(userTeller.Approve(spender, amount))
}

func TransferFrom(cur realm, from, to address, amount int64) {
	userTeller := token.CallerTeller()
	checkErr(userTeller.TransferFrom(from, to, amount))
}

func Mint(cur realm, to address, amount int64) {
	owner.AssertOwned()
	checkErr(privateLedger.Mint(to, amount))
}

func Burn(cur realm, from address, amount int64) {
	owner.AssertOwned()
	checkErr(privateLedger.Burn(from, amount))
}

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return token.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := address(parts[1])
		userTeller := token.CallerTeller()
		balance := userTeller.BalanceOf(owner)
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
