package gnft

import (
	"math/rand"
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/users"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

var (
	gnft = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
)

var (
	owner     *ownable.Ownable
	tokenList *avl.Tree // addr -> []grc721.TokenID
)

func init() {
	owner = ownable.NewWithAddress(consts.POSITION_ADDR) // deployed position contract
	tokenList = avl.NewTree()
}

// Name returns the full name of the NFT
// Returns:
//   - string: The name of the NFT collection
func Name() string {
	return gnft.Name()
}

// Symbol returns the token symbol of the NFT
// Returns:
//   - string: The symbol of the NFT collection
func Symbol() string {
	return gnft.Symbol()
}

// TotalSupply returns the total number of NFTs minted
// Returns:
//   - uint64: The total number of tokens that have been minted
func TotalSupply() uint64 {
	return gnft.TokenCount()
}

// TokenURI retrieves the metadata URI for a specific token ID
// Parameters:
//   - tid: The unique identifier of the token
//
// Returns:
//   - string: The metadata URI associated with the token
func TokenURI(tid grc721.TokenID) string {
	uri, err := gnft.TokenURI(tid)
	if err != nil {
		panic(err.Error())
	}

	return string(uri)
}

// BalanceOf returns how many NFTs are owned by the specified address
// Parameters:
//   - user: The address or username to check the balance for
//
// Returns:
//   - uint64: The number of tokens owned by the address
func BalanceOf(user pusers.AddressOrName) uint64 {
	balance, err := gnft.BalanceOf(users.Resolve(user))
	if err != nil {
		panic(err.Error())
	}

	return balance
}

// OwnerOf returns the current owner's address of a specific token ID
// Parameters:
//   - tid: The token ID to check ownership of
//
// Returns:
//   - std.Address: The address of the token owner
func OwnerOf(tid grc721.TokenID) std.Address {
	owner, err := gnft.OwnerOf(tid)
	checkErr(err)

	return owner
}

// IsApprovedForAll checks if an operator is approved to manage all tokens of an owner
// Parameters:
//   - owner: The address or username of the token owner
//   - user: The address or username to check approval for
//
// Returns:
//   - bool: true if the user is approved to manage all tokens, false otherwise
func IsApprovedForAll(owner, user pusers.AddressOrName) bool {
	return gnft.IsApprovedForAll(users.Resolve(owner), users.Resolve(user))
}

// GetApproved returns the approved address for a specific token ID
// Parameters:
//   - tid: The token ID to check approval for
//
// Returns:
//   - std.Address: The approved address for the token
//   - bool: true if an address is approved, false otherwise
func GetApproved(tid grc721.TokenID) (std.Address, bool) {
	addr, err := gnft.GetApproved(tid)
	if err != nil {
		return "", false
	}

	return addr, true
}

// Approve grants permission to transfer a specific token ID to another address
// Parameters:
//   - user: The address or username to grant approval to
//   - tid: The token ID to approve
func Approve(user pusers.AddressOrName, tid grc721.TokenID) {
	common.IsHalted()
	assertCallerIsOwnerOfToken(tid)

	err := gnft.Approve(users.Resolve(user), tid)
	if err != nil {
		panic(err.Error())
	}
}

// SetApprovalForAll enables or disables approval for a third party to manage all tokens
// Parameters:
//   - user: The address or username to set approval for
//   - approved: true to approve, false to revoke approval
func SetApprovalForAll(user pusers.AddressOrName, approved bool) {
	common.IsHalted()
	checkErr(gnft.SetApprovalForAll(users.Resolve(user), approved))
}

// TransferFrom transfers ownership of a token from one address to another
// Parameters:
//   - from: The current owner's address or username
//   - to: The recipient's address or username
//   - tid: The token ID to transfer
func TransferFrom(from, to pusers.AddressOrName, tid grc721.TokenID) {
	common.IsHalted()

	caller := getPrevAddr()
	ownerOf := OwnerOf(tid)
	_, approved := GetApproved(tid)

	if caller != ownerOf && !approved {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("caller (%s) is not the owner or operator of token (%s)", caller, string(tid)),
		))
	}

	removeTokenList(users.Resolve(from), tid)
	appendTokenList(users.Resolve(to), tid)

	checkErr(gnft.TransferFrom(users.Resolve(from), users.Resolve(to), tid))
}

// Mint creates a new NFT and assigns it to the specified address (only callable by owner)
// Parameters:
//   - to: The address or username to mint the token to
//   - tid: The token ID to assign to the new NFT
//
// Returns:
//   - grc721.TokenID: The ID of the newly minted token
func Mint(to pusers.AddressOrName, tid grc721.TokenID) grc721.TokenID {
	owner.AssertCallerIsOwner()
	common.IsHalted()

	toAddr := users.Resolve(to)
	checkErr(gnft.Mint(toAddr, tid))

	appendTokenList(toAddr, tid)
	return tid
}

// Burn removes a specific token ID (only callable by owner)
// Parameters:
//   - tid: The token ID to burn
func Burn(tid grc721.TokenID) {
	owner.AssertCallerIsOwner()
	common.IsHalted()

	removeTokenList(OwnerOf(tid), tid)
	checkErr(gnft.Burn(tid))
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
		return gnft.RenderHome()
	default:
		return "404\n"
	}
}

// SetTokenURI sets the metadata URI using a randomly generated SVG image
// Parameters:
//   - tid: The token ID to set the URI for
func SetTokenURI(tid grc721.TokenID) {
	common.IsHalted()

	assertCallerIsOwnerOfToken(tid)

	err := setTokenURI(tid)
	if err != nil {
		panic(addDetailToError(
			errCannotSetURI,
			ufmt.Sprintf("token id (%s)", tid),
		))
	}
}

// SetTokenURILast sets metadata URI for last minted nft token
func SetTokenURILast() {
	common.IsHalted()

	caller := getPrevAddr()
	tokenListByCaller, _ := getTokenList(caller)
	lenTokenListByCaller := len(tokenListByCaller)
	if lenTokenListByCaller == 0 {
		panic(addDetailToError(
			errNoTokenForCaller,
			ufmt.Sprintf("caller (%s)", caller),
		))
	}

	lastTokenId := tokenListByCaller[lenTokenListByCaller-1]
	err := setTokenURI(lastTokenId)
	if err != nil {
		panic(addDetailToError(
			errCannotSetURI,
			ufmt.Sprintf("token id (%s)", lastTokenId),
		))
	}
}

func setTokenURI(tid grc721.TokenID) error {
	tokenURI := genImageURI(generateRandInstance())

	_, err := gnft.SetTokenURI(tid, grc721.TokenURI(tokenURI))
	if err != nil {
		return err
	}

	prevAddr, prevPkgPath := getPrevAsString()
	std.Emit(
		"SetTokenURI",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"lpTokenId", string(tid),
		"internal_tokenURI", tokenURI,
	)

	return nil
}

// generateRandInstnace generates a new random instance
// Returns:
//   - *rand.Rand: A new random instance
func generateRandInstance() *rand.Rand {
	seed1 := uint64(time.Now().Unix()) + TotalSupply()
	seed2 := uint64(time.Now().UnixNano()) + TotalSupply()
	pcg := rand.NewPCG(seed1, seed2)
	return rand.New(pcg)
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

// checkErr helper function to panic if an error occurs
// Parameters:
//   - err: The error to check
func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}

func assertCallerIsOwnerOfToken(tid grc721.TokenID) {
	caller := getPrevAddr()
	owner := OwnerOf(tid)
	if caller != owner {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("caller (%s) is not the owner of token (%s)", caller, string(tid)),
		))
	}
}
