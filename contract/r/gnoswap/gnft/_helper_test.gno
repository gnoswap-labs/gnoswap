package gnft

import (
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

func setHalted(halted bool) {
	adminAddr, _ := access.GetAddress(rbac.ROLE_ADMIN.String())
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	halt.SetOperationStatus(cross, halt.OpTypePosition, halted)
}

// tid is a test helper function that converts uint64 to TokenID
func tid(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(id, 10))
}
