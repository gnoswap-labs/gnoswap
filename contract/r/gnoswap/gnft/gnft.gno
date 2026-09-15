package gnft

import (
	"chain"
	"errors"

	"gno.land/p/nt/grc721/metadata/v0"
	"gno.land/p/nt/grc721/v0"
	"gno.land/p/nt/seqid/v0"
	"gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"
)

var (
	token      *grc721.Token
	ledger     *grc721.PrivateLedger
	meta       *metadata.Metadata
	metaLedger *metadata.Ledger
)

func init(cur realm) {
	token, ledger = grc721.NewToken("GNOSWAP NFT", "GNFT", seqid.ID(0), cur)
	meta, metaLedger = metadata.NewMetadata(ledger)
}

// Name returns the NFT collection name.
//
// Returns:
//   - name: collection name
func Name() string {
	return token.GetName()
}

// Symbol returns the NFT collection symbol.
//
// Returns:
//   - symbol: collection symbol
func Symbol() string {
	return token.GetSymbol()
}

// TotalSupply returns the total number of NFTs minted.
//
// Returns:
//   - supply: number of NFTs minted by the collection
func TotalSupply() int64 {
	return token.TotalSupply()
}

// TokenURI returns the metadata URI for the specified token ID.
// Parameter-format values (x1,y1,x2,y2,color1,color2) are rendered as a
// base64-encoded SVG data URI; other non-empty stored URIs are returned unchanged.
//
// Parameters:
//   - tid: token ID whose metadata URI is requested
//
// Returns:
//   - uri: stored URI, or a generated SVG data URI for parameter-format metadata
//   - error: metadata lookup error when tid has no retrievable metadata
func TokenURI(tid grc721.TokenID) (string, error) {
	stored, err := meta.TokenURI(tid)
	if err != nil {
		return "", err
	}

	params, err := parseImageParams(stored)
	if err == nil {
		return params.generateImageURI(tid), nil
	}

	return stored, nil
}

// BalanceOf returns the number of NFTs owned by the specified address.
//
// Parameters:
//   - owner: address whose NFT balance is queried
//
// Returns:
//   - balance: number of NFTs owned by owner
//   - error: token-ledger balance lookup error; an invalid owner address
//     panics before the lookup
func BalanceOf(owner address) (int64, error) {
	assertIsValidAddress(owner)
	return token.BalanceOf(owner)
}

// OwnerOf returns the owner address for the specified token ID.
//
// Parameters:
//   - tid: token ID whose owner is requested
//
// Returns:
//   - owner: current owner address
//   - error: token-ledger error when tid does not exist or cannot be read
func OwnerOf(tid grc721.TokenID) (address, error) {
	return token.OwnerOf(tid)
}

// MustOwnerOf returns the owner address for the specified token ID.
// It panics if the token ID is invalid.
//
// Parameters:
//   - tid: token ID whose owner is requested
//
// Returns:
//   - owner: current owner address; panics when tid is invalid or absent
func MustOwnerOf(tid grc721.TokenID) address {
	ownerAddr, err := token.OwnerOf(tid)
	checkErr(err)
	return ownerAddr
}

// SetTokenURI sets the metadata URI for the specified token.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - tid: token ID whose metadata URI is replaced
//   - tURI: non-empty metadata URI or parameter-format image description
//
// Returns:
//   - updated: true after the URI is stored and re-read successfully
//   - error: nil on success; validation and storage failures panic before a
//     non-nil error can be returned
//
// Only callable by position contract.
func SetTokenURI(cur realm, tid grc721.TokenID, tURI string) (bool, error) {
	caller := cur.Previous().Address()
	access.AssertIsPosition(caller)

	assertIsNonEmptyTokenURI(tURI)
	assertIsValidTokenURI(tid)

	checkErr(setTokenURI(0, cur, tid, tURI))

	return true, nil
}

// TransferFrom transfers a token from one address to another.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - from: current owner address
//   - to: recipient address
//   - tid: token ID to transfer
//
// Returns:
//   - error: nil after a successful transfer; invalid addresses, authorization,
//     ownership, or ledger failures panic through checkTransferErr
//
// Permission model:
//   - Tokens held by the staker contract (i.e. currently staked) can only be
//     moved by the staker itself; the underlying staked LP position is
//     non-transferable.
//   - Otherwise, ownership and approval are enforced by the GRC721 layer
//     (owner / approved-for-token / approved-for-all).
func TransferFrom(cur realm, from, to address, tid grc721.TokenID) error {
	assertFromIsValidAddress(from)
	assertToIsValidAddress(to)
	caller := cur.Previous().Address()
	assertIsAllowedTransfer(caller, tid)

	err := ledger.TransferFrom(caller, from, to, tid)
	checkTransferErr(err, caller, from, to, tid)
	return nil
}

