package gnft

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/halt"
)

var nft = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")

var (
	owner     = ownable.NewWithAddress(getPositionAddress()) // deployed position contract
	tokenList *avl.Tree // addr -> []grc721.TokenID
)

func init() {
	tokenList = avl.NewTree()
}

// Name returns the full name of the NFT
// Returns:
//   - string: The name of the NFT collection
func Name() string {
	return nft.Name()
}

// Symbol returns the token symbol of the NFT
// Returns:
//   - string: The symbol of the NFT collection
func Symbol() string {
	return nft.Symbol()
}

// TotalSupply returns the total number of NFTs minted
// Returns:
//   - int64: The total number of tokens that have been minted
func TotalSupply() int64 {
	return nft.TokenCount()
}

// TokenURI retrieves the metadata URI for a specific token ID
// Parameters:
//   - tid: The unique identifier of the token
//
// Returns:
//   - string: The metadata URI associated with the token
//   - error: Returns an error if the token URI retrieval fails.
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
	balance, err := nft.BalanceOf(owner)
	if err != nil {
		return 0, err
	}
	return balance, nil
}

// OwnerOf returns the current owner's address of a specific token ID
// Parameters:
//   - tid: The token ID to check ownership of
//
// Returns:
//   - std.Address: The address of the token owner
func OwnerOf(tid grc721.TokenID) (std.Address, error) {
	ownerAddr, err := nft.OwnerOf(tid)
	if err != nil {
		return "", err
	}

	return ownerAddr, nil
}

// MustOwnerOf returns the current owner's address of a specific token ID
// Parameters:
//   - tid: The token ID to check ownership of
//
// Returns:
//   - std.Address: The address of the token owner
//
// Panics:
//   - If the token ID is invalid
func MustOwnerOf(tid grc721.TokenID) std.Address {
	ownerAddr, err := OwnerOf(tid)
	if err != nil {
		panic(err.Error())
	}

	return ownerAddr
}

// SetTokenURI sets the metadata URI using a randomly generated SVG image
// Parameters:
//   - tid (grc721.TokenID): The token ID for which the URI will be updated.
//   - tURI (grc721.TokenURI): The new metadata URI to associate with the token.
//
// Returns:
//   - bool: Returns `true` if the operation is successful.
//   - error: Returns an error if the operation fails or the caller is not authorized.
//
// Panics:
//   - If the caller is not the token owner, the function panics.
//   - If the URI update fails, the function panics with the associated error.
func SetTokenURI(cur realm, tid grc721.TokenID, tURI grc721.TokenURI) (bool, error) {
	halt.AssertIsNotHaltedPosition()
	assertIsOwnerOfToken(tid)

	err := setTokenURI(cur, tid, tURI)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetTokenURI",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpTokenId", string(tid),
		"tokenURI", string(tURI),
	)
	
	return true, nil
}

// SafeTransferFrom securely transfers ownership of a token from one address to another.
//
// This function enforces several checks to ensure the transfer is valid and authorized:
//   - Ensures the contract is not halted.
//   - Validates the addresses involved in the transfer.
//   - Checks that the caller is the token owner or has been approved to transfer the token.
//
// After validation, the function updates the internal token lists by removing the token from the sender's list
// and appending it to the recipient's list. It then calls the underlying transfer logic through `nft.TransferFrom`.
//
// Parameters:
//   - from (std.Address): The current owner's address of the token being transferred.
//   - to (std.Address): The recipient's address to receive the token.
//   - tid (grc721.TokenID): The ID of the token to be transferred.
//
// Returns:
//   - error: Returns `nil` if the transfer is successful; otherwise, it raises an error.
//
// Panics:
//   - If the contract is halted.
//   - If either `from` or `to` addresses are invalid.
//   - If the caller is not the owner or approved operator of the token.
//   - If the internal transfer (`nft.TransferFrom`) fails.
func SafeTransferFrom(cur realm, from, to std.Address, tid grc721.TokenID) error {
	halt.AssertIsNotHaltedPosition()
	access.AssertIsValidAddress(from)
	access.AssertIsValidAddress(to)

	caller := std.PreviousRealm().Address()
	ownerAddr, _ := OwnerOf(tid)
	approved, _ := GetApproved(tid)
	if (caller != ownerAddr) && (caller != approved) {
		panic(makeErrorWithDetails(errNoPermission, ufmt.Sprintf("caller (%s) is not the owner or operator of token (%s)", caller, string(tid))))
	}

	removeTokenList(from, tid)
	appendTokenList(to, tid)

	checkErr(nft.TransferFrom(from, to, tid))
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
	return SafeTransferFrom(cur, from, to, tid)
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
	assertIsOwnerOfToken(tid)

	err := nft.Approve(approved, tid)
	if err != nil {
		panic(err.Error())
	}
	return nil
}

