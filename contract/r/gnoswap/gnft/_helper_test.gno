package gnft

import (
	"strconv"

	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/nt/grc721/v0"
	"gno.land/r/gnoswap/access/v1"
)

var positionAddr = access.MustGetAddress(prbac.ROLE_POSITION.String())

// tid is a test helper function that converts uint64 to TokenID
func tid(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(id, 10))
}
