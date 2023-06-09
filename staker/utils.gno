package staker

import (
	"std"
	"gno.land/r/demo/users"
	"gno.land/p/demo/grc/grc721"
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
		panic("tokenId is nil")
	}

	switch tokenId.(type) {
	case bigint:
		return grc721.TokenID(string(tokenId.(bigint)))
	case string:
		return grc721.TokenID(tokenId.(string))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic("tokenId is not a string or TokenID")
	}
}

func requireUnsigned(x bigint, msg string) {
	if x < 0 {
		panic(msg)
	}
}