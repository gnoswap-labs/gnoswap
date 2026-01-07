package gnft

import (
	"chain"
	"chain/runtime"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ownable"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"
)

var (
	nft   = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
	positionAddr = access.MustGetAddress(prabc.ROLE_POSITION.String())
	owner = ownable.NewWithAddress(positionAddr)
)

// TokenURI returns the metadata URI for the specified token ID.
// If stored value is in parameter format (x1,y1,x2,y2,color1,color2),
// it converts to full base64-encoded SVG image URI on read.
func TokenURI(tid grc721.TokenID) (string, error) {
	stored, err := nft.TokenURI(tid)
	if err != nil {
		return "", err
	}

	storedStr := string(stored)

	// Check if it looks like SVG parameters format (x1,y1,x2,y2,color1,color2)
	if isImageParams(storedStr) {
		return paramsToImageURI(storedStr), nil
	}

	return storedStr, nil
}

// BalanceOf returns the number of NFTs owned by the specified address.
func BalanceOf(owner address) (int64, error) {
	assertIsValidAddress(owner)
	return nft.BalanceOf(owner)
}

// OwnerOf returns the owner address for the specified token ID.
func OwnerOf(tid grc721.TokenID) (address, error) {
	ownerAddr, err := nft.OwnerOf(tid)
	if err != nil {
		return "", err
	}

	return ownerAddr, nil
}

// MustOwnerOf returns the owner address for the specified token ID.
// It panics if the token ID is invalid.
func MustOwnerOf(tid grc721.TokenID) address {
	ownerAddr, err := OwnerOf(tid)
	if err != nil {
		panic(err.Error())
	}

	return ownerAddr
}

// SetTokenURI sets the metadata URI for the specified token.
//
// Parameters:
//   - tid: token ID
//   - tURI: token URI
//
// Only callable by position contract.
func SetTokenURI(cur realm, tid grc721.TokenID, tURI grc721.TokenURI) (bool, error) {
	halt.AssertIsNotHaltedPosition()
	owner.AssertOwnedByPrevious()

	assertIsValidTokenURI(tid)

	err := setTokenURI(tid, tURI)
	if err != nil {
		panic(err)
	}

	return true, nil
}

// SafeTransferFrom transfers token ownership with receiver validation.
//
// Parameters:
//   - from: current owner address
//   - to: recipient address
//   - tid: token ID to transfer
//
// Returns error if transfer fails.
// Only callable by staker contract.
func SafeTransferFrom(cur realm, from, to address, tid grc721.TokenID) error {
	halt.AssertIsNotHaltedPosition()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsStaker(caller)

	assertFromIsValidAddress(from)
	assertToIsValidAddress(to)

	err := nft.SafeTransferFrom(from, to, tid)
	checkTransferErr(err, from, to, tid)
	return nil
}

// TransferFrom transfers a token from one address to another.
//
// Parameters:
//   - from: current owner address
//   - to: recipient address
//   - tid: token ID
//
// Returns error if transfer fails.
// Only callable by staker contract.
func TransferFrom(cur realm, from, to address, tid grc721.TokenID) error {
	halt.AssertIsNotHaltedPosition()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsStaker(caller)

	assertFromIsValidAddress(from)
	assertToIsValidAddress(to)

	err := nft.TransferFrom(from, to, tid)
	checkTransferErr(err, from, to, tid)
	return nil
}

// Approve grants permission to transfer a specific token ID to another address.
//
// Parameters:
//   - approved: address to approve
//   - tid: token ID to approve for transfer
//
// Returns error if approval fails.
// Only callable when not halted.
func Approve(cur realm, approved address, tid grc721.TokenID) error {
	halt.AssertIsNotHaltedPosition()
	assertIsValidAddress(approved)

	err := nft.Approve(approved, tid)
	checkApproveErr(err, approved, tid)
	return nil
}

// SetApprovalForAll enables/disables operator approval for all tokens.
//
// Parameters:
//   - operator: address to set approval for
//   - approved: true to approve, false to revoke
//
// Returns error if operation fails.
// Only callable when not halted.
func SetApprovalForAll(cur realm, operator address, approved bool) error {
	halt.AssertIsNotHaltedPosition()
	assertIsValidAddress(operator)

	checkErr(nft.SetApprovalForAll(operator, approved))
	return nil
}

// Mint creates new NFT and transfers to address.
//
// Parameters:
//   - to: recipient address
//   - tid: token ID
//
// Returns minted token ID.
// Only callable by position contract.
func Mint(cur realm, to address, tid grc721.TokenID) grc721.TokenID {
	halt.AssertIsNotHaltedPosition()
	owner.AssertOwnedByPrevious()

	ownerAddress := owner.Owner()

	checkErr(nft.Mint(ownerAddress, tid))

	// Store only the gradient parameters instead of full base64 SVG to reduce storage costs.
	// Parameters are converted to full SVG on read via TokenURI().
	imageParams := genImageParams(generateRandInstance())
	err := setTokenURI(tid, grc721.TokenURI(imageParams))
	if err != nil {
		panic(err)
	}

	checkErr(nft.TransferFrom(ownerAddress, to, tid))

	return tid
}

// Exists checks if token ID exists.
func Exists(tid grc721.TokenID) bool {
	_, err := nft.OwnerOf(tid)
	if err != nil {
		return false
	}

	return true
}

// Burn removes a specific token ID.
//
// Parameters:
//   - tid: token ID to burn
//
// Only callable by owner.
func Burn(cur realm, tid grc721.TokenID) {
	halt.AssertIsNotHaltedPosition()
	owner.AssertOwnedByPrevious()

	checkErr(nft.Burn(tid))
}

// Render returns the HTML representation of the NFT.
func Render(path string) string {
	switch {
	case path == "":
		return nft.RenderHome()
	default:
		return "404\n"
	}
}

// setTokenURI sets the metadata URI for a specific token ID.
func setTokenURI(tid grc721.TokenID, tURI grc721.TokenURI) error {
	_, err := nft.SetTokenURI(tid, tURI)
	if err != nil {
		return makeErrorWithDetails(err, ufmt.Sprintf("token id (%s)", tid))
	}

	tokenURI, err := TokenURI(tid)
	if err != nil {
		return makeErrorWithDetails(err, ufmt.Sprintf("token id (%s)", tid))
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetTokenURI",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"tokenId", string(tid),
		"tokenURI", tokenURI,
	)

	return nil
}
