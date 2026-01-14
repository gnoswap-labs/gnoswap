package v2

import (
	"gno.land/p/demo/tokens/grc721"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/position"
)

type positionV1 struct {
	store       position.IPositionStore
	nftAccessor NFTAccessor
}

func NewPositionV1(positionStore position.IPositionStore, accessor NFTAccessor) position.IPosition {
	return &positionV1{
		store:       positionStore,
		nftAccessor: accessor,
	}
}

type NFTAccessor interface {
	Approve(approved address, tid grc721.TokenID) error
	Mint(to address, tid grc721.TokenID) grc721.TokenID
	Burn(tid grc721.TokenID)
	TotalSupply() int64
	Exists(tid grc721.TokenID) bool
	OwnerOf(tid grc721.TokenID) (address, error)
}

type gnftAccessor struct{}

func (n *gnftAccessor) Approve(approved address, tid grc721.TokenID) error {
	return gnft.Approve(cross, approved, tid)
}

func (n *gnftAccessor) Mint(to address, tid grc721.TokenID) grc721.TokenID {
	return gnft.Mint(cross, to, tid)
}

func (n *gnftAccessor) Burn(tid grc721.TokenID) {
	gnft.Burn(cross, tid)
}

func (n *gnftAccessor) TotalSupply() int64 {
	return gnft.TotalSupply()
}

func (n *gnftAccessor) Exists(tid grc721.TokenID) bool {
	return gnft.Exists(tid)
}

func (n *gnftAccessor) OwnerOf(tid grc721.TokenID) (address, error) {
	return gnft.OwnerOf(tid)
}

func newGNFTAccessor() NFTAccessor {
	return &gnftAccessor{}
}
