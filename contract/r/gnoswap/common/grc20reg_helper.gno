package common

import (
	"gno.land/p/demo/tokens/grc20"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/demo/defi/grc20reg"
)

// GetToken returns a grc20.Token instance for the specified path, panicking if not registered.
//
// Parameters:
//   - path: GRC20 token path
//
// Returns a pointer to the grc20.Token instance.
//
// Panics if the token is not registered in grc20reg.
func GetToken(path string) *grc20.Token {
	return grc20reg.MustGet(path)
}

// GetTokenTeller returns a CallerTeller for the specified path, panicking if not registered.
//
// Parameters:
//   - path: GRC20 token path
//
// Returns a grc20.Teller whose write methods derive the actor from the caller
// realm.
//
// Panics if the token is not registered in grc20reg.
func GetTokenTeller(path string) grc20.Teller {
	return GetToken(path).CallerTeller()
}

// IsRegistered checks if a token is registered in grc20reg, returning nil if registered or error if not.
//
// Parameters:
//   - path: GRC20 token path
//
// Returns nil if the token is registered, or an error describing the issue.
func IsRegistered(path string) error {
	getter := grc20reg.Get(path)
	if getter == nil {
		return ufmt.Errorf("token(%s) is not registered to grc20reg", path)
	}
	return nil
}

// MustRegistered checks if all provided tokens are registered, panicking if any is not registered.
//
// Parameters:
//   - paths: variable number of GRC20 token paths to check
//
// Panics if any of the provided tokens is not registered in grc20reg.
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
//
// Parameters:
//   - path: GRC20 token path
//
// Returns the total supply of the token as int64.
func TotalSupply(path string) int64 {
	return GetToken(path).TotalSupply()
}

// BalanceOf returns the token balance for the specified address.
//
// Parameters:
//   - path: GRC20 token path
//   - addr: address to query the balance for
//
// Returns the token balance as int64.
func BalanceOf(path string, addr address) int64 {
	return GetToken(path).BalanceOf(addr)
}

// Allowance returns the token allowance from owner to spender.
//
// Parameters:
//   - path: GRC20 token path
//   - owner: address of the token owner
//   - spender: address of the spender
//
// Returns the allowance amount as int64.
func Allowance(path string, owner, spender address) int64 {
	return GetToken(path).Allowance(owner, spender)
}

// Transfer crosses into common before forwarding to grc20.Teller.Transfer.
// CallerTeller uses cur.Previous() as the token actor, so this helper must
// remain a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - path: GRC20 token path
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Returns an error if the transfer fails, nil otherwise.
func Transfer(cur realm, path string, to address, amount int64) error {
	return GetTokenTeller(path).Transfer(0, cur, to, amount)
}

// TransferFrom crosses into common before forwarding to grc20.Teller.TransferFrom.
// CallerTeller uses cur.Previous() as the spender, so this helper must remain
// a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - path: GRC20 token path
//   - from: sender address
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Returns an error if the transfer fails, nil otherwise.
func TransferFrom(cur realm, path string, from, to address, amount int64) error {
	return GetTokenTeller(path).TransferFrom(0, cur, from, to, amount)
}

// Approve crosses into common before forwarding to grc20.Teller.Approve.
// CallerTeller uses cur.Previous() as the approver, so this helper must
// remain a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - path: GRC20 token path
//   - spender: address allowed to spend the tokens
//   - amount: amount of tokens to approve
//
// Returns an error if the approval fails, nil otherwise.
func Approve(cur realm, path string, spender address, amount int64) error {
	return GetTokenTeller(path).Approve(0, cur, spender, amount)
}

// SafeGRC20Transfer crosses into common, transfers tokens, and panics if it fails.
// CallerTeller uses cur.Previous() as the token actor, so this helper must
// remain a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - path: GRC20 token path
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Panics if the transfer fails.
func SafeGRC20Transfer(cur realm, path string, to address, amount int64) {
	if err := GetTokenTeller(path).Transfer(0, cur, to, amount); err != nil {
		panic(err)
	}
}

// SafeGRC20TransferFrom crosses into common, transfers tokens, and panics if it fails.
// CallerTeller uses cur.Previous() as the spender, so this helper must remain
// a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - path: GRC20 token path
//   - from: sender address
//   - to: recipient address
//   - amount: amount of tokens to transfer
//
// Panics if the transfer fails.
func SafeGRC20TransferFrom(cur realm, path string, from, to address, amount int64) {
	if err := GetTokenTeller(path).TransferFrom(0, cur, from, to, amount); err != nil {
		panic(err)
	}
}

// SafeGRC20Approve crosses into common, approves tokens, and panics if it fails.
// CallerTeller uses cur.Previous() as the approver, so this helper must remain
// a crossing adapter called with cross(cur).
//
// Parameters:
//   - cur: current realm
//   - path: GRC20 token path
//   - spender: address allowed to spend the tokens
//   - amount: amount of tokens to approve
//
// Panics if the approval fails.
func SafeGRC20Approve(cur realm, path string, spender address, amount int64) {
	if err := GetTokenTeller(path).Approve(0, cur, spender, amount); err != nil {
		panic(err)
	}
}
