package gnft

import (
	"errors"
	"math/rand"
	"time"

	"gno.land/p/nt/grc721/v0"
	"gno.land/p/nt/ufmt/v0"
)

// generateRandInstance creates a time- and supply-seeded pseudo-random generator
// for artwork parameters; it is not suitable for secure or cryptographic randomness.
//
// Returns:
//   - rand: pseudo-random generator initialized from the current time and token supply
func generateRandInstance() *rand.Rand {
	now := time.Now()
	seed1 := now.Unix() + TotalSupply()
	seed2 := now.UnixNano() + TotalSupply()
	pcg := rand.NewPCG(uint64(seed1), uint64(seed2))
	return rand.New(pcg)
}

// checkErr panics with err's message when err is non-nil and otherwise returns.
//
// Parameters:
//   - err: operation error to check; nil means the operation succeeded
func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}

// checkTransferErr translates a failed GRC721 transfer into a contextual panic.
// It verifies the token owner before distinguishing ownership, approval,
// destination-address, source-owner, and token-ID failures.
//
// Parameters:
//   - err: error returned by the attempted GRC721 transfer
//   - caller: address that initiated the transfer
//   - from: source address supplied to the transfer
//   - to: destination address supplied to the transfer
//   - tid: token identifier involved in the transfer
func checkTransferErr(err error, caller, from, to address, tid grc721.TokenID) {
	if err == nil {
		return
	}

	// Check if token exists
	owner, ownerErr := token.OwnerOf(tid)
	if ownerErr != nil {
		panic(ownerErr)
	}

	switch err {
	case grc721.ErrCallerIsNotOwnerOrApproved:
		// Check if caller is the owner
		if caller == owner {
			panic(makeErrorWithDetails(grc721.ErrTransferFromIncorrectOwner.Error(), ufmt.Sprintf("owner mismatch - from: %s, actual owner: %s, token: %s", from, owner, string(tid))))
		}

		// Check if caller is approved for this specific token
		approved, _ := token.GetApproved(tid)
		if approved != caller {
			// Check if caller is approved for all tokens
			if !token.IsApprovedForAll(owner, caller) {
				panic(makeErrorWithDetails(grc721.ErrCallerIsNotOwnerOrApproved.Error(), ufmt.Sprintf("caller %s is not owner %s or approved for token %s", caller, owner, string(tid))))
			}
		}

	case grc721.ErrInvalidAddress:
		panic(makeErrorWithDetails(grc721.ErrInvalidAddress.Error(), ufmt.Sprintf("to address (%s)", to)))

	case grc721.ErrTransferFromIncorrectOwner:
		panic(makeErrorWithDetails(grc721.ErrTransferFromIncorrectOwner.Error(), ufmt.Sprintf("from %s is not the owner %s of token %s", from, owner, string(tid))))

	case grc721.ErrInvalidTokenId:
		panic(makeErrorWithDetails(grc721.ErrInvalidTokenId.Error(), ufmt.Sprintf("token %s", string(tid))))

	default:
		panic(err.Error())
	}
}

// checkApproveErr translates a failed GRC721 approval into a contextual panic.
//
// Parameters:
//   - err: error returned by the attempted approval
//   - caller: address that initiated the approval
//   - approved: address designated to receive token approval
//   - tid: token identifier for which approval was attempted
func checkApproveErr(err error, caller, approved address, tid grc721.TokenID) {
	if err == nil {
		return
	}

	switch {
	case errors.Is(err, grc721.ErrInvalidTokenId):
		panic(makeErrorWithDetails(errTokenNotExists, ufmt.Sprintf("token %s", string(tid))))

	case errors.Is(err, grc721.ErrCallerIsNotOwnerOrApproved):
		owner, ownerErr := token.OwnerOf(tid)
		checkErr(ownerErr)
		panic(makeErrorWithDetails(errNotOwnerOrApproved, ufmt.Sprintf("caller %s cannot approve for token %s owned by %s", caller, string(tid), owner)))

	case errors.Is(err, grc721.ErrApprovalToCurrentOwner):
		panic(makeErrorWithDetails(errTransferToSelf, ufmt.Sprintf("cannot approve to current owner %s for token %s", approved, string(tid))))

	default:
		panic(err.Error())
	}
}
