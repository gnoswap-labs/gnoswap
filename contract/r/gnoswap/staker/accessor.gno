package staker

import "gno.land/r/gnoswap/emission"

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
