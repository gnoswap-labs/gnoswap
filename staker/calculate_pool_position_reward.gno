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

func isAbleToCalculateEmissionReward(prev int64, current int64) bool {
	if prev >= current {
		return false
	}
	return true
}

type Reward struct {
	Internal uint64
	InternalPenalty uint64
	External map[string]uint64
	ExternalPenalty map[string]uint64
}

func calcPositionRewardByWarmups(currentHeight uint64, tokenId uint64) []Reward {
	deposit := deposits.Get(tokenId)
	emissionUpdateHeights, emissionUpdates := gns.EmissionUpdates(deposit.lastCollectHeight, currentHeight)
	internalRewards, internalPenalties, externalRewards, externalPenalties := CalcPositionReward(currentHeight, tokenId, deposits, pools, poolTier, emissionUpdateHeights, emissionUpdates)

	rewards := make([]Reward, len(internalRewards))
	for i := range internalRewards {
		rewards[i] = Reward{
			Internal: internalRewards[i],
			InternalPenalty: internalPenalties[i],
			External: externalRewards[i],
			ExternalPenalty: externalPenalties[i],
		}
	}
	return rewards
}

func calcPositionReward(currentHeight uint64, tokenId uint64) Reward {
	deposit := deposits.Get(tokenId)
	emissionUpdateHeights, emissionUpdates := gns.EmissionUpdates(deposit.lastCollectHeight, currentHeight)
	internalRewards, internalPenalties, externalRewards, externalPenalties := CalcPositionReward(currentHeight, tokenId, deposits, pools, poolTier, emissionUpdateHeights, emissionUpdates)

	
	internal := uint64(0)
	for _, reward := range internalRewards {
		internal += reward
	}

	internalPenalty := uint64(0)
	for _, penalty := range internalPenalties {
		internalPenalty += penalty
	}

	externalReward := make(map[string]uint64)
	for _, external := range externalRewards {
		for incentive, reward := range external {
			externalReward[incentive] += reward
		}
	}

	externalPenalty := make(map[string]uint64)
	for _, external := range externalPenalties {
		for incentive, penalty := range external {
			externalPenalty[incentive] += penalty
		}
	}

	return Reward{
		Internal: internal,
		InternalPenalty: internalPenalty,
		External: externalReward,
		ExternalPenalty: externalPenalty,
	}
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
