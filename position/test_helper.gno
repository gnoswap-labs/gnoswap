package position

import (
	"std"

	"gno.land/p/demo/grc/grc721"

	"gno.land/r/bar"
	"gno.land/r/foo"
)

// Testing
func getNextId() uint64 {
	return nextId
}

func tid(tokenId uint64) grc721.TokenID {
	return grc721.TokenID(tokenId)
}

func Token0Bal(addr std.Address) bigint {
	return bigint(foo.BalanceOf(a2u(addr)))
}

func Token1Bal(addr std.Address) bigint {
	return bigint(bar.BalanceOf(a2u(addr)))
}