// SetApprovalForAll enables or disables approval for a third party (`operator`) to manage all tokens owned by the caller.
//
// Parameters:
//   - operator (std.Address): The address to grant or revoke operator permissions for.
//   - approved (bool): `true` to enable approval, `false` to revoke approval.
//
// Returns:
//   - error: Returns `nil` if the operation is successful, otherwise returns an error.
//
// Panics:
//   - If the contract is halted.
//   - If the `SetApprovalForAll` operation fails.
func SetApprovalForAll(cur realm, operator std.Address, approved bool) error {
	checkErr(nft.SetApprovalForAll(operator, approved))
	return nil
}

// GetApproved returns the approved address for a specific token ID.
//
// Parameters:
//   - tid (grc721.TokenID): The token ID to check for approval.
//
// Returns:
//   - std.Address: The address approved to manage the token. Returns an empty address if no approval exists.
//   - error: Returns an error if the lookup fails or the token ID is invalid.
func GetApproved(tid grc721.TokenID) (std.Address, error) {
	return nft.GetApproved(tid)
}

// IsApprovedForAll checks if an operator is approved to manage all tokens of an owner.
//
// Parameters:
//   - owner (std.Address): The address of the token owner.
//   - operator (std.Address): The address to check if it has approval to manage the owner's tokens.
//
// Returns:
//   - bool: true if the operator is approved to manage all tokens of the owner, false otherwise.
func IsApprovedForAll(owner, operator std.Address) bool {
	return nft.IsApprovedForAll(owner, operator)
}

// SetTokenURIByImageURI generates and sets a new token URI for a specified token ID using a random image URI.
//
// Parameters:
//   - tid (grc721.TokenID): The ID of the token for which the URI will be set.
//
// Panics:
//   - If the contract is halted.
//   - If the caller is not the owner of the token.
//   - If the token URI cannot be set.
func SetTokenURIByImageURI(cur realm, tid grc721.TokenID) {
	assertIsOwnerOfToken(tid)

	tokenURI := genImageURI(generateRandInstance())

	err := setTokenURI(cur, tid, grc721.TokenURI(tokenURI))
	if err != nil {
		panic(makeErrorWithDetails(err, ufmt.Sprintf("%s (%s)", err.Error(), string(tid))))
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetTokenURI",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpTokenId", string(tid),
		"tokenURI", string(tokenURI),
	)
}

// SetTokenURILast sets the token URI for the last token owned by the caller using a randomly generated image URI.
//
// This function ensures the contract is active and the caller owns at least one token.
// It retrieves the list of tokens owned by the caller and applies a new token URI to the most recently minted token.
//
// Panics:
//   - If the contract is halted.
//   - If the caller does not own any tokens (empty token list).
//   - If URI generation or assignment fails.
func SetTokenURILast(cur realm) {
	caller := std.PreviousRealm().Address()
	assertHasToken(caller)

	tokenListByCaller, _ := getTokenList(caller)
	lenTokenListByCaller := len(tokenListByCaller)
	lastTokenId := tokenListByCaller[lenTokenListByCaller-1]

	tokenURI := genImageURI(generateRandInstance())
	err := setTokenURI(cur, lastTokenId, grc721.TokenURI(tokenURI))
	if err != nil {
		panic(makeErrorWithDetails(err, ufmt.Sprintf("%s (%s)", err.Error(), string(lastTokenId))))
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetTokenURI",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpTokenId", string(lastTokenId),
		"tokenURI", string(tokenURI),
	)
}

