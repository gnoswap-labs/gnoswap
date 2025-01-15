package staker

import (
	"std"

	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
)

func CreateStakerDistributionCallback(pt *PoolTier) (en.LiquidityStakerDistributionPctChangeCallback, error) {
	return func(pct uint64) {
		// caching the reward
		// pt.cacheReward(uint64(std.GetHeight()), pools)
		currentHeight := uint64(std.GetHeight())

		// update the current emission
		newEmission := gns.GetCurrentEmission()
		pt.cacheReward(currentHeight, pools)
		pt.currentEmission = newEmission
	}, nil
}
