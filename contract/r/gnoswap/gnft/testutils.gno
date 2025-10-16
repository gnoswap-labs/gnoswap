package gnft

import (
	"testing"

	"gno.land/p/demo/tokens/grc721"
)

func InitGNFTTest(t *testing.T) {
	t.Helper()

	func(cur realm) {
		nft = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
	}(cross)
}
