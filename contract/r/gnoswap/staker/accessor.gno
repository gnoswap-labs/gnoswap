package staker

import (
	"gno.land/p/gnoswap/deps/grc721"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/pool"
)

type PoolAccessor interface {
	ExistsPoolPath(poolPath string) bool
	GetSlot0Tick(poolPath string) int32
	GetSlot0SqrtPriceX96(poolPath string) string

	SetTickCrossHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64))
	SetSwapStartHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string, timestamp int64))
	SetSwapEndHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string) error)
}

type poolAccessor struct{}

func (p *poolAccessor) ExistsPoolPath(poolPath string) bool {
	return pool.ExistsPoolPath(poolPath)
}

func (p *poolAccessor) GetSlot0Tick(poolPath string) int32 {
	return pool.GetSlot0Tick(poolPath)
}

func (p *poolAccessor) GetSlot0SqrtPriceX96(poolPath string) string {
	return pool.GetSlot0SqrtPriceX96(poolPath)
}

func (p *poolAccessor) SetTickCrossHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	if !rlm.IsCurrent() {
		panic(ErrSpoofedRealm)
	}

	pool.SetTickCrossHook(cross(rlm), func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
		hook(0, cur, poolPath, tickId, zeroForOne, timestamp)
	})
}

func (p *poolAccessor) SetSwapStartHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string, timestamp int64)) {
	if !rlm.IsCurrent() {
		panic(ErrSpoofedRealm)
	}

	pool.SetSwapStartHook(cross(rlm), func(cur realm, poolPath string, timestamp int64) {
		hook(0, cur, poolPath, timestamp)
	})
}

func (p *poolAccessor) SetSwapEndHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string) error) {
	if !rlm.IsCurrent() {
		panic(ErrSpoofedRealm)
	}

	pool.SetSwapEndHook(cross(rlm), func(cur realm, poolPath string) error {
		return hook(0, cur, poolPath)
	})
}

func newPoolAccessor() PoolAccessor {
	return &poolAccessor{}
}

type EmissionAccessor interface {
	MintAndDistributeGns(_ int, rlm realm) (int64, bool)
	GetStakerEmissionAmountPerSecond() int64
	GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64)
	SetOnDistributionPctChangeCallback(_ int, rlm realm, callback func(_ int, rlm realm, emissionAmountPerSecond int64))
}

type emissionAccessor struct{}

func (e *emissionAccessor) MintAndDistributeGns(_ int, rlm realm) (int64, bool) {
	if !rlm.IsCurrent() {
		panic(ErrSpoofedRealm)
	}

	return emission.MintAndDistributeGns(cross(rlm))
}

func (e *emissionAccessor) GetStakerEmissionAmountPerSecond() int64 {
	return emission.GetStakerEmissionAmountPerSecond()
}

func (e *emissionAccessor) GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64) {
	return emission.GetStakerEmissionAmountPerSecondInRange(start, end)
}

func (e *emissionAccessor) SetOnDistributionPctChangeCallback(_ int, rlm realm, callback func(_ int, rlm realm, emissionAmountPerSecond int64)) {
	if !rlm.IsCurrent() {
		panic(ErrSpoofedRealm)
	}

	// Wrap the caller-provided callback in an adapter constructed HERE, inside
	// the /r/gnoswap/staker domain package. By borrow rule #3 the wrapper
	// closure is owned by /r/gnoswap/staker (its construction realm), not by the
	// v1 implementation that passed `callback` in. This mirrors the swap/tick
	// hook accessors above and lets emission persist the callback into its
	// package-level var without hitting "cannot persist realm value" (which
	// fired when a v1-constructed closure was stored there directly).
	emission.SetOnDistributionPctChangeCallback(cross(rlm), func(cur realm, emissionAmountPerSecond int64) {
		callback(0, cur, emissionAmountPerSecond)
	})
}

func newEmissionAccessor() EmissionAccessor {
	return &emissionAccessor{}
}

type NFTAccessor interface {
	Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error
	Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID
	Burn(_ int, rlm realm, tid grc721.TokenID)
	TransferFrom(_ int, rlm realm, from, to address, tid grc721.TokenID) error
	TotalSupply() int64
	Exists(tid grc721.TokenID) bool
	MustOwnerOf(tid grc721.TokenID) address
	OwnerOf(tid grc721.TokenID) (address, error)
}

type gnftAccessor struct{}

func (n *gnftAccessor) Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return gnft.Approve(cross(rlm), approved, tid)
}

func (n *gnftAccessor) Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID {
	if !rlm.IsCurrent() {
		panic(ErrSpoofedRealm)
	}

	return gnft.Mint(cross(rlm), to, tid)
}

func (n *gnftAccessor) Burn(_ int, rlm realm, tid grc721.TokenID) {
	if !rlm.IsCurrent() {
		panic(ErrSpoofedRealm)
	}

	gnft.Burn(cross(rlm), tid)
}

func (n *gnftAccessor) TransferFrom(_ int, rlm realm, from, to address, tid grc721.TokenID) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return gnft.TransferFrom(cross(rlm), from, to, tid)
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
