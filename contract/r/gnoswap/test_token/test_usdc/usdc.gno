package usdc

import (
	"strings"

	"gno.land/p/demo/tokens/grc20"
	ownable "gno.land/p/nt/ownable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/demo/defi/grc20reg"
)

var (
	token         *grc20.Token
	privateLedger *grc20.PrivateLedger
	userTeller    grc20.Teller

	owner = ownable.NewWithAddress("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5") // ADMIN
)

func init(cur realm) {
	token, privateLedger = grc20.NewToken(0, cur, "Usd Coin", "USDC", 6)
	userTeller = token.CallerTeller()

	privateLedger.Mint(owner.Owner(), 70_000_000_000_000_000)
	grc20reg.Register(cross(cur), token, "")
}

func TotalSupply() int64 {
	return userTeller.TotalSupply()
}

func BalanceOf(owner address) int64 {
	return userTeller.BalanceOf(owner)
}

func Allowance(owner, spender address) int64 {
	return userTeller.Allowance(owner, spender)
}

func Transfer(cur realm, to address, amount int64) {
	checkErr(userTeller.Transfer(0, cur, to, amount))
}

func Approve(cur realm, spender address, amount int64) {
	checkErr(userTeller.Approve(0, cur, spender, amount))
}

func TransferFrom(cur realm, from, to address, amount int64) {
	checkErr(userTeller.TransferFrom(0, cur, from, to, amount))
}

func Mint(cur realm, to address, amount int64) {
	owner.AssertOwnedBy(cur.Address())
	checkErr(privateLedger.Mint(to, amount))
}

func Burn(cur realm, from address, amount int64) {
	owner.AssertOwnedBy(cur.Address())
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
