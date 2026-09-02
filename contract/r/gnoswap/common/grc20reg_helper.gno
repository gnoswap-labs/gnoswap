package common

import (
	"errors"

	"gno.land/p/demo/tokens/grc20"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/demo/defi/grc20reg"
)

// GetToken returns a grc20.Token instance for the specified tokenKey, panicking if not registered.
//
// Parameters:
//   - tokenKey: GRC20 registry key
//
// Returns a pointer to the grc20.Token instance.
//
// Panics if the token is not registered in grc20reg.
func GetToken(tokenKey string) *grc20.Token {
	return grc20reg.MustGet(tokenKey)
}

// GetTokenTeller returns a teller bound to the current realm for the specified
// tokenKey, panicking if not registered.
//
// Parameters:
//   - rlm: current realm
//   - tokenKey: GRC20 registry key
//
// Returns a grc20.Teller whose actor is the current realm.
//
// Panics if the token is not registered in grc20reg.
func GetTokenTeller(_ int, rlm realm, tokenKey string) grc20.Teller {
	return GetToken(tokenKey).RealmTeller(0, rlm)
}

// IsRegistered checks if a token is registered in grc20reg, returning nil if registered or error if not.
//
// Parameters:
//   - tokenKey: GRC20 registry key
//
// Returns nil if the token is registered, or an error describing the issue.
func IsRegistered(tokenKey string) error {
	if grc20reg.Get(tokenKey) == nil {
		return ufmt.Errorf("token(%s) is not registered to grc20reg", tokenKey)
	}
	return nil
}

// MustRegistered checks if all provided tokens are registered, panicking if any is not registered.
//
// Parameters:
//   - tokenKeys: variable number of GRC20 registry keys to check
//
// Panics if any of the provided tokens is not registered in grc20reg.
func MustRegistered(tokenKeys ...string) {
	if err := ValidateRegistered(tokenKeys...); err != nil {
		panic(err.Error())
	}
}

// ValidateRegistered checks if all provided tokens are registered, returning an
// error instead of panicking when a token is not registered.
//
// Parameters:
//   - tokenKeys: variable number of GRC20 registry keys to check
//
// Returns nil when every token is registered, otherwise the first
// registration failure as an error carrying the same detail format used by
// MustRegistered.
func ValidateRegistered(tokenKeys ...string) error {
	for _, tokenKey := range tokenKeys {
		if err := IsRegistered(tokenKey); err != nil {
			return errors.New(newErrorWithDetail(
				errNotRegistered,
				ufmt.Sprintf("token(%s)", tokenKey),
			))
		}
	}
	return nil
}

// TotalSupply returns the total supply of the specified token.
//
// Parameters:
//   - tokenKey: GRC20 registry key
//
// Returns the total supply of the token as int64.
func TotalSupply(tokenKey string) int64 {
	return GetToken(tokenKey).TotalSupply()
}

// BalanceOf returns the token balance for the specified address.
//
// Parameters:
//   - tokenKey: GRC20 registry key
//   - addr: address to query the balance for
//
// Returns the token balance as int64.
func BalanceOf(tokenKey string, addr address) int64 {
	return GetToken(tokenKey).BalanceOf(addr)
}

// Allowance returns the token allowance from owner to spender.
//
// Parameters:
//   - tokenKey: GRC20 registry key
//   - owner: address of the token owner
//   - spender: address of the spender
//
// Returns the allowance amount as int64.
func Allowance(tokenKey string, owner, spender address) int64 {
	return GetToken(tokenKey).Allowance(owner, spender)
}

// Transfer forwards to a teller bound to the current realm.
//
// Parameters:
//   - rlm: current realm
//   - tokenKey: GRC20 registry key
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Returns an error if the transfer fails, nil otherwise.
func Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) error {
	return GetTokenTeller(0, rlm, tokenKey).Transfer(0, rlm, to, amount)
}

// TransferFrom forwards to a teller bound to the current realm.
//
// Parameters:
//   - rlm: current realm
//   - tokenKey: GRC20 registry key
//   - from: sender address
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Returns an error if the transfer fails, nil otherwise.
func TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) error {
	return GetTokenTeller(0, rlm, tokenKey).TransferFrom(0, rlm, from, to, amount)
}

// Approve forwards to a teller bound to the current realm.
//
// Parameters:
//   - rlm: current realm
//   - tokenKey: GRC20 registry key
//   - spender: address allowed to spend the tokens
//   - amount: amount of tokens to approve
//
// Returns an error if the approval fails, nil otherwise.
func Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) error {
	return GetTokenTeller(0, rlm, tokenKey).Approve(0, rlm, spender, amount)
}

// SafeGRC20Transfer transfers tokens as the current realm and panics if it fails.
//
// Parameters:
//   - rlm: current realm
//   - tokenKey: GRC20 registry key
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Panics if the transfer fails.
func SafeGRC20Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) {
	if err := GetTokenTeller(0, rlm, tokenKey).Transfer(0, rlm, to, amount); err != nil {
		panic(err)
	}
}

// SafeGRC20TransferFrom transfers tokens as the current realm and panics if it fails.
//
// Parameters:
//   - rlm: current realm
//   - tokenKey: GRC20 registry key
//   - from: sender address
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Panics if the transfer fails.
func SafeGRC20TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) {
	if err := GetTokenTeller(0, rlm, tokenKey).TransferFrom(0, rlm, from, to, amount); err != nil {
		panic(err)
	}
}

// SafeGRC20Approve approves tokens as the current realm and panics if it fails.
//
// Parameters:
//   - rlm: current realm
//   - tokenKey: GRC20 registry key
//   - spender: address allowed to spend the tokens
//   - amount: amount of tokens to approve
//
// Panics if the approval fails.
func SafeGRC20Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) {
	if err := GetTokenTeller(0, rlm, tokenKey).Approve(0, rlm, spender, amount); err != nil {
		panic(err)
	}
}
