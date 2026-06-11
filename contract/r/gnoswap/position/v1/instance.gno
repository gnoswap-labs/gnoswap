package v1

import (
	"gno.land/p/gnoswap/deps/grc721"
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
	Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error
	Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID
	Burn(_ int, rlm realm, tid grc721.TokenID)
	TotalSupply() int64
	Exists(tid grc721.TokenID) bool
	OwnerOf(tid grc721.TokenID) (address, error)
}

type gnftAccessor struct{}

func (n *gnftAccessor) Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error {
	if !rlm.IsCurrent() {
		return errSpoofedRealm
	}

	return gnft.Approve(cross(rlm), approved, tid)
}

func (n *gnftAccessor) Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	return gnft.Mint(cross(rlm), to, tid)
}

func (n *gnftAccessor) Burn(_ int, rlm realm, tid grc721.TokenID) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	gnft.Burn(cross(rlm), tid)
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
