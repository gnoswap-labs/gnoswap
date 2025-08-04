package gnft

import (
	"std"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
)

// assertIsValidTokenURI panics if the token URI is not empty.
func assertIsValidTokenURI(tid grc721.TokenID) {
	uri, _ := nft.TokenURI(tid)
	if string(uri) != "" {
		panic(makeErrorWithDetails(errCannotSetURI, ufmt.Sprintf("token id (%s) has already set URI", string(tid))))
	}
}

func assertIsValidAddress(addr std.Address) {
	if !addr.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("address (%s)", addr.String())))
	}
}

func assertFromIsValidAddress(from std.Address) {
	if !from.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("from address (%s)", from.String())))
	}
}

func assertToIsValidAddress(to std.Address) {
	if !to.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("to address (%s)", to.String())))
	}
}
