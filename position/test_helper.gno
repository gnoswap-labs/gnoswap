package position

import (
	"std"

	"gno.land/p/demo/grc/grc721"

	"gno.land/r/bar"
	"gno.land/r/foo"

	nft "gno.land/r/gnft"
)

// Testing
func GetNextId() bigint {
	return nextId
}

func tid(tokenId string) grc721.TokenID {
	return grc721.TokenID(tokenId)
}

func Token0Bal(addr std.Address) bigint {
	return bigint(foo.BalanceOf(a2u(addr)))
}

func Token1Bal(addr std.Address) bigint {
	return bigint(bar.BalanceOf(a2u(addr)))
}
