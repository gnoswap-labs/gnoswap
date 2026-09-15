package common

type ICommon interface {
	// ValidateNotHandleNativeCoin rejects a call carrying native coins.
	//
	// Returns:
	//   - error: non-nil when the transaction includes native coins; nil when no native coins are attached
	ValidateNotHandleNativeCoin() error

	// IsRegistered checks whether tokenKey identifies a registered token.
	//
	// Parameters:
	//   - tokenKey: token registry key to validate and look up
	//
	// Returns:
	//   - error: nil when tokenKey is valid and registered; non-nil for an invalid or unregistered key
	IsRegistered(tokenKey string) error

	// ValidateRegistered checks each token key in order.
	//
	// Parameters:
	//   - tokenKeys: token registry keys that must all be valid and registered
	//
	// Returns:
	//   - error: nil when every key is registered; otherwise the first registration failure in input order
	ValidateRegistered(tokenKeys ...string) error

	// TotalSupply returns the total supply of a registered token.
	//
	// Parameters:
	//   - tokenKey: token registry key whose supply is queried
	//
	// Returns:
	//   - totalSupply: token's total supply; panics if tokenKey is invalid or unregistered
	TotalSupply(tokenKey string) int64

	// BalanceOf returns a registered token's balance for an address.
	//
	// Parameters:
	//   - tokenKey: token registry key whose balance is queried
	//   - addr: account address whose token balance is queried
	//
	// Returns:
	//   - balance: token units held by addr; panics if tokenKey is invalid or unregistered
	BalanceOf(tokenKey string, addr address) int64

	// Allowance returns the approved spendable amount for an owner/spender pair.
	//
	// Parameters:
	//   - tokenKey: token registry key whose allowance is queried
	//   - owner: account that granted spending approval
	//   - spender: account allowed to spend owner's tokens
	//
	// Returns:
	//   - allowance: token units owner has approved for spender; panics if tokenKey is invalid or unregistered
	Allowance(tokenKey string, owner, spender address) int64

	// Transfer asks the token teller bound to rlm to move tokens to to.
	//
	// Parameters:
	//   - _: leading token-call discriminator; callers pass 0
	//   - rlm: propagated realm context used to bind the token teller and invoke the transfer
	//   - tokenKey: token registry key whose tokens are transferred
	//   - to: recipient account address
	//   - amount: number of token units to transfer
	//
	// Panics if tokenKey is invalid or unregistered before the teller is invoked.
	//
	// Returns:
	//   - error: nil when the teller completes the transfer; otherwise an error
	//     returned by the teller for transfer-rule validation or execution failure
	Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) error

	// TransferFrom asks the token teller bound to rlm to transfer tokens from one account to another.
	//
	// Parameters:
	//   - _: leading token-call discriminator; callers pass 0
	//   - rlm: propagated realm context used to bind the token teller and invoke the transfer
	//   - tokenKey: token registry key whose tokens are transferred
	//   - from: account whose token balance is debited
	//   - to: recipient account address
	//   - amount: number of token units to transfer
	//
	// Panics if tokenKey is invalid or unregistered before the teller is invoked.
	//
	// Returns:
	//   - error: nil when the teller completes the transfer; otherwise an error
	//     returned by the teller for transfer, allowance, or balance-rule failure
	TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) error

	// Approve asks the token teller bound to rlm to set spender's allowance.
	//
	// Parameters:
	//   - _: leading token-call discriminator; callers pass 0
	//   - rlm: propagated realm context used to bind the token teller and invoke approval
	//   - tokenKey: token registry key whose tokens are approved
	//   - spender: account receiving permission to spend the caller's tokens
	//   - amount: number of token units to authorize
	//
	// Panics if tokenKey is invalid or unregistered before the teller is invoked.
	//
	// Returns:
	//   - error: nil when the teller records the allowance; otherwise an error
	//     returned by the teller for approval-rule validation or execution failure
	Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) error
	Render(path string) string
}
