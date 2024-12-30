package staker

import (
	//"time"

	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"

	//pn "gno.land/r/gnoswap/v1/position"

	u256 "gno.land/p/gnoswap/uint256"
	i256 "gno.land/p/gnoswap/int256"
	//en "gno.land/r/gnoswap/v1/emission"
)

// Q96
var _q96 = u256.MustFromDecimal(consts.Q96)
var _iQ96 = i256.MustFromDecimal(consts.Q96)

func isAbleToCalculateEmissionReward(prev int64, current int64) bool {
	if prev >= current {
		return false
	}
	return true
}

func calcPositionReward(currentHeight uint64, tokenId uint64) ([]uint64, []uint64, []map[string]uint64, []map[string]uint64) {
	deposit := deposits.Get(tokenId)
	emissionUpdateHeights, emissionUpdates := gns.EmissionUpdates(deposit.lastCollectHeight, currentHeight)
	return CalcPositionReward(currentHeight, tokenId, deposits, pools, poolTier, emissionUpdateHeights, emissionUpdates)
}

func CalcPositionReward(currentHeight uint64, tokenId uint64, deposits *Deposits, pools *Pools, poolTier *PoolTier, emissionUpdateHeights []uint64, emissionUpdates []uint64) ([]uint64, []uint64, []map[string]uint64, []map[string]uint64) {
	// cache per-tier and per-pool rewards
	poolTier.cacheReward(currentHeight, emissionUpdateHeights, emissionUpdates)

	deposit := deposits.Get(tokenId)
	poolPath := deposit.targetPoolPath

	pool, ok := pools.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, currentHeight)
		pools.Set(poolPath, pool)
	}

	pool.cacheInternalReward(poolTier, currentHeight)
	pool.cacheExternalReward(currentHeight)

	// eligible(in-range) intervals for a position
	upperTick := pool.ticks.Get(deposit.tickUpper)
	lowerTick := pool.ticks.Get(deposit.tickLower)

	lastCollectHeight := deposit.lastCollectHeight

	initialUpperCross := upperTick.previousCross(lastCollectHeight)
	initialLowerCross := lowerTick.previousCross(lastCollectHeight)
	currentlyInRange := initialUpperCross && !initialLowerCross

	tickUpperCrosses := upperTick.crossInfo(lastCollectHeight, currentHeight)
	tickLowerCrosses := lowerTick.crossInfo(lastCollectHeight, currentHeight)

	internalRewards, internalPenalties := pool.InternalRewardOf(deposit).Calculate(int64(lastCollectHeight), int64(currentHeight), currentlyInRange, tickUpperCrosses, tickLowerCrosses)

	externalRewards, externalPenalties := pool.ExternalRewardOf(deposit).Calculate(int64(lastCollectHeight), int64(currentHeight), currentlyInRange, tickUpperCrosses, tickLowerCrosses)

	return internalRewards, internalPenalties, externalRewards, externalPenalties
}
