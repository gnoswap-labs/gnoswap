package router

import (
	"std"

	"gno.land/r/demo/users"
)

const APPROVED_CALLER = "g12l9splsyngcgefrwa52x5a7scc29e9v086m6p4" // gsa

var registered = []GRC20Pair{}

type GRC20Interface interface {
	Transfer() func(to users.AddressOrName, amount uint64)
	TransferFrom() func(from, to users.AddressOrName, amount uint64)
	BalanceOf() func(owner users.AddressOrName) uint64
	Approve() func(spender users.AddressOrName, amount uint64)
}

type GRC20Pair struct {
	pkgPath string
	igrc20  GRC20Interface
}

func findGRC20(pkgPath string) (int, bool) {
	for i, pair := range registered {
		if pair.pkgPath == pkgPath {
			return i, true
		}
	}

	return -1, false
}

func appendGRC20Interface(pkgPath string, igrc20 GRC20Interface) {
	registered = append(registered, GRC20Pair{pkgPath: pkgPath, igrc20: igrc20})
}

func removeGRC20Interface(pkgPath string) {
	i, found := findGRC20(pkgPath)
	if !found {
		return
	}

	registered = append(registered[:i], registered[i+1:]...)
}

func RegisterGRC20Interface(pkgPath string, igrc20 GRC20Interface) {
	// only admin can register
	// r3v4_xxx: below logic can't be used in test case
	// r3v4_xxx: however must be used in production

	// caller := std.GetOrigCaller()
	// if caller != APPROVED_CALLER {
	// 	panic("unauthorized address to register")
	// }

	_, found := findGRC20(pkgPath)
	if !found {
		appendGRC20Interface(pkgPath, igrc20)
	}
}

func UnregisterGRC20Interface(pkgPath string) {
	// do not allow realm to unregister
	std.AssertOriginCall()

	// only admin can unregister
	caller := std.GetOrigCaller()
	require(caller == APPROVED_CALLER, "[ROUTER] router_register.gno__UnregisterGRC20Interface() || nauthorized address to unregister")

	_, found := findGRC20(pkgPath)
	if found {
		removeGRC20Interface(pkgPath)
	}
}

func transferByRegisterCall(pkgPath string, to std.Address, amount uint64) bool {
	i, found := findGRC20(pkgPath)
	if !found {
		return false
	}

	registered[i].igrc20.Transfer()(users.AddressOrName(to), amount)

	return true
}

func transferFromByRegisterCall(pkgPath string, from, to std.Address, amount uint64) bool {
	i, found := findGRC20(pkgPath)
	if !found {
		return false
	}

	registered[i].igrc20.TransferFrom()(users.AddressOrName(from), users.AddressOrName(to), amount)

	return true
}

func balanceOfByRegisterCall(pkgPath string, owner std.Address) uint64 {
	i, found := findGRC20(pkgPath)
	if !found {
		return 0
	}

	balance := registered[i].igrc20.BalanceOf()(users.AddressOrName(owner))
	return balance
}

func approveByRegisterCall(pkgPath string, spender std.Address, amount uint64) bool {
	i, found := findGRC20(pkgPath)
	if !found {
		return false
	}

	registered[i].igrc20.Approve()(users.AddressOrName(spender), amount)

	return true
}
