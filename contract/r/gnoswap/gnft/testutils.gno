package gnft

import (
	"testing"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/r/gnoswap/halt"
)

func InitGNFTTest(t *testing.T) {
	t.Helper()

	func(cur realm) {
		nft = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
	}(cross)
}

func setHalted(halted bool) {
	adminAddr := getAdminAddress()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	halt.SetOperationStatus(cross, halt.OpTypePosition, 1, halted)
}

func getAdminAddress() address {
	return "g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d"
}
