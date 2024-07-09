package staker

import (
	"std"

	"gno.land/r/gnoswap/consts"
)

var defaultAllowed = []string{consts.GNS_PATH, consts.WUGNOT_PATH, consts.GNOT}
var allowedTokens = []string{}

func init() {
	allowedTokens = defaultAllowed
}

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
