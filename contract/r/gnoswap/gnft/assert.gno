package gnft

import (
	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
)

// assertIsEmptyTokenURI panics if the token URI is not empty.
func assertIsEmptyTokenURI(tid grc721.TokenID) {
	uri, _ := nft.TokenURI(tid)
	if string(uri) != "" {
		panic(makeErrorWithDetails(errCannotSetURI, ufmt.Sprintf("token id (%s) has already set URI", string(tid))))
	}
}