package gnft

import (
	"testing"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

func InitGNFTTest(t *testing.T) {
	t.Helper()

	func(cur realm) {
		nft = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
	}(cross)
}

func setHalted(halted bool) {
	adminAddr, _ := access.GetAddress(rbac.ROLE_ADMIN.String())
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	halt.SetOperationStatus(cross, halt.OpTypePosition, 1, halted)
}
