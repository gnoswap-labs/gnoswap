package gnft

import (
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/grc721/v0"
	"gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
)

// assertIsValidTokenURI panics when tid already has a non-empty token URI.
//
// Parameters:
//   - tid: token identifier whose stored metadata URI is checked
func assertIsValidTokenURI(tid grc721.TokenID) {
	uri, _ := meta.TokenURI(tid)
	if uri != "" {
		panic(makeErrorWithDetails(errCannotSetURI, ufmt.Sprintf("token id (%s) has already set URI", string(tid))))
	}
}

// assertIsNonEmptyTokenURI panics when tURI is empty.
//
// Parameters:
//   - tURI: new token metadata URI that must contain at least one character
func assertIsNonEmptyTokenURI(tURI string) {
	if tURI == "" {
		panic(makeErrorWithDetails(errCannotSetURI, "empty token URI"))
	}
}

// assertIsValidAddress panics when addr is not a valid address.
//
// Parameters:
//   - addr: address value to validate
func assertIsValidAddress(addr address) {
	if !addr.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("address (%s)", addr.String())))
	}
}

// assertFromIsValidAddress panics when from is not a valid source address.
//
// Parameters:
//   - from: source address used by a transfer
func assertFromIsValidAddress(from address) {
	if !from.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("from address (%s)", from.String())))
	}
}

// assertToIsValidAddress panics when to is not a valid destination address.
//
// Parameters:
//   - to: destination address used by a transfer
func assertToIsValidAddress(to address) {
	if !to.IsValid() {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("to address (%s)", to.String())))
	}
}

// assertIsAllowedTransfer permits ordinary ledger transfers and restricts
// staked NFTs held by the staker to transfers initiated by that staker.
//
// Parameters:
//   - caller: address initiating the transfer
//   - tid: token identifier whose owner and staking status are checked
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
