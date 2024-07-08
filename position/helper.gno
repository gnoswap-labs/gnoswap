package position

import (
	"strconv"

	"gno.land/p/demo/grc/grc721"
)

func getNextId() uint64 {
	return nextId
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic("[POSITION] test_helper.gno__tid() || tokenId is nil")
	}

	switch tokenId.(type) {
	case string:
		return grc721.TokenID(tokenId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(tokenId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(tokenId.(uint64))))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic("[POSITION] utils.gno__tid() || unsupported tokenId type")
	}
}