// Approve grants permission to transfer a specific token ID to another address.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - approved: address to approve
//   - tid: token ID to approve for transfer
//
// Returns:
//   - error: nil after approval is stored; invalid addresses, ownership, or
//     ledger failures panic through checkApproveErr
func Approve(cur realm, approved address, tid grc721.TokenID) error {
	assertIsValidAddress(approved)

	caller := cur.Previous().Address()
	err := ledger.Approve(caller, approved, tid)
	checkApproveErr(err, caller, approved, tid)
	return nil
}

// SetApprovalForAll enables/disables operator approval for all tokens.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - operator: address to set approval for
//   - approved: true to approve, false to revoke
//
// Returns:
//   - error: nil after the operator approval is stored; ledger failures panic
//     before a non-nil error can be returned
func SetApprovalForAll(cur realm, operator address, approved bool) error {
	assertIsValidAddress(operator)

	checkErr(ledger.SetApprovalForAll(cur.Previous().Address(), operator, approved))
	return nil
}

// GetApproved returns approved address for token ID.
//
// Parameters:
//   - tid: token ID whose per-token approval is requested
//
// Returns:
//   - approved: address approved for tid
//   - error: token-ledger error if tid does not exist or approval cannot be read
func GetApproved(tid grc721.TokenID) (address, error) {
	return token.GetApproved(tid)
}

// IsApprovedForAll checks if operator can manage all owner's tokens.
//
// Parameters:
//   - owner: token owner address
//   - operator: operator address to check
//
// Returns:
//   - approved: true when operator is approved for every token owned by owner
func IsApprovedForAll(owner, operator address) bool {
	return token.IsApprovedForAll(owner, operator)
}

// Mint creates new NFT and transfers it to to.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - to: recipient address
//   - tid: token ID to mint
//
// Returns:
//   - tokenID: minted token ID
//
// Only callable by position contract.
func Mint(cur realm, to address, tid grc721.TokenID) grc721.TokenID {
	caller := cur.Previous().Address()
	access.AssertIsPosition(caller)

	positionAddr := access.MustGetAddress(prabc.ROLE_POSITION.String())
	checkErr(ledger.Mint(positionAddr, tid))

	// Store only the gradient parameters instead of full base64 SVG to reduce storage costs.
	// Parameters are converted to full SVG on read via TokenURI().
	imageParams := genImageParamsString(generateRandInstance())
	checkErr(setTokenURI(0, cur, tid, imageParams))

	checkErr(ledger.TransferFrom(positionAddr, positionAddr, to, tid))

	return tid
}

// Exists checks if token ID exists.
//
// Parameters:
//   - tid: token ID to check
//
// Returns:
//   - exists: true when the ledger can resolve an owner for tid; false otherwise
func Exists(tid grc721.TokenID) bool {
	_, err := token.OwnerOf(tid)
	return err == nil
}

// Burn removes a specific token ID.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - tid: token ID to burn
//
// Only callable by position.
func Burn(cur realm, tid grc721.TokenID) {
	caller := cur.Previous().Address()
	access.AssertIsPosition(caller)

	checkErr(ledger.Burn(tid))
}

// Render returns the HTML representation of the NFT.
//
// Parameters:
//   - path: render path; the empty path selects the collection home page
//
// Returns:
//   - html: collection HTML for the home path, or "404\n" for unsupported paths
func Render(path string) string {
	if path == "" {
		return token.RenderHome()
	}
	return "404\n"
}

// setTokenURI sets the metadata URI for a specific token ID.
func setTokenURI(_ int, rlm realm, tid grc721.TokenID, tURI string) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	previousRealm := rlm.Previous()
	previousAddr := previousRealm.Address()

	err := metaLedger.SetTokenURI(tid, tURI)
	if err != nil {
		return makeErrorWithDetails(err.Error(), ufmt.Sprintf("token id (%s)", tid))
	}
	tokenURI, err := TokenURI(tid)
	if err != nil {
		return makeErrorWithDetails(err.Error(), ufmt.Sprintf("token id (%s)", tid))
	}

	chain.Emit(
		"SetTokenURI",
		"prevAddr", previousAddr.String(),
		"prevRealm", previousRealm.PkgPath(),
		"tokenId", string(tid),
		"tokenURI", tokenURI,
	)

	return nil
}
