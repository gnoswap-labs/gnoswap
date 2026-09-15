package common

// IsRegistered checks whether a token key is registered.
//
// Parameters:
//   - tokenKey: registry key identifying the GRC20 token to inspect.
//
// Returns:
//   - error: nil when tokenKey is valid and registered; non-nil when the key is invalid or unregistered.
func IsRegistered(tokenKey string) error {
	return getImplementation().IsRegistered(tokenKey)
}

// MustRegistered checks whether all provided tokens are registered and panics if any is not registered.
//
// Parameters:
//   - tokenKeys: token registry keys to check; an empty list performs no checks.
//
// Panics if any of the provided tokens is not registered.
func MustRegistered(tokenKeys ...string) {
	if err := ValidateRegistered(tokenKeys...); err != nil {
		panic(err.Error())
	}
}

// ValidateRegistered checks whether all provided tokens are registered, returning an
// error instead of panicking when a token is not registered.
//
// Parameters:
//   - tokenKeys: token registry keys to check; an empty list is valid.
//
// Returns:
//   - error: nil when every token is registered; otherwise the first
//     registration failure.
func ValidateRegistered(tokenKeys ...string) error {
	return getImplementation().ValidateRegistered(tokenKeys...)
}

// TotalSupply returns the total supply of the specified token.
//
// Parameters:
//   - tokenKey: registry key identifying the GRC20 token.
//
// Returns:
//   - totalSupply: current token supply for tokenKey, in the token's base units; panics if tokenKey is invalid or unregistered.
func TotalSupply(tokenKey string) int64 {
	return getImplementation().TotalSupply(tokenKey)
}

// BalanceOf returns the token balance for the specified address.
//
// Parameters:
//   - tokenKey: registry key identifying the GRC20 token.
//   - addr: address whose token balance is queried.
//
// Returns:
//   - balance: token balance held by addr, in the token's base units; panics if tokenKey is invalid or unregistered.
func BalanceOf(tokenKey string, addr address) int64 {
	return getImplementation().BalanceOf(tokenKey, addr)
}

// Allowance returns the token allowance from owner to spender.
//
// Parameters:
//   - tokenKey: registry key identifying the GRC20 token.
//   - owner: address that owns the tokens.
//   - spender: address authorized to spend owner's tokens.
//
// Returns:
//   - allowance: amount owner has approved spender to use, in the token's base units; panics if tokenKey is invalid or unregistered.
func Allowance(tokenKey string, owner, spender address) int64 {
	return getImplementation().Allowance(tokenKey, owner, spender)
}

// Transfer forwards a token transfer to the implementation bound to the current realm.
//
// Parameters:
//   - _: leading integer discriminator for the realm-crossing ABI; pass 0.
//   - rlm: propagated realm context used to resolve and invoke the registered token implementation.
//   - tokenKey: registry key identifying the GRC20 token to transfer.
//   - to: recipient address.
//   - amount: number of token base units to transfer.
//
// Panics if tokenKey is invalid or unregistered; the lookup occurs before the
// token teller is invoked.
//
// Returns:
//   - error: nil when the token teller completes the transfer; otherwise an error
//     returned by the teller for transfer-rule validation or execution failure.
func Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) error {
	return getImplementation().Transfer(0, rlm, tokenKey, to, amount)
}

// TransferFrom forwards an allowance-backed token transfer to the implementation bound to the current realm.
//
// Parameters:
//   - _: leading integer discriminator for the realm-crossing ABI; pass 0.
//   - rlm: propagated realm context used to resolve and invoke the registered token implementation.
//   - tokenKey: registry key identifying the GRC20 token to transfer.
//   - from: address whose allowance and balance are debited.
//   - to: recipient address.
//   - amount: number of token base units to transfer.
//
// Panics if tokenKey is invalid or unregistered; the lookup occurs before the
// token teller is invoked.
//
// Returns:
//   - error: nil when the token teller completes the transfer; otherwise an error
//     returned by the teller for transfer, allowance, or balance-rule failure.
func TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) error {
	return getImplementation().TransferFrom(0, rlm, tokenKey, from, to, amount)
}

// Approve forwards an allowance update to the implementation bound to the current realm.
//
// Parameters:
//   - _: leading integer discriminator for the realm-crossing ABI; pass 0.
//   - rlm: propagated realm context used to resolve and invoke the registered token implementation.
//   - tokenKey: registry key identifying the GRC20 token.
//   - spender: address authorized to spend the caller's tokens.
//   - amount: number of token base units to authorize.
//
// Panics if tokenKey is invalid or unregistered; the lookup occurs before the
// token teller is invoked.
//
// Returns:
//   - error: nil when the token teller records the allowance; otherwise an error
//     returned by the teller for approval-rule validation or execution failure.
func Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) error {
	return getImplementation().Approve(0, rlm, tokenKey, spender, amount)
}

// SafeGRC20Transfer transfers tokens as the current realm and panics if it fails.
//
// Parameters:
//   - _: leading integer discriminator for the realm-crossing ABI; pass 0.
//   - rlm: propagated realm context used to resolve and invoke the registered token implementation.
//   - tokenKey: registry key identifying the GRC20 token to transfer.
//   - to: recipient address.
//   - amount: number of token base units to transfer.
//
// Panics if tokenKey is invalid or unregistered, or if the underlying token
// teller returns an error.
func SafeGRC20Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) {
	if err := Transfer(0, rlm, tokenKey, to, amount); err != nil {
		panic(err)
	}
}

// SafeGRC20TransferFrom transfers tokens as the current realm and panics if it fails.
//
// Parameters:
//   - _: leading integer discriminator for the realm-crossing ABI; pass 0.
//   - rlm: propagated realm context used to resolve and invoke the registered token implementation.
//   - tokenKey: registry key identifying the GRC20 token to transfer.
//   - from: address whose allowance and balance are debited.
//   - to: recipient address.
//   - amount: number of token base units to transfer.
//
// Panics if tokenKey is invalid or unregistered, or if the underlying token
// teller returns an error.
func SafeGRC20TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) {
	if err := TransferFrom(0, rlm, tokenKey, from, to, amount); err != nil {
		panic(err)
	}
}

// SafeGRC20Approve approves tokens as the current realm and panics if it fails.
//
// Parameters:
//   - _: leading integer discriminator for the realm-crossing ABI; pass 0.
//   - rlm: propagated realm context used to resolve and invoke the registered token implementation.
//   - tokenKey: registry key identifying the GRC20 token.
//   - spender: address authorized to spend the caller's tokens.
//   - amount: number of token base units to authorize.
//
// Panics if tokenKey is invalid or unregistered, or if the underlying token
// teller returns an error.
func SafeGRC20Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) {
	if err := Approve(0, rlm, tokenKey, spender, amount); err != nil {
		panic(err)
	}
}
