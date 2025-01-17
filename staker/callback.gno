package staker

import (
	"std"

	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
)

func CreateCallbackStakerEmissionChange(pt *PoolTier, pools *Pools) func(uint64) {
	return func(emission uint64) {
		pt.cacheReward(std.GetHeight(), pools)
		pt.currentEmission = emission
	}
}
