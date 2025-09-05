package gnft

import (
	"math/rand"
	"std"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/rbac"
)

func getPositionAddress() std.Address {
	addr, exists := access.GetAddress(prabc.ROLE_POSITION.String())
	if !exists {
		return rbac.DefaultRoleAddresses[prabc.ROLE_POSITION]
	}

	return addr
}

// tid converts uint64 to grc721.TokenID.
func tid(id uint64) grc721.TokenID {
	return grc721.TokenID(ufmt.Sprintf("%d", id))
}

// generateRandInstance generates a new random instance.
func generateRandInstance() *rand.Rand {
	seed1 := time.Now().Unix() + TotalSupply()
	seed2 := time.Now().UnixNano() + TotalSupply()
	pcg := rand.NewPCG(uint64(seed1), uint64(seed2))
	return rand.New(pcg)
}

// checkErr panics if an error occurs.
func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}

// checkTransferErr wraps transfer errors with more specific context.
func checkTransferErr(err error, from, to std.Address, tid grc721.TokenID) {
	if err == nil {
		return
	}

	caller := std.PreviousRealm().Address()

	// Check if token exists
	owner, ownerErr := nft.OwnerOf(tid)
	if ownerErr != nil {
		panic(ownerErr)
	}

	switch err {
	case grc721.ErrCallerIsNotOwnerOrApproved:
		// Check if caller is the owner
		if caller == owner {
			panic(makeErrorWithDetails(grc721.ErrTransferFromIncorrectOwner, ufmt.Sprintf("owner mismatch - from: %s, actual owner: %s, token: %s", from, owner, string(tid))))
		}

		// Check if caller is approved for this specific token
		approved, _ := nft.GetApproved(tid)
		if approved != caller {
			// Check if caller is approved for all tokens
			if !nft.IsApprovedForAll(owner, caller) {
				panic(makeErrorWithDetails(grc721.ErrCallerIsNotOwnerOrApproved, ufmt.Sprintf("caller %s is not owner %s or approved for token %s", caller, owner, string(tid))))
			}
		}

	case grc721.ErrInvalidAddress:
		panic(makeErrorWithDetails(grc721.ErrInvalidAddress, ufmt.Sprintf("to address (%s)", to)))

	case grc721.ErrTransferFromIncorrectOwner:
		panic(makeErrorWithDetails(grc721.ErrTransferFromIncorrectOwner, ufmt.Sprintf("from %s is not the owner %s of token %s", from, owner, string(tid))))

	case grc721.ErrInvalidTokenId:
		panic(makeErrorWithDetails(grc721.ErrInvalidTokenId, ufmt.Sprintf("token %s", string(tid))))

	default:
		panic(err.Error())
	}
}

// checkApproveErr wraps approve errors with more specific context.
func checkApproveErr(err error, approved std.Address, tid grc721.TokenID) {
	if err == nil {
		return
	}

	errMsg := err.Error()
	caller := std.PreviousRealm().Address()

	// Check if token exists
	owner, ownerErr := nft.OwnerOf(tid)
	if ownerErr != nil {
		panic(makeErrorWithDetails(errTokenNotExists, ufmt.Sprintf("token %s", string(tid))))
	}

	switch {
	case errMsg == "caller is not token owner or approved":
		panic(makeErrorWithDetails(errNotOwnerOrApproved, ufmt.Sprintf("caller %s cannot approve for token %s owned by %s", caller, string(tid), owner)))

	case errMsg == "approval to current owner":
		panic(makeErrorWithDetails(errTransferToSelf, ufmt.Sprintf("cannot approve to current owner %s for token %s", approved, string(tid))))

	default:
		panic(err.Error())
	}
}
