package common

import (
	"regexp"
	"std"
	"strings"

	"gno.land/p/demo/tokens/grc20"
	"gno.land/p/nt/ufmt"
	"gno.land/r/demo/defi/grc20reg"
)

var re = regexp.MustCompile(`\[gno\.land/r/[^\]]+\]`)

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

// extractTokenPathsFromRender extracts token paths from rendered grc20reg output.
func extractTokenPathsFromRender(render string) []string {
	matches := re.FindAllString(render, -1)

	tokenPaths := make([]string, 0, len(matches))
	for _, match := range matches {
		tokenPath := strings.Trim(match, "[]") // Remove the brackets
		tokenPaths = append(tokenPaths, tokenPath)
	}
	return tokenPaths
}

// TotalSupply returns the total supply of the specified token.
func TotalSupply(path string) int64 {
	return GetToken(path).TotalSupply()
}

// BalanceOf returns the token balance for the specified address.
func BalanceOf(path string, addr std.Address) int64 {
	return GetToken(path).BalanceOf(addr)
}

// Allowance returns the token allowance from owner to spender.
func Allowance(path string, owner, spender std.Address) int64 {
	return GetToken(path).Allowance(owner, spender)
}

// Transfer transfers tokens to the specified address using grc20.Teller.Transfer.
func Transfer(cur realm, path string, to std.Address, amount int64) error {
	return GetTokenTeller(path).Transfer(to, amount)
}

// TransferFrom transfers tokens from one address to another using grc20.Teller.TransferFrom.
func TransferFrom(cur realm, path string, from, to std.Address, amount int64) error {
	return GetTokenTeller(path).TransferFrom(from, to, amount)
}

// Approve approves tokens for the specified spender using grc20.Teller.Approve.
func Approve(cur realm, path string, spender std.Address, amount int64) error {
	return GetTokenTeller(path).Approve(spender, amount)
}
