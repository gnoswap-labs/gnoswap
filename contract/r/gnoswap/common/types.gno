package common

type ICommon interface {
	// ValidateNotHandleNativeCoin returns an error when the current transaction
	// carries native coins.
	ValidateNotHandleNativeCoin() error

	// IsRegistered returns nil when tokenKey is a valid, registered key.
	IsRegistered(tokenKey string) error
	// ValidateRegistered returns the first registration failure among tokenKeys.
	ValidateRegistered(tokenKeys ...string) error

	TotalSupply(tokenKey string) int64
	BalanceOf(tokenKey string, addr address) int64
	Allowance(tokenKey string, owner, spender address) int64

	// Mutating methods take `_ int, rlm realm` so the caller's realm token is
	// threaded down to the token teller bound to that realm.
	Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) error
	TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) error
	Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) error
	Render(path string) string
}
