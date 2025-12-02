package common

import (
	"gno.land/p/demo/tokens/grc20"
	"gno.land/p/nt/ufmt"
	"gno.land/r/demo/defi/grc20reg"
)

// GetToken returns a grc20.Token instance for the specified path, panicking if not registered.
func GetToken(path string) *grc20.Token {
	return grc20reg.MustGet(path)
}

// GetTokenTeller returns a grc20.Teller instance for the specified path, panicking if not registered.
func GetTokenTeller(path string) grc20.Teller {
	return GetToken(path).CallerTeller()
}

// IsRegistered checks if a token is registered in grc20reg, returning nil if registered or error if not.
func IsRegistered(path string) error {
	getter := grc20reg.Get(path)
	if getter == nil {
		return ufmt.Errorf("token(%s) is not registered to grc20reg", path)
	}
	return nil
}

// MustRegistered checks if all provided tokens are registered, panicking if any is not registered.
func MustRegistered(paths ...string) {
	for _, path := range paths {
		if err := IsRegistered(path); err != nil {
			panic(newErrorWithDetail(
				errNotRegistered,
				ufmt.Sprintf("token(%s)", path),
			))
		}
	}
}

// TotalSupply returns the total supply of the specified token.
func TotalSupply(path string) int64 {
	return GetToken(path).TotalSupply()
}

// BalanceOf returns the token balance for the specified address.
func BalanceOf(path string, addr address) int64 {
	return GetToken(path).BalanceOf(addr)
}

// Allowance returns the token allowance from owner to spender.
func Allowance(path string, owner, spender address) int64 {
	return GetToken(path).Allowance(owner, spender)
}

// Transfer transfers tokens to the specified address using grc20.Teller.Transfer.
func Transfer(cur realm, path string, to address, amount int64) error {
	return GetTokenTeller(path).Transfer(to, amount)
}

// TransferFrom transfers tokens from one address to another using grc20.Teller.TransferFrom.
func TransferFrom(cur realm, path string, from, to address, amount int64) error {
	return GetTokenTeller(path).TransferFrom(from, to, amount)
}

// Approve approves tokens for the specified spender using grc20.Teller.Approve.
func Approve(cur realm, path string, spender address, amount int64) error {
	return GetTokenTeller(path).Approve(spender, amount)
}

// SafeGRC20Transfer performs a token transfer and panics if it fails.
func SafeGRC20Transfer(cur realm, path string, to address, amount int64) {
	if err := GetTokenTeller(path).Transfer(to, amount); err != nil {
		panic(err)
	}
}

// SafeGRC20TransferFrom performs a token transfer from one address to another and panics if it fails.
func SafeGRC20TransferFrom(cur realm, path string, from, to address, amount int64) {
	if err := GetTokenTeller(path).TransferFrom(from, to, amount); err != nil {
		panic(err)
	}
}

// SafeGRC20Approve performs a token approval and panics if it fails.
func SafeGRC20Approve(cur realm, path string, spender address, amount int64) {
	if err := GetTokenTeller(path).Approve(spender, amount); err != nil {
		panic(err)
	}
}
