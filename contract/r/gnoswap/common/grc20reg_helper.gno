package common

// IsRegistered checks if a token is registered, returning nil if registered or error if not.
//
// Parameters:
//   - tokenKey: token registry key
//
// Returns nil if the token is registered, or an error describing the issue.
func IsRegistered(tokenKey string) error {
	return getImplementation().IsRegistered(tokenKey)
}

// MustRegistered checks if all provided tokens are registered, panicking if any is not registered.
//
// Parameters:
//   - tokenKeys: variable number of token registry keys to check
//
// Panics if any of the provided tokens is not registered.
func MustRegistered(tokenKeys ...string) {
	if err := ValidateRegistered(tokenKeys...); err != nil {
		panic(err.Error())
	}
}

// ValidateRegistered checks if all provided tokens are registered, returning an
// error instead of panicking when a token is not registered.
//
// Parameters:
//   - tokenKeys: variable number of token registry keys to check
//
// Returns nil when every token is registered, otherwise the first
// registration failure as an error.
func ValidateRegistered(tokenKeys ...string) error {
	return getImplementation().ValidateRegistered(tokenKeys...)
}

// TotalSupply returns the total supply of the specified token.
//
// Parameters:
//   - tokenKey: GRC20 registry key
//
// Returns the total supply of the token as int64.
func TotalSupply(tokenKey string) int64 {
	return getImplementation().TotalSupply(tokenKey)
}

// BalanceOf returns the token balance for the specified address.
//
// Parameters:
//   - tokenKey: GRC20 registry key
//   - addr: address to query the balance for
//
// Returns the token balance as int64.
func BalanceOf(tokenKey string, addr address) int64 {
	return getImplementation().BalanceOf(tokenKey, addr)
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
	return getImplementation().Allowance(tokenKey, owner, spender)
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
	return getImplementation().Transfer(0, rlm, tokenKey, to, amount)
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
	return getImplementation().TransferFrom(0, rlm, tokenKey, from, to, amount)
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
	return getImplementation().Approve(0, rlm, tokenKey, spender, amount)
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
	if err := Transfer(0, rlm, tokenKey, to, amount); err != nil {
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
	if err := TransferFrom(0, rlm, tokenKey, from, to, amount); err != nil {
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
	if err := Approve(0, rlm, tokenKey, spender, amount); err != nil {
		panic(err)
	}
}
