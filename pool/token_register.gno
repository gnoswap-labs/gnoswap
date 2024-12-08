package pool

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

// GRC20Interface is the interface for GRC20 tokens
// It is used to interact with the GRC20 tokens without importing but by registering each tokens function
type GRC20Interface interface {
	Transfer() func(to pusers.AddressOrName, amount uint64)
	TransferFrom() func(from, to pusers.AddressOrName, amount uint64)
	BalanceOf() func(owner pusers.AddressOrName) uint64
	Approve() func(spender pusers.AddressOrName, amount uint64)
}

var (
	registered = make(map[string]GRC20Interface)
)

// GetRegisteredTokens returns a list of all registered tokens
func GetRegisteredTokens() []string {
	tokens := make([]string, 0, len(registered))
	for k := range registered {
		tokens = append(tokens, k)
	}
	return tokens
}

// RegisterGRC20Interface registers a GRC20 token interface
func RegisterGRC20Interface(pkgPath string, igrc20 GRC20Interface) {
	prevAddr := std.PrevRealm().Addr()
	prevPath := std.PrevRealm().PkgPath()
	if !(prevAddr == consts.TOKEN_REGISTER || prevPath == consts.INIT_REGISTER_PATH || strings.HasPrefix(prevPath, "gno.land/r/g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5")) {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("token_register.gno__RegisterGRC20Interface() || only register(%s) can register token, called from %s", consts.TOKEN_REGISTER, prevAddr),
		))
	}

	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if found {
		panic(addDetailToError(
			errAlreadyRegistered,
			ufmt.Sprintf("token_register.gno__RegisterGRC20Interface() || token(%s) already registered", pkgPath),
		))
	}

	registered[pkgPath] = igrc20
}

// UnregisterGRC20Interface unregisters a GRC20 token interface
func UnregisterGRC20Interface(pkgPath string) {
	if err := common.SatisfyCond(isUserCall()); err != nil {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("token_register.gno__UnregisterGRC20Interface() || unauthorized address(%s) to unregister", std.PrevRealm().Addr()),
		))
	}

	caller := std.PrevRealm().Addr()
	if err := common.TokenRegisterOnly(caller); err != nil {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("token_register.gno__UnregisterGRC20Interface() || unauthorized address(%s) to unregister", caller),
		))
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
		panic(addDetailToError(
			errNotRegistered,
			ufmt.Sprintf("token_register.gno__transferByRegisterCall() || token(%s) not registered", pkgPath),
		))
	}
	registered[pkgPath].Transfer()(pusers.AddressOrName(to), amount)

	return true
}

func transferFromByRegisterCall(pkgPath string, from, to std.Address, amount uint64) bool {
	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if !found {
		panic(addDetailToError(
			errNotRegistered,
			ufmt.Sprintf("token_register.gno__transferFromByRegisterCall() || token(%s) not registered", pkgPath),
		))
	}

	registered[pkgPath].TransferFrom()(pusers.AddressOrName(from), pusers.AddressOrName(to), amount)

	return true
}

func balanceOfByRegisterCall(pkgPath string, owner std.Address) uint64 {
	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if !found {
		panic(addDetailToError(
			errNotRegistered,
			ufmt.Sprintf("token_register.gno__balanceOfByRegisterCall() || token(%s) not registered", pkgPath),
		))
	}

	balance := registered[pkgPath].BalanceOf()(pusers.AddressOrName(owner))
	return balance
}

func approveByRegisterCall(pkgPath string, spender std.Address, amount uint64) bool {
	pkgPath = handleNative(pkgPath)

	_, found := registered[pkgPath]
	if !found {
		panic(addDetailToError(
			errNotRegistered,
			ufmt.Sprintf("token_register.gno__approveByRegisterCall() || token(%s) not registered", pkgPath),
		))
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
