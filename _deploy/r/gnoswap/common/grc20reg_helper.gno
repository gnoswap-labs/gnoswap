package common

import (
	"gno.land/p/demo/grc/grc20"

	"gno.land/r/demo/grc20reg"
)

// GetToken returns a grc20.Token instance
// if token is not registered, it will panic
// token instance supports following methods:
// - GetName
// - GetSymbol
// - GetDecimals
// - TotalSupply
// - KnownAccounts
// - BalanceOf
// - Allowance
// - RenderHome
func GetToken(path string) *grc20.Token {
	tokenGetter := grc20reg.MustGet(path) // if token is not registered, it will panic

	return tokenGetter()
}

// GetTokenTeller returns a grc20.Teller instance
// if token is not registered, it will panic
// teller instance supports following methods:
// - Transfer
// - Approve
// - TransferFrom
func GetTokenTeller(path string) grc20.Teller {
	tokenGetter := grc20reg.MustGet(path) // if token is not registered, it will panic
	token := tokenGetter()
	return token.CallerTeller()
}
