package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	"gno.land/r/gnoswap/consts"
)

type GRC20Interface interface {
	Transfer() func(to users.AddressOrName, amount uint64)
	TransferFrom() func(from, to users.AddressOrName, amount uint64)
	BalanceOf() func(owner users.AddressOrName) uint64
	Approve() func(spender users.AddressOrName, amount uint64)
}

var (
	registered = make(map[string]GRC20Interface)
	locked     = false // mutex
)

func GetRegisteredTokens() []string {
	tokens := make([]string, 0, len(registered))
	for k := range registered {
		tokens = append(tokens, k)
	}
	return tokens
}

func RegisterGRC20Interface(pkgPath string, igrc20 GRC20Interface) {
	caller := std.GetOrigCaller()
	if caller != consts.GNOSWAP_ADMIN {
		panic(ufmt.Sprintf("[STAKER] staker_register.gno__RegisterGRC20Interface() || unauthorized address(%s) to register", caller.String()))
	}

	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if found {
		panic(ufmt.Sprintf("[STAKER] staker_register.gno__RegisterGRC20Interface() || pkgPath(%s) already registered", pkgPath))
	}

	registered[pkgPath] = igrc20
}

func UnregisterGRC20Interface(pkgPath string) {
	// only admin can unregister
	caller := std.GetOrigCaller()
	if caller != consts.GNOSWAP_ADMIN {
		panic(ufmt.Sprintf("[STAKER] staker_register.gno__UnregisterGRC20Interface() || unauthorized address(%s) to unregister", caller.String()))
	}

	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if found {
		delete(registered, pkgPath)
	}
}

func transferByRegisterCall(pkgPath string, to std.Address, amount uint64) bool {
	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if !found {
		panic(ufmt.Sprintf("[STAKER] staker_register.gno__transferByRegisterCall() || pkgPath(%s) not found", pkgPath))
	}

	if !locked {
		locked = true
		registered[pkgPath].Transfer()(users.AddressOrName(to), amount)

		defer func() {
			locked = false
		}()
	} else {
		panic("[POOl] staker_register.gno__transferByRegisterCall() || expected locked to be false")
	}
	return true
}

func transferFromByRegisterCall(pkgPath string, from, to std.Address, amount uint64) bool {
	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if !found {
		panic(ufmt.Sprintf("[STAKER] staker_register.gno__transferFromByRegisterCall() || pkgPath(%s) not found", pkgPath))
	}

	if !locked {
		locked = true
		registered[pkgPath].TransferFrom()(users.AddressOrName(from), users.AddressOrName(to), amount)

		defer func() {
			locked = false
		}()
	} else {
		panic("[POOl] staker_register.gno__transferFromByRegisterCall() || expected locked to be false")
	}
	return true
}

func balanceOfByRegisterCall(pkgPath string, owner std.Address) uint64 {
	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if !found {
		panic(ufmt.Sprintf("[STAKER] staker_register.gno__balanceOfByRegisterCall() || pkgPath(%s) not found", pkgPath))
	}

	balance := registered[pkgPath].BalanceOf()(users.AddressOrName(owner))
	return balance
}

func approveByRegisterCall(pkgPath string, spender std.Address, amount uint64) bool {
	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if !found {
		panic(ufmt.Sprintf("[STAKER] staker_register.gno__approveByRegisterCall() || pkgPath(%s) not found", pkgPath))
	}

	registered[pkgPath].Approve()(users.AddressOrName(spender), amount)

	return true
}

func handleNative(pkgPath string) string {
	if pkgPath == consts.GNOT {
		return consts.WRAPPED_WUGNOT
	}

	return pkgPath
}
