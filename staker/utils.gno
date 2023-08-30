package staker

import (
	"std"

	"gno.land/p/demo/grc/grc721"
	"gno.land/r/demo/users"
)

func require(condition bool, message string) {
	if !condition {
		panic(message)
	}
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic("[STAKER] utils.gno__tid() || tokenId is nil")
	}

	switch tokenId.(type) {
	case bigint:
		return grc721.TokenID(string(tokenId.(bigint)))
	case string:
		return grc721.TokenID(tokenId.(string))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic("[STAKER] utils.gno__tid() || tokenId is not a type of string or grc721.TokenID")
	}
}

func requireUnsigned(x bigint, msg string) {
	if x < 0 {
		panic(msg)
	}
}
