package gnft

import (
    "gno.land/p/demo/tokens/grc721"
)

// GetName returns the NFT collection name.
func GetName() string {
	return nft.Name()
}

// GetSymbol returns the NFT symbol.
func GetSymbol() string {
	return nft.Symbol()
}

// GetTotalSupply returns the total number of NFTs minted.
func GetTotalSupply() int64 {
	return nft.TokenCount()
}

// GetBalanceOf returns the number of NFTs owned by the specified address.
func GetBalanceOf(addr address) (int64, error) {
	if !addr.IsValid() {
		return 0, errInvalidAddress
	}
	return nft.BalanceOf(addr)
}

// Owner returns the owner address of the contract.
func GetOwner() address {
	return owner.Owner()
}

// GetOwnerOf returns the owner address of the specified NFT.
func GetOwnerOf(id uint64) (address, error) {
    return nft.OwnerOf(tid(id))
}

// GetApproved returns approved address for token ID.
//
// Parameters:
//   - tid: token ID to check
//
// Returns approved address and error if token doesn't exist.
func GetApproved(tid grc721.TokenID) (address, error) {
	return nft.GetApproved(tid)
}

// IsApprovedForAll checks if operator can manage all owner's tokens.
//
// Parameters:
//   - owner: token owner address
//   - operator: operator address to check
//
// Returns true if operator is approved for all owner's tokens.
func IsApprovedForAll(owner, operator address) bool {
	return nft.IsApprovedForAll(owner, operator)
}
