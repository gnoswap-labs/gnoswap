package v1

import (
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/pool"
	sr "gno.land/r/gnoswap/staker"
)

type mockPoolAccessor struct{}

func (p *mockPoolAccessor) SetTickCrossHook(hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	func(cur realm) {
		pool.SetTickCrossHook(cross, hook)
	}(cross)
}

func (p *mockPoolAccessor) SetSwapStartHook(hook func(cur realm, poolPath string, timestamp int64)) {
	func(cur realm) {
		pool.SetSwapStartHook(cross, hook)
	}(cross)
}

func (p *mockPoolAccessor) SetSwapEndHook(hook func(cur realm, poolPath string) error) {
	func(cur realm) {
		pool.SetSwapEndHook(cross, hook)
	}(cross)
}

func newMockPoolAccessor() sr.PoolAccessor {
	return &mockPoolAccessor{}
}

type mockEmissionAccessor struct{}

func (e *mockEmissionAccessor) MintAndDistributeGns() {
	func(cur realm) {
		emission.MintAndDistributeGns(cross)
	}(cross)
}

func (e *mockEmissionAccessor) GetStakerEmissionAmountPerSecond() int64 {
	return emission.GetStakerEmissionAmountPerSecond()
}

func (e *mockEmissionAccessor) GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64) {
	return emission.GetStakerEmissionAmountPerSecondInRange(start, end)
}

func (e *mockEmissionAccessor) SetOnDistributionPctChangeCallback(callback func(emissionAmountPerSecond int64)) {
	func(cur realm) {
		emission.SetOnDistributionPctChangeCallback(cross, callback)
	}(cross)
}

func newMockEmissionAccessor() sr.EmissionAccessor {
	return &mockEmissionAccessor{}
}
