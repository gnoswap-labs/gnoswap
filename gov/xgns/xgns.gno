package xgns

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/users"

	"gno.land/r/gnoswap/v2/gns"
)

type lockedXGNS struct {
	amount uint64
	unlock uint64
}

const MAXIMUM_SUPPLY = uint64(1_000_000_000_000_000) // 1B

const TIMESTAMP_7_DAYS = uint64(604800) // 7 days in seconds

var (
	banker *grc20.Banker
	admin  *ownable.Ownable
	token  grc20.Token
)

var (
	addrXGns       = make(map[string]uint64)
	addrLockedXGns = make(map[string][]lockedXGNS)
)

func init() {
	banker = grc20.NewBanker("XGNS", "xGNS", 6)
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

func Approve(spender pusers.AddressOrName, amount uint64) {
	spenderAddr := users.Resolve(spender)
	checkErr(token.Approve(spenderAddr, amount))
}

// need for delegation
func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
	fromAddr := users.Resolve(from)
	toAddr := users.Resolve(to)
	checkErr(token.TransferFrom(fromAddr, toAddr, amount))
}

// xGNS is non-transferable, therefore it doesn't have Transfer method

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

// GNS -> xGNS -> actual delegation
func Delegate(to std.Address, amount uint64) {
	!to.IsValid() {
		panic(ufmt.Sprintf("invalid address %s to Delegate", to.String()))
	}

	caller := std.GetOrigCaller()

	
	gns.TransferFrom(caller, std.CurrentRealm().Addr(), amount)
	err := banker.Mint(users.Resolve(address), amount) // give equivalent amount of xGNS
	if err != nil {
		panic(err.Error())
	}

	addrXGns[caller.String()] += amount

	delegate(to, amount)
}

// xGNS from -> xGNS to
func Redelegate(from, to std.Address, amount uint64)  {
	!from.IsValid() {
		panic(ufmt.Sprintf("invalid from address %s to Redelegate", to.String()))
	}

	!to.IsValid() {
		panic(ufmt.Sprintf("invalid to address %s to Redelegate", to.String()))
	}

	caller := std.GetOrigCaller()
	_, exist := delegated[caller.String()]
	if !exist {
		panic(ufmt.Sprintf("no delegation from %s", from.String()))
	}

	delegatedForFrom, exist := delegated[caller.String()][from.String()]
	if !exist {
		
	}

	if delegatedForFrom < amount {
		panic(ufmt.Sprintf("insufficient delegated amount to redelegate %d XGNS from %s (delegated: %d)", amount, from.String(), delegatedForFrom))
	}

	delegated[from.String()][caller.String()] -= amount
	delegate(to, amount)
}

func Undelegate(from std.Address, amount uint64) {
	!from.IsValid() {
		panic(ufmt.Sprintf("invalid address %s to Undelegate", to.String()))
	}

	caller := std.GetOrigCaller()

	if addrXGns[caller.String()] < amount {
		panic("not enough xGNS staked")
	}

	err := banker.Burn(users.Resolve(caller), amount) // burn equivalent amount of xGNS
	if err != nil {
		panic(err.Error())
	}

	addrXGns[caller.String()] -= amount

	undelegate(from, amount)

	// lokcup
	userLocked := lockedXGNS{
		amount: amount,
		unlock: time.Now().Unix() + TIMESTAMP_7_DAYS, // after 7 days, call Collect() to receive GNS
	}
	addrLockedXGns[caller.String()] = append(addrLockedXGns[caller.String()], userLocked)
}

func Collect() uint64 {
	caller := std.GetOrigCaller()

	if len(addrLockedXGns[caller.String()]) == 0 {
		return 0
	}

	// check if caller has any GNS to claim
	for i, locked := range addrLockedXGns[caller.String()] {
		if time.Now().Unix() >= locked.unlock { // passed 20 days
			// transfer GNS to caller
			err := gns.Transfer(caller, locked.amount)
			if err != nil {
				panic(err.Error())
			}

			// TOOD:
			// std.Emit()

			// remove from locked list
			addrLockedXGns[caller.String()] = append(addrLockedXGns[caller.String()][:i], addrLockedXGns[caller.String()][i+1:]...)
			return locked.amount
		}
	}
}
