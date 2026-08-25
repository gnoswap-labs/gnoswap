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

// GetTokenTeller returns a CallerTeller for the specified tokenKey, panicking if not registered.
//
// Parameters:
//   - tokenKey: GRC20 registry key
//
// Returns a grc20.Teller whose write methods derive the actor from the caller
// realm.
//
// Panics if the token is not registered in grc20reg.
func GetTokenTeller(tokenKey string) grc20.Teller {
	return GetToken(tokenKey).CallerTeller()
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

// Transfer crosses into common before forwarding to grc20.Teller.Transfer.
// CallerTeller uses cur.Previous() as the token actor, so this helper must
// remain a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - tokenKey: GRC20 registry key
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Returns an error if the transfer fails, nil otherwise.
func Transfer(cur realm, tokenKey string, to address, amount int64) error {
	return GetTokenTeller(tokenKey).Transfer(0, cur, to, amount)
}

// TransferFrom crosses into common before forwarding to grc20.Teller.TransferFrom.
// CallerTeller uses cur.Previous() as the spender, so this helper must remain
// a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - tokenKey: GRC20 registry key
//   - from: sender address
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Returns an error if the transfer fails, nil otherwise.
func TransferFrom(cur realm, tokenKey string, from, to address, amount int64) error {
	return GetTokenTeller(tokenKey).TransferFrom(0, cur, from, to, amount)
}

// Approve crosses into common before forwarding to grc20.Teller.Approve.
// CallerTeller uses cur.Previous() as the approver, so this helper must
// remain a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - tokenKey: GRC20 registry key
//   - spender: address allowed to spend the tokens
//   - amount: amount of tokens to approve
//
// Returns an error if the approval fails, nil otherwise.
func Approve(cur realm, tokenKey string, spender address, amount int64) error {
	return GetTokenTeller(tokenKey).Approve(0, cur, spender, amount)
}

// SafeGRC20Transfer crosses into common, transfers tokens, and panics if it fails.
// CallerTeller uses cur.Previous() as the token actor, so this helper must
// remain a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - tokenKey: GRC20 registry key
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Panics if the transfer fails.
func SafeGRC20Transfer(cur realm, tokenKey string, to address, amount int64) {
	if err := GetTokenTeller(tokenKey).Transfer(0, cur, to, amount); err != nil {
		panic(err)
	}
}

// SafeGRC20TransferFrom crosses into common, transfers tokens, and panics if it fails.
// CallerTeller uses cur.Previous() as the spender, so this helper must remain
// a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - tokenKey: GRC20 registry key
//   - from: sender address
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Panics if the transfer fails.
func SafeGRC20TransferFrom(cur realm, tokenKey string, from, to address, amount int64) {
	if err := GetTokenTeller(tokenKey).TransferFrom(0, cur, from, to, amount); err != nil {
		panic(err)
	}
}

// SafeGRC20Approve crosses into common, approves tokens, and panics if it fails.
// CallerTeller uses cur.Previous() as the approver, so this helper must remain
// a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - tokenKey: GRC20 registry key
//   - spender: address allowed to spend the tokens
//   - amount: amount of tokens to approve
//
// Panics if the approval fails.
func SafeGRC20Approve(cur realm, tokenKey string, spender address, amount int64) {
	if err := GetTokenTeller(tokenKey).Approve(0, cur, spender, amount); err != nil {
		panic(err)
	}
}
