package gnft

import (
	"gno.land/p/demo/tokens/grc721"
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
)

// assertIsValidTokenURI panics if the token already has a URI set.
func assertIsValidTokenURI(tid grc721.TokenID) {
	uri, _ := meta.TokenURI(tid)
	if uri != "" {
		panic(makeErrorWithDetails(errCannotSetURI, ufmt.Sprintf("token id (%s) has already set URI", string(tid))))
	}
}

// assertIsNonEmptyTokenURI panics if the new URI is empty.
func assertIsNonEmptyTokenURI(tURI string) {
	if tURI == "" {
		panic(makeErrorWithDetails(errCannotSetURI, "empty token URI"))
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
// Other tokens fall through to the standard GRC721 owner/approval checks performed inside ledger.
func assertIsAllowedTransfer(caller address, tid grc721.TokenID) {
	owner, err := token.OwnerOf(tid)
	if err != nil {
		// Surface the same not-found error as the standard transfer path.
		checkErr(err)
	}

	stakerAddr := access.MustGetAddress(prabc.ROLE_STAKER.String())
	if owner != stakerAddr {
		return
	}

	if caller != stakerAddr {
		panic(makeErrorWithDetails(
			errStakedTokenLocked,
			ufmt.Sprintf("token (%s) is held by staker", string(tid)),
		))
	}
}
