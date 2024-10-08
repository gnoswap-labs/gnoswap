package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v2/consts"
)

type GRC20Interface interface {
	Transfer() func(to pusers.AddressOrName, amount uint64)
	TransferFrom() func(from, to pusers.AddressOrName, amount uint64)
	BalanceOf() func(owner pusers.AddressOrName) uint64
	Approve() func(spender pusers.AddressOrName, amount uint64)
}

var (
	// registered is a map of registered GRC20 interfaces keyed by package path
	registered = make(map[string]GRC20Interface)
	locked     = false // mutex
)

// GetRegisteredTokens returns a slice of all registered tokjen package paths
func GetRegisteredTokens() []string {
	tokens := make([]string, 0, len(registered))
	for k := range registered {
		tokens = append(tokens, k)
	}
	return tokens
}

// RegisterGRC20Interface registers a GRC20 token interface
//
// Panics:
//   - caller is not the admin
//   - token already registered
func RegisterGRC20Interface(pkgPath string, igrc20 GRC20Interface) {
	prevAddr := std.PrevRealm().Addr()
	prevPath := std.PrevRealm().PkgPath()
	if !(prevAddr == consts.TOKEN_REGISTER || prevPath == consts.INIT_REGISTER_PATH) {
		panic("[POOL] token_register.gno__RegisterGRC20Interface()")
	}

	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if found {
		panic(ufmt.Sprintf("[GOV_STAKER] token_register.gno__RegisterGRC20Interface() || pkgPath(%s) already registered", pkgPath))
	}

	registered[pkgPath] = igrc20
}

// UnregisterGRC20Interface unregisters a GRC20 token interface
//
// Panics:
//   - caller is not the admin
func UnregisterGRC20Interface(pkgPath string) {
	assertUserCall()

	caller := std.PrevRealm().Addr()
	if caller != consts.TOKEN_REGISTER {
		panic(ufmt.Sprintf("[GOV_STAKER] token_register.gno__UnregisterGRC20Interface() || unauthorized address(%s) to unregister", caller.String()))
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
		panic(ufmt.Sprintf("[GOV_STAKER] token_register.gno__transferByRegisterCall() || pkgPath(%s) not found", pkgPath))
	}

	if !locked {
		locked = true
		registered[pkgPath].Transfer()(pusers.AddressOrName(to), amount)

		defer func() {
			locked = false
		}()
	} else {
		panic("[GOV_STAKER] token_register.gno__transferByRegisterCall() || expected locked to be false")
	}
	return true
}

func transferFromByRegisterCall(pkgPath string, from, to std.Address, amount uint64) bool {
	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if !found {
		panic(ufmt.Sprintf("[GOV_STAKER] token_register.gno__transferFromByRegisterCall() || pkgPath(%s) not found", pkgPath))
	}

	if !locked {
		locked = true
		registered[pkgPath].TransferFrom()(pusers.AddressOrName(from), pusers.AddressOrName(to), amount)

		defer func() {
			locked = false
		}()
	} else {
		panic("[GOV_STAKER] token_register.gno__transferFromByRegisterCall() || expected locked to be false")
	}
	return true
}

func balanceOfByRegisterCall(pkgPath string, owner std.Address) uint64 {
	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if !found {
		panic(ufmt.Sprintf("[GOV_STAKER] token_register.gno__balanceOfByRegisterCall() || pkgPath(%s) not found", pkgPath))
	}

	balance := registered[pkgPath].BalanceOf()(pusers.AddressOrName(owner))
	return balance
}

func approveByRegisterCall(pkgPath string, spender std.Address, amount uint64) bool {
	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if !found {
		panic(ufmt.Sprintf("[GOV_STAKER] token_register.gno__approveByRegisterCall() || pkgPath(%s) not found", pkgPath))
	}

	registered[pkgPath].Approve()(pusers.AddressOrName(spender), amount)

	return true
}

func handleNative(pkgPath string) string {
	if pkgPath == consts.GNOT {
		return consts.WRAPPED_WUGNOT
	}

	return pkgPath
}
