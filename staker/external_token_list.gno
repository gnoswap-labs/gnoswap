package staker

import (
	"std"

	"gno.land/r/gnoswap/v2/consts"
)

// defaultAllowed is the list of default allowed tokens to create external incentive
var defaultAllowed = []string{consts.GNS_PATH, consts.WUGNOT_PATH, consts.GNOT}

// allowedTokens is a slice of all allowed token paths, including the default and added tokens.
var allowedTokens = []string{}

func init() {
	allowedTokens = defaultAllowed
}

// AddToken adds a new token path to the list of allowed tokens
// Only the admin (GNOSWAP_ADMIN) can add a new token.
//
// Parameters:
//   - tokenPath (string): The path of the token to add
//
// Panics:
//   - If the caller is not the GNOSWAP_ADMIN
func AddToken(tokenPath string) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN {
		panic("only admin can add token")
	}

	// if exist just return
	for _, t := range allowedTokens {
		if t == tokenPath {
			return
		}
	}

	allowedTokens = append(allowedTokens, tokenPath)
}

// RemoveToken removes a token path from the list of allowed tokens.
// Only the admin (GNOSWAP_ADMIN) can remove a token.
//
// Default tokens can not be removed.
//
// Parameters:
//   - tokenPath (string): The path of the token to remove
//
// Panics:
//   - If the caller is not the GNOSWAP_ADMIN
func RemoveToken(tokenPath string) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN {
		panic("only admin can remove token")
	}

	// if default token, can not remove
	isDefault := contains(defaultAllowed, tokenPath)
	if isDefault {
		panic("can not remove default token")
	}

	for i, t := range allowedTokens {
		if t == tokenPath {
			allowedTokens = append(allowedTokens[:i], allowedTokens[i+1:]...)
			return
		}
	}
}
