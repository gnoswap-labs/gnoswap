package position

import (
	"errors"

	"gno.land/p/nt/grc721/v0"
	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/position"
)

type positionV1 struct {
	store       position.IPositionStore
	nftAccessor NFTAccessor
}

// NewPositionV1 constructs a position implementation backed by the supplied
// position store and NFT accessor.
//
// Parameters:
//   - positionStore: storage interface used to read and update position records
//   - accessor: NFT interface used for position token minting, burning, approval, and ownership
//
// Returns:
//   - position: IPosition implementation connected to positionStore and accessor
func NewPositionV1(positionStore position.IPositionStore, accessor NFTAccessor) position.IPosition {
	return &positionV1{
		store:       positionStore,
		nftAccessor: accessor,
	}
}

type NFTAccessor interface {
	// Approve forwards an operator approval for a position NFT.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the forwarded NFT operation; callers pass 0
	//   - rlm: propagated realm context validated by the concrete accessor before crossing into the NFT realm
	//   - approved: address to approve for the specified position NFT; the empty address revokes approval
	//   - tid: position NFT token ID whose operator approval is changed
	//
	// Returns:
	//   - err: nil when approval succeeds; otherwise the NFT accessor or realm-validation error
	Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error
	// Mint creates a position NFT for an address and token ID.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the forwarded NFT operation; callers pass 0
	//   - rlm: propagated realm context used to cross into the NFT realm
	//   - to: address that receives the newly minted position NFT
	//   - tid: requested position NFT token ID
	//
	// Returns:
	//   - mintedTid: token ID returned by the NFT realm after minting
	Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID
	// Burn removes a position NFT from the NFT ledger.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the forwarded NFT operation; callers pass 0
	//   - rlm: propagated realm context used to cross into the NFT realm
	//   - tid: position NFT token ID to burn
	Burn(_ int, rlm realm, tid grc721.TokenID)
	// TotalSupply returns the number of NFTs currently recorded by the ledger.
	//
	// Returns:
	//   - totalSupply: current number of position NFTs in the ledger
	TotalSupply() int64
	// Exists reports whether the NFT ledger contains a token ID.
	//
	// Parameters:
	//   - tid: position NFT token ID to test
	//
	// Returns:
	//   - exists: true when the NFT ledger contains tid
	Exists(tid grc721.TokenID) bool
	// OwnerOf returns the current owner of a position NFT.
	//
	// Parameters:
	//   - tid: position NFT token ID whose owner is requested
	//
	// Returns:
	//   - owner: address recorded as the token owner
	//   - err: nil when the token exists; otherwise the NFT ledger's ownership lookup error
	OwnerOf(tid grc721.TokenID) (address, error)
}

type gnftAccessor struct{}

// Approve forwards an operator approval to the GNFT realm.
//
// Parameters:
//   - _: leading realm-call discriminator for the forwarded NFT operation; callers pass 0
//   - rlm: propagated realm context that must be current before crossing into GNFT
//   - approved: address to approve for the specified position NFT; the empty address revokes approval
//   - tid: position NFT token ID whose operator approval is changed
//
// Returns:
//   - err: nil when GNFT accepts the approval; errSpoofedRealm when rlm is not current, otherwise the underlying GNFT error
func (n *gnftAccessor) Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return gnft.Approve(cross(rlm), approved, tid)
}

// Mint forwards position NFT creation to the GNFT realm.
//
// Parameters:
//   - _: leading realm-call discriminator for the forwarded NFT operation; callers pass 0
//   - rlm: propagated realm context asserted current before crossing into GNFT
//   - to: address that receives the newly minted position NFT
//   - tid: requested position NFT token ID
//
// Returns:
//   - mintedTid: token ID returned by GNFT after minting
func (n *gnftAccessor) Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID {
	access.AssertIsRlmCurrent(0, rlm)

	return gnft.Mint(cross(rlm), to, tid)
}

// Burn forwards position NFT destruction to the GNFT realm.
//
// Parameters:
//   - _: leading realm-call discriminator for the forwarded NFT operation; callers pass 0
//   - rlm: propagated realm context asserted current before crossing into GNFT
//   - tid: position NFT token ID to burn
func (n *gnftAccessor) Burn(_ int, rlm realm, tid grc721.TokenID) {
	access.AssertIsRlmCurrent(0, rlm)

	gnft.Burn(cross(rlm), tid)
}

// TotalSupply returns the GNFT ledger's current token count.
//
// Returns:
//   - totalSupply: number of NFTs currently recorded by GNFT
func (n *gnftAccessor) TotalSupply() int64 {
	return gnft.TotalSupply()
}

// Exists reports whether GNFT contains a position NFT token ID.
//
// Parameters:
//   - tid: position NFT token ID to test
//
// Returns:
//   - exists: true when GNFT contains tid
func (n *gnftAccessor) Exists(tid grc721.TokenID) bool {
	return gnft.Exists(tid)
}

// OwnerOf returns the owner recorded by GNFT for a position NFT.
//
// Parameters:
//   - tid: position NFT token ID whose owner is requested
//
// Returns:
//   - owner: address recorded as the token owner
//   - err: nil when GNFT finds the token; otherwise GNFT's ownership lookup error
func (n *gnftAccessor) OwnerOf(tid grc721.TokenID) (address, error) {
	return gnft.OwnerOf(tid)
}

func newGNFTAccessor() NFTAccessor {
	return &gnftAccessor{}
}
