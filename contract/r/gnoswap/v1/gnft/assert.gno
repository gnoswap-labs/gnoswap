package gnft

import (
	"std"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"
)

// assertIsValidTokenURI panics if the token already has a URI set.
func assertIsValidTokenURI(tid grc721.TokenID) {
	uri, _ := nft.TokenURI(tid)
	if string(uri) != "" {
		panic(makeErrorWithDetails(errCannotSetURI, ufmt.Sprintf("token id (%s) has already set URI", string(tid))))
	}
}

// assertIsValidAddress panics if the address is invalid.
func assertIsValidAddress(addr std.Address) {
	if !addr.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("address (%s)", addr.String())))
	}
}

// assertFromIsValidAddress panics if the from address is invalid.
func assertFromIsValidAddress(from std.Address) {
	if !from.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("from address (%s)", from.String())))
	}
}

// assertToIsValidAddress panics if the to address is invalid.
func assertToIsValidAddress(to std.Address) {
	if !to.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("to address (%s)", to.String())))
	}
}
