package gnft

import (
	"chain/runtime"

	"gno.land/p/demo/tokens/grc721"
	prabc "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
)

// assertIsValidTokenURI panics if the token already has a URI set.
func assertIsValidTokenURI(tid grc721.TokenID) {
	uri, _ := nft.TokenURI(tid)
	if string(uri) != "" {
		panic(makeErrorWithDetails(errCannotSetURI, ufmt.Sprintf("token id (%s) has already set URI", string(tid))))
	}
}

// assertIsValidAddress panics if the address is invalid.
func assertIsValidAddress(addr address) {
	if !addr.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("address (%s)", addr.String())))
	}
}

// assertFromIsValidAddress panics if the from address is invalid.
func assertFromIsValidAddress(from address) {
	if !from.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("from address (%s)", from.String())))
	}
}

// assertToIsValidAddress panics if the to address is invalid.
func assertToIsValidAddress(to address) {
	if !to.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("to address (%s)", to.String())))
	}
}

// assertIsAllowedTransfer enforces that NFTs held
// by the staker (i.e. currently staked) can only be moved by the staker itself.
// Other tokens fall through to the standard GRC721 owner/approval checks performed inside nft.
func assertIsAllowedTransfer(tid grc721.TokenID) {
	owner, err := nft.OwnerOf(tid)
	if err != nil {
		// Surface the same not-found error as the standard transfer path.
		checkErr(err)
	}

	stakerAddr := access.MustGetAddress(prabc.ROLE_STAKER.String())
	if owner != stakerAddr {
		return
	}

	caller := runtime.PreviousRealm().Address()
	if caller != stakerAddr {
		panic(makeErrorWithDetails(
			errStakedTokenLocked,
			ufmt.Sprintf("token (%s) is held by staker", string(tid)),
		))
	}
}
