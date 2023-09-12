package position

import (
	"std"
	"strconv"

	"gno.land/p/demo/grc/grc721"

	"gno.land/r/bar"
	"gno.land/r/foo"
)

// Testing
func getNextId() uint64 {
	return nextId
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic("[POSITION] test_helper.gno__tid() || tokenId is nil")
	}

	switch tokenId.(type) {
	case bigint:
		return grc721.TokenID(string(tokenId.(bigint)))
	case string:
		return grc721.TokenID(tokenId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(tokenId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(tokenId.(uint64))))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic("[STAKER] utils.gno__tid() || unsupported tokenId type")
	}
}

func Token0Bal(addr std.Address) bigint {
	return bigint(foo.BalanceOf(a2u(addr)))
}

func Token1Bal(addr std.Address) bigint {
	return bigint(bar.BalanceOf(a2u(addr)))
}
