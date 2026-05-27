package gnft

import (
	"strconv"

	"gno.land/p/demo/tokens/grc721"
	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
)

var positionAddr = access.MustGetAddress(prbac.ROLE_POSITION.String())

// tid is a test helper function that converts uint64 to TokenID
func tid(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(id, 10))
}