// Mint creates a new NFT and assigns it to the specified address (only callable by owner)
// Parameters:
//   - to: The address or username to mint the token to
//   - tid: The token ID to assign to the new NFT
//
// Returns:
//   - grc721.TokenID: The ID of the newly minted token
func Mint(cur realm, to std.Address, tid grc721.TokenID) grc721.TokenID {
	halt.AssertIsNotHaltedPosition()
	owner.AssertOwnedByPrevious()

	checkErr(nft.Mint(to, tid))

	appendTokenList(to, tid)
	return tid
}

// Exists checks if a token ID exists.
//
// Input:
//   - tid: the token ID to check
//
// Output:
//   - bool: true if the token ID exists, false otherwise
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

	ownerAddr, err := OwnerOf(tid)
	if err != nil {
		panic(err.Error())
	}
	removeTokenList(ownerAddr, tid)

	checkErr(nft.Burn(tid))
}

// Render returns the HTML representation of the NFT
// Parameters:
//   - path: The path to render
//
// Returns:
//   - string: HTML representation of the NFT or 404 if path is invalid
func Render(cur realm, path string) string {
	switch {
	case path == "":
		return nft.RenderHome()
	default:
		return "404\n"
	}
}

// setTokenURI sets the metadata URI for a specific token ID
func setTokenURI(cur realm, tid grc721.TokenID, tURI grc721.TokenURI) error {
	uri, _ := nft.TokenURI(tid)
	if string(uri) != "" {
		return makeErrorWithDetails(errCannotSetURI, ufmt.Sprintf("token id (%s)", tid))
	}

	_, err := nft.SetTokenURI(tid, tURI)
	if err != nil {
		return makeErrorWithDetails(err, ufmt.Sprintf("token id (%s)", tid))
	}

	return nil
}

// getTokenList retrieves the list of nft tokens for an address
// Parameters:
//   - addr: The address to check for nft tokens
//
// Returns:
//   - []grc721.TokenID: Array of token IDs
//   - bool: true if tokens exist for the address, false otherwise
func getTokenList(addr std.Address) ([]grc721.TokenID, bool) {
	iTokens, exists := tokenList.Get(addr.String())
	if !exists {
		return []grc721.TokenID{}, false
	}

	return iTokens.([]grc721.TokenID), true
}

// mustGetTokenList same as getTokenList but panics if tokens don't exist
// Parameters:
//   - addr: The address to check for nft tokens
//
// Returns:
//   - []grc721.TokenID: Array of token IDs
func mustGetTokenList(addr std.Address) []grc721.TokenID {
	tokens, exists := getTokenList(addr)
	if !exists {
		panic(ufmt.Sprintf("user %s has no minted nft tokens", addr.String()))
	}

	return tokens
}

// appendTokenList adds a token ID to the list of nft tokens
// Parameters:
//   - addr: The address to append the token for
//   - tid: The token ID to append
func appendTokenList(addr std.Address, tid grc721.TokenID) {
	prevTokenList, _ := getTokenList(addr)
	prevTokenList = append(prevTokenList, tid)
	tokenList.Set(addr.String(), prevTokenList)
}

// removeTokenList removes a token ID from the list of nft tokens
// Parameters:
//   - addr: The address to remove the token for
//   - tid: The token ID to remove
func removeTokenList(addr std.Address, tid grc721.TokenID) {
	prevTokenList, exist := getTokenList(addr)
	if !exist {
		return
	}

	for i, token := range prevTokenList {
		if token == tid {
			prevTokenList = append(prevTokenList[:i], prevTokenList[i+1:]...)
			break
		}
	}

	tokenList.Set(addr.String(), prevTokenList)
}
