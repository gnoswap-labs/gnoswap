package pool

import (
	"std"
	"strings"

	"gno.land/p/demo/avl"
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
	registered = avl.NewTree()
	locked     = false // mutex
)

// GetRegisteredTokens returns a list of all registered tokens
func GetRegisteredTokens() []string {
	tokens := make([]string, 0, registered.Size())

	registered.Iterate("", "", func(key string, value interface{}) bool {
		tokens = append(tokens, key)
		return false
	})

	return tokens
}

// RegisterGRC20Interface registers a GRC20 token interface
func RegisterGRC20Interface(pkgPath string, igrc20 GRC20Interface) {
	prevAddr := std.PrevRealm().Addr()
	prevPath := std.PrevRealm().PkgPath()
	if !(prevAddr == consts.TOKEN_REGISTER || prevPath == consts.INIT_REGISTER_PATH || strings.HasPrefix(prevPath, consts.TOKEN_REGISTER_NAMESPACE)) {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only register(%s) can register token, called from %s", consts.TOKEN_REGISTER, prevAddr),
		))
	}

	pkgPath = handleNative(pkgPath)

	if registered.Has(pkgPath) {
		panic(addDetailToError(
			errAlreadyRegistered,
			ufmt.Sprintf("token(%s) already registered", pkgPath),
		))
	}

	registered.Set(pkgPath, igrc20)
}

// UnregisterGRC20Interface unregisters a GRC20 token interface
func UnregisterGRC20Interface(pkgPath string) {
	if err := common.SatisfyCond(isUserCall()); err != nil {
		panic(addDetailToError(
			err,
			ufmt.Sprintf("is not user call"),
		))
	}

	caller := std.PrevRealm().Addr()
	if err := common.TokenRegisterOnly(caller); err != nil {
		panic(addDetailToError(
			err,
			ufmt.Sprintf("unauthorized address to unregister"),
		))
	}

	pkgPath = handleNative(pkgPath)

	if registered.Has(pkgPath) {
		registered.Remove(pkgPath)
	}
}

func transferByRegisterCall(pkgPath string, to std.Address, amount uint64) bool {
	pkgPath = handleNative(pkgPath)

	mustRegistered(pkgPath)
	mustUnlocked()

	locked = true
	getToken(pkgPath).Transfer()(pusers.AddressOrName(to), amount)
	defer func() {
		locked = false
	}()

	return true
}

func transferFromByRegisterCall(pkgPath string, from, to std.Address, amount uint64) bool {
	pkgPath = handleNative(pkgPath)

	mustRegistered(pkgPath)
	mustUnlocked()

	locked = true
	getToken(pkgPath).TransferFrom()(pusers.AddressOrName(from), pusers.AddressOrName(to), amount)
	defer func() {
		locked = false
	}()

	return true
}

func balanceOfByRegisterCall(pkgPath string, owner std.Address) uint64 {
	pkgPath = handleNative(pkgPath)

	mustRegistered(pkgPath)

	balance := getToken(pkgPath).BalanceOf()(pusers.AddressOrName(owner))
	return balance
}

func approveByRegisterCall(pkgPath string, spender std.Address, amount uint64) bool {
	pkgPath = handleNative(pkgPath)

	mustRegistered(pkgPath)

	getToken(pkgPath).Approve()(pusers.AddressOrName(spender), amount)

	return true
}

func handleNative(pkgPath string) string {
	if pkgPath == consts.GNOT {
		return consts.WRAPPED_WUGNOT
	}

	return pkgPath
}

func getToken(pkgPath string) GRC20Interface {
	pkgPath = handleNative(pkgPath)

	itoken, _ := registered.Get(pkgPath)
	return itoken.(GRC20Interface)
}

func mustRegistered(pkgPath string) {
	pkgPath = handleNative(pkgPath)

	if !registered.Has(pkgPath) {
		panic(addDetailToError(
			errNotRegistered,
			ufmt.Sprintf("token(%s) not registered", pkgPath),
		))
	}
}

func mustUnlocked() {
	if locked {
		panic(addDetailToError(
			errLocked,
			ufmt.Sprintf("expected locked(%t) to be false", locked),
		))
	}
}
