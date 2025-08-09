package gnft

import (
	"std"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/halt"
)

var (
	nft   = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
	owner = ownable.NewWithAddress(getPositionAddress())
)

// Name returns the NFT collection name.
func Name() string {
	return nft.Name()
}

// Symbol returns the NFT symbol.
func Symbol() string {
	return nft.Symbol()
}

// TotalSupply returns the total number of NFTs minted.
func TotalSupply() int64 {
	return nft.TokenCount()
}

// TokenURI returns the metadata URI for the specified token ID.
func TokenURI(tid grc721.TokenID) (string, error) {
	uri, err := nft.TokenURI(tid)
	if err != nil {
		return "", err
	}

	return string(uri), nil
}

// BalanceOf returns the number of NFTs owned by the specified address.
func BalanceOf(owner std.Address) (int64, error) {
	assertIsValidAddress(owner)

	balance, err := nft.BalanceOf(owner)
	if err != nil {
		return 0, err
	}
	return balance, nil
}

// OwnerOf returns the owner address for the specified token ID.
func OwnerOf(tid grc721.TokenID) (std.Address, error) {
	ownerAddr, err := nft.OwnerOf(tid)
	if err != nil {
		return "", err
	}

	return ownerAddr, nil
}

// MustOwnerOf returns the owner address for the specified token ID.
// It panics if the token ID is invalid.
func MustOwnerOf(tid grc721.TokenID) std.Address {
	ownerAddr, err := OwnerOf(tid)
	if err != nil {
		panic(err.Error())
	}

	return ownerAddr
}

// SetTokenURI sets the metadata URI for the specified token.
// Only callable by position contract.
func SetTokenURI(cur realm, tid grc721.TokenID, tURI grc721.TokenURI) (bool, error) {
	halt.AssertIsNotHaltedPosition()

	assertIsValidTokenURI(tid)

	err := setTokenURI(tid, tURI)
	if err != nil {
		panic(err)
	}

	return true, nil
}

// SafeTransferFrom transfers token ownership.
func SafeTransferFrom(cur realm, from, to std.Address, tid grc721.TokenID) error {
	halt.AssertIsNotHaltedPosition()

	assertFromIsValidAddress(from)
	assertToIsValidAddress(to)

	err := nft.SafeTransferFrom(from, to, tid)
	checkTransferErr(err, from, to, tid)
	return nil
}

// TransferFrom transfers a token from one address to another.
// This function is a direct wrapper around SafeTransferFrom.
func TransferFrom(cur realm, from, to std.Address, tid grc721.TokenID) error {
	halt.AssertIsNotHaltedPosition()

	assertFromIsValidAddress(from)
	assertToIsValidAddress(to)

	err := nft.TransferFrom(from, to, tid)
	checkTransferErr(err, from, to, tid)
	return nil
}

// Approve grants permission to transfer a specific token ID to another address.
func Approve(cur realm, approved std.Address, tid grc721.TokenID) error {
	halt.AssertIsNotHaltedPosition()
	assertIsValidAddress(approved)

	err := nft.Approve(approved, tid)
	checkApproveErr(err, approved, tid)
	return nil
}

// SetApprovalForAll enables/disables operator approval for all tokens.
func SetApprovalForAll(cur realm, operator std.Address, approved bool) error {
	halt.AssertIsNotHaltedPosition()
	assertIsValidAddress(operator)

	checkErr(nft.SetApprovalForAll(operator, approved))
	return nil
}

// GetApproved returns approved address for token ID.
func GetApproved(tid grc721.TokenID) (std.Address, error) {
	return nft.GetApproved(tid)
}

// IsApprovedForAll checks if operator can manage all owner's tokens.
func IsApprovedForAll(owner, operator std.Address) bool {
	return nft.IsApprovedForAll(owner, operator)
}

// Mint creates new NFT and transfers to address.
// Only callable by position contract.
// Mints to position contract, sets SVG URI, then transfers to recipient.
func Mint(cur realm, to std.Address, tid grc721.TokenID) grc721.TokenID {
	halt.AssertIsNotHaltedPosition()
	owner.AssertOwnedByPrevious()

	ownerAddress := owner.Owner()

	checkErr(nft.Mint(ownerAddress, tid))

	tokenURI := genImageURI(generateRandInstance())
	err := setTokenURI(tid, grc721.TokenURI(tokenURI))
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

// Burn removes a specific token ID (only callable by owner).
func Burn(cur realm, tid grc721.TokenID) {
	halt.AssertIsNotHaltedPosition()
	owner.AssertOwnedByPrevious()

	checkErr(nft.Burn(tid))
}

// Render returns the HTML representation of the NFT.
// Returns 404 if path is invalid.
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

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetTokenURI",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"tokenId", string(tid),
		"tokenURI", string(tURI),
	)

	return nil
}
