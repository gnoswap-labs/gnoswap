package staker

import (
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/pool"
)

type PoolAccessor interface {
	SetTickCrossHook(hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64))
	SetSwapStartHook(hook func(cur realm, poolPath string, timestamp int64))
	SetSwapEndHook(hook func(cur realm, poolPath string) error)
}

type poolAccessor struct{}

func (p *poolAccessor) SetTickCrossHook(hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	func(cur realm) {
		pool.SetTickCrossHook(cross, hook)
	}(cross)
}

func (p *poolAccessor) SetSwapStartHook(hook func(cur realm, poolPath string, timestamp int64)) {
	func(cur realm) {
		pool.SetSwapStartHook(cross, hook)
	}(cross)
}

func (p *poolAccessor) SetSwapEndHook(hook func(cur realm, poolPath string) error) {
	func(cur realm) {
		pool.SetSwapEndHook(cross, hook)
	}(cross)
}

func newPoolAccessor() PoolAccessor {
	return &poolAccessor{}
}

type EmissionAccessor interface {
	MintAndDistributeGns()
	GetStakerEmissionAmountPerSecond() int64
	GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64)
	SetOnDistributionPctChangeCallback(callback func(emissionAmountPerSecond int64))
}

type emissionAccessor struct{}

func (e *emissionAccessor) MintAndDistributeGns() {
	func(cur realm) {
		emission.MintAndDistributeGns(cross)
	}(cross)
}

func (e *emissionAccessor) GetStakerEmissionAmountPerSecond() int64 {
	return emission.GetStakerEmissionAmountPerSecond()
}

func (e *emissionAccessor) GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64) {
	return emission.GetStakerEmissionAmountPerSecondInRange(start, end)
}

func (e *emissionAccessor) SetOnDistributionPctChangeCallback(callback func(emissionAmountPerSecond int64)) {
	func(cur realm) {
		emission.SetOnDistributionPctChangeCallback(cross, callback)
	}(cross)
}

func newEmissionAccessor() EmissionAccessor {
	return &emissionAccessor{}
}
