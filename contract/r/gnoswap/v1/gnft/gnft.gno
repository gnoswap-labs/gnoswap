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

// Name returns NFT collection name.
func Name() string {
	return nft.Name()
}

// Symbol returns NFT symbol.
func Symbol() string {
	return nft.Symbol()
}

// TotalSupply returns total NFTs minted.
func TotalSupply() int64 {
	return nft.TokenCount()
}

// TokenURI returns metadata URI for token ID.
func TokenURI(tid grc721.TokenID) (string, error) {
	uri, err := nft.TokenURI(tid)
	if err != nil {
		return "", err
	}

	return string(uri), nil
}

// BalanceOf returns the number of NFTs owned by the specified address.
// Parameters:
//   - owner (std.Address): The address to check the NFT balance for.
//
// Returns:
//   - int64: The number of NFTs owned by the address.
//   - error: Returns an error if the balance retrieval fails.
func BalanceOf(owner std.Address) (int64, error) {
	assertIsValidAddress(owner)

	balance, err := nft.BalanceOf(owner)
	if err != nil {
		return 0, err
	}
	return balance, nil
}

// OwnerOf returns owner address for token ID.
func OwnerOf(tid grc721.TokenID) (std.Address, error) {
	ownerAddr, err := nft.OwnerOf(tid)
	if err != nil {
		return "", err
	}

	return ownerAddr, nil
}

// MustOwnerOf returns owner address for token ID.
// Panics if token ID is invalid.
func MustOwnerOf(tid grc721.TokenID) std.Address {
	ownerAddr, err := OwnerOf(tid)
	if err != nil {
		panic(err.Error())
	}

	return ownerAddr
}

// SetTokenURI sets metadata URI for token.
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
// Validates addresses and checks caller authorization.
func SafeTransferFrom(cur realm, from, to std.Address, tid grc721.TokenID) error {
	halt.AssertIsNotHaltedPosition()

	assertFromIsValidAddress(from)
	assertToIsValidAddress(to)

	err := nft.SafeTransferFrom(from, to, tid)
	checkTransferErr(err, from, to, tid)
	return nil
}

// TransferFrom transfers a token from one address to another
// This function is a direct wrapper around `SafeTransferFrom`, which performs the actual transfer.
//
// Parameters:
//   - from (std.Address): The current owner's address of the token being transferred.
//   - to (std.Address): The recipient's address to receive the token.
//   - tid (grc721.TokenID): The ID of the token to be transferred.
//
// Returns:
//   - error: Returns `nil` if the transfer is successful; otherwise, returns an error.
func TransferFrom(cur realm, from, to std.Address, tid grc721.TokenID) error {
	halt.AssertIsNotHaltedPosition()

	assertFromIsValidAddress(from)
	assertToIsValidAddress(to)

	err := nft.TransferFrom(from, to, tid)
	checkTransferErr(err, from, to, tid)
	return nil
}

// Approve grants permission to transfer a specific token ID to another address.
//
// Parameters:
//   - approved (std.Address): The address to grant transfer approval to.
//   - tid (grc721.TokenID): The token ID to approve for transfer.
//
// Returns:
//   - error: Returns `nil` if the approval is successful, otherwise returns an error.
//
// Panics:
//   - If the contract is halted.
//   - If the caller is not the token owner.
//   - If the `Approve` call fails.
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

// Burn removes a specific token ID (only callable by owner)
// Parameters:
//   - tid: The token ID to burn
func Burn(cur realm, tid grc721.TokenID) {
	halt.AssertIsNotHaltedPosition()
	owner.AssertOwnedByPrevious()

	checkErr(nft.Burn(tid))
}

// Render returns the HTML representation of the NFT
// Parameters:
//   - path: The path to render
//
// Returns:
//   - string: HTML representation of the NFT or 404 if path is invalid
func Render(path string) string {
	switch {
	case path == "":
		return nft.RenderHome()
	default:
		return "404\n"
	}
}

// setTokenURI sets the metadata URI for a specific token ID
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
