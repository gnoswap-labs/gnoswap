package bar

import (
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/grc20reg"
	"gno.land/r/demo/users"
)

var (
	Token, privateLedger = grc20.NewToken("Bar", "BAR", 6)
	UserTeller           = Token.CallerTeller()
	owner                = ownable.NewWithAddress("g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d") // ADMIN
)

func init() {
	privateLedger.Mint(owner.Owner(), 100_000_000_000_000)
	getter := func() *grc20.Token { return Token }
	grc20reg.Register(getter, "")
}

func TotalSupply() uint64 {
	return UserTeller.TotalSupply()
}

func BalanceOf(owner pusers.AddressOrName) uint64 {
	ownerAddr := users.Resolve(owner)
	return UserTeller.BalanceOf(ownerAddr)
}

func Allowance(owner, spender pusers.AddressOrName) uint64 {
	ownerAddr := users.Resolve(owner)
	spenderAddr := users.Resolve(spender)
	return UserTeller.Allowance(ownerAddr, spenderAddr)
}

func Transfer(to pusers.AddressOrName, amount uint64) {
	toAddr := users.Resolve(to)
	checkErr(UserTeller.Transfer(toAddr, amount))
}

func Approve(spender pusers.AddressOrName, amount uint64) {
	spenderAddr := users.Resolve(spender)
	checkErr(UserTeller.Approve(spenderAddr, amount))
}

func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
	fromAddr := users.Resolve(from)
	toAddr := users.Resolve(to)
	checkErr(UserTeller.TransferFrom(fromAddr, toAddr, amount))
}

func Burn(from pusers.AddressOrName, amount uint64) {
	owner.AssertCallerIsOwner()
	fromAddr := users.Resolve(from)
	checkErr(privateLedger.Burn(fromAddr, amount))
}

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return Token.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := pusers.AddressOrName(parts[1])
		ownerAddr := users.Resolve(owner)
		balance := UserTeller.BalanceOf(ownerAddr)
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
