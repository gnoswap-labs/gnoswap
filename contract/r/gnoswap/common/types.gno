package common

type ICommon interface {
	IsRegistered(tokenKey string) bool

	TotalSupply(tokenKey string) int64
	BalanceOf(tokenKey string, addr address) int64
	Allowance(tokenKey string, owner, spender address) int64

	// Mutating methods take `_ int, rlm realm` so the caller's realm token is
	// threaded down to the token teller bound to that realm.
	Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) error
	TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) error
	Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) error
}
