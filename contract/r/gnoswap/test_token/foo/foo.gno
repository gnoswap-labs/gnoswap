package foo

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/grc20reg"
)

var (
	token, privateLedger = grc20.NewToken("Foo", "FOO", 6)
	owner                = ownable.NewWithAddress("g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d") // ADMIN
)

func init() {
	privateLedger.Mint(owner.Owner(), 100_000_000_000_000)
	cross(grc20reg.Register)(token, "")
}

func TotalSupply() int64 {
	crossing()
	userTeller := token.CallerTeller()
	return userTeller.TotalSupply()
}

func BalanceOf(owner std.Address) int64 {
	crossing()
	userTeller := token.CallerTeller()
	return userTeller.BalanceOf(owner)
}

func Allowance(owner, spender std.Address) int64 {
	crossing()
	userTeller := token.CallerTeller()
	return userTeller.Allowance(owner, spender)
}

func Transfer(to std.Address, amount int64) {
	crossing()
	userTeller := token.CallerTeller()
	checkErr(userTeller.Transfer(to, amount))
}

func Approve(spender std.Address, amount int64) {
	crossing()
	userTeller := token.CallerTeller()
	checkErr(userTeller.Approve(spender, amount))
}

func TransferFrom(from, to std.Address, amount int64) {
	crossing()
	userTeller := token.CallerTeller()
	checkErr(userTeller.TransferFrom(from, to, amount))
}

func Burn(from std.Address, amount int64) {
	crossing()
	owner.AssertOwnedByPrevious()
	checkErr(privateLedger.Burn(from, amount))
}

func Render(path string) string {
	crossing()
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return token.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := std.Address(parts[1])
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
