package gnft

import (
	"std"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
)

// assertCallerIsOwnerOfToken asserts that the caller is the owner of the token
// Parameters:
//   - tid: The token ID to check ownership of
func assertIsOwnerOfToken(tid grc721.TokenID) {
	caller := std.PreviousRealm().Address()
	owner, _ := OwnerOf(tid)
	if caller != owner {
		panic(makeErrorWithDetails(errNoPermission, ufmt.Sprintf("caller (%s) is not the owner of token (%s)", caller, string(tid))))
	}
}

// assertIsEmptyTokenURI panics if the token URI is not empty.
func assertIsEmptyTokenURI(tid grc721.TokenID) {
	uri, _ := nft.TokenURI(tid)
	if string(uri) != "" {
		panic(makeErrorWithDetails(errCannotSetURI, ufmt.Sprintf("token id (%s) has already set URI", string(tid))))
	}
}

func assertHasToken(caller std.Address) {
	tokenListByCaller, ok := getTokenList(caller)
	if !ok {
		panic(makeErrorWithDetails(errNoTokenForCaller, ufmt.Sprintf("caller (%s)", caller)))
	}

	lenTokenListByCaller := len(tokenListByCaller)
	if lenTokenListByCaller == 0 {
		panic(makeErrorWithDetails(errNoTokenForCaller, ufmt.Sprintf("caller (%s)", caller)))
	}
}