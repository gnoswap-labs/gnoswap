package staker

import (
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/pool"
)

type PoolAccessor interface {
	ExistsPoolPath(poolPath string) bool
	GetSlot0Tick(poolPath string) int32
	GetSlot0SqrtPriceX96(poolPath string) *u256.Uint

	SetTickCrossHook(hook func(poolPath string, tickId int32, zeroForOne bool, timestamp int64))
	SetSwapStartHook(hook func(poolPath string, timestamp int64))
	SetSwapEndHook(hook func(poolPath string) error)
}

type poolAccessor struct{}

func (p *poolAccessor) ExistsPoolPath(poolPath string) bool {
	return pool.ExistsPoolPath(poolPath)
}

func (p *poolAccessor) GetSlot0Tick(poolPath string) int32 {
	return pool.GetSlot0Tick(poolPath)
}

func (p *poolAccessor) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return pool.GetSlot0SqrtPriceX96(poolPath)
}

func (p *poolAccessor) SetTickCrossHook(hook func(poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	pool.SetTickCrossHook(cross, func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
		hook(poolPath, tickId, zeroForOne, timestamp)
	})
}

func (p *poolAccessor) SetSwapStartHook(hook func(poolPath string, timestamp int64)) {
	pool.SetSwapStartHook(cross, func(cur realm, poolPath string, timestamp int64) {
		hook(poolPath, timestamp)
	})
}

func (p *poolAccessor) SetSwapEndHook(hook func(poolPath string) error) {
	pool.SetSwapEndHook(cross, func(cur realm, poolPath string) error {
		return hook(poolPath)
	})
}

func newPoolAccessor() PoolAccessor {
	return &poolAccessor{}
}

type EmissionAccessor interface {
	MintAndDistributeGns() (int64, bool)
	GetStakerEmissionAmountPerSecond() int64
	GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64)
	SetOnDistributionPctChangeCallback(callback func(emissionAmountPerSecond int64))
}

type emissionAccessor struct{}

func (e *emissionAccessor) MintAndDistributeGns() (int64, bool) {
	var amount int64
	var ok bool
	func(cur realm) {
		amount, ok = emission.MintAndDistributeGns(cross)
	}(cross)
	return amount, ok
}

func (e *emissionAccessor) GetStakerEmissionAmountPerSecond() int64 {
	return emission.GetStakerEmissionAmountPerSecond()
}

func (e *emissionAccessor) GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64) {
	return emission.GetStakerEmissionAmountPerSecondInRange(start, end)
}

func (e *emissionAccessor) SetOnDistributionPctChangeCallback(callback func(emissionAmountPerSecond int64)) {
	callbackWithCross := func(emissionAmountPerSecond int64) {
		func(cur realm) {
			callback(emissionAmountPerSecond)
		}(cross)
	}

	func(cur realm) {
		emission.SetOnDistributionPctChangeCallback(cross, callbackWithCross)
	}(cross)
}

func newEmissionAccessor() EmissionAccessor {
	return &emissionAccessor{}
}

type NFTAccessor interface {
	Approve(approved address, tid grc721.TokenID) error
	Mint(to address, tid grc721.TokenID) grc721.TokenID
	Burn(tid grc721.TokenID)
	TransferFrom(from, to address, tid grc721.TokenID) error
	TotalSupply() int64
	Exists(tid grc721.TokenID) bool
	MustOwnerOf(tid grc721.TokenID) address
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

func (n *gnftAccessor) TransferFrom(from, to address, tid grc721.TokenID) error {
	return gnft.TransferFrom(cross, from, to, tid)
}

func (n *gnftAccessor) TotalSupply() int64 {
	return gnft.TotalSupply()
}

func (n *gnftAccessor) Exists(tid grc721.TokenID) bool {
	return gnft.Exists(tid)
}

func (n *gnftAccessor) MustOwnerOf(tid grc721.TokenID) address {
	return gnft.MustOwnerOf(tid)
}

func (n *gnftAccessor) OwnerOf(tid grc721.TokenID) (address, error) {
	return gnft.OwnerOf(tid)
}

func newNFTAccessor() NFTAccessor {
	return &gnftAccessor{}
}
