package staker

import (
	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gns"
	en "gno.land/r/gnoswap/v1/emission"
	pn "gno.land/r/gnoswap/v1/position"
	pl "gno.land/r/gnoswap/v1/pool"

	u256 "gno.land/p/gnoswap/uint256"
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
	Internal        uint64
	InternalPenalty uint64
	External        map[string]uint64
	ExternalPenalty map[string]uint64
}

func calcPositionRewardByWarmups(currentHeight uint64, tokenId uint64) []Reward {
	rewards := CalcPositionReward(CalcPositionRewardParam{
		CurrentHeight: currentHeight,
		Deposits: deposits,
		Pools: pools,
		PoolTier: poolTier,
		TokenId: tokenId,
	})

	return rewards
}

func calcPositionReward(currentHeight uint64, tokenId uint64) Reward {
	rewards := CalcPositionReward(CalcPositionRewardParam{
		CurrentHeight: currentHeight,
		Deposits: deposits,
		Pools: pools,
		PoolTier: poolTier,
		TokenId: tokenId,
	})

	internal := uint64(0)
	for _, reward := range rewards {
		internal += reward.Internal
	}

	internalPenalty := uint64(0)
	for _, reward := range rewards {
		internalPenalty += reward.InternalPenalty
	}

	externalReward := make(map[string]uint64)
	for _, reward := range rewards {
		if reward.External != nil {
			for incentive, reward := range reward.External {
				externalReward[incentive] += reward
			}
		}
	}

	externalPenalty := make(map[string]uint64)
	for _, reward := range rewards {
		if reward.ExternalPenalty != nil {
			for incentive, penalty := range reward.ExternalPenalty {
				externalPenalty[incentive] += penalty
			}
		}
	}

	return Reward{
		Internal:        internal,
		InternalPenalty: internalPenalty,
		External:        externalReward,
		ExternalPenalty: externalPenalty,
	}
}

type CalcPositionRewardParam struct {
	// Environmental variables
	CurrentHeight uint64
	Deposits *Deposits
	Pools *Pools
	PoolTier *PoolTier

	// Position variables
	TokenId uint64
}



func CalcPositionReward(param CalcPositionRewardParam) []Reward {


	// cache per-pool rewards in the internal incentive(tiers)
	param.PoolTier.cacheReward(param.CurrentHeight, param.Pools)

	deposit := param.Deposits.Get(param.TokenId)
	poolPath := deposit.targetPoolPath


	pool, ok := param.Pools.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, param.CurrentHeight)
		param.Pools.Set(poolPath, pool)
	}

	// cacheInternalReward is called by poolTier.cacheReward
	pool.cacheExternalReward(param.CurrentHeight)
	// eligible(in-range) intervals for a position
	// XXX: Tick ordering code, memoing for future
	tickUpper := deposit.tickUpper
	tickLower := deposit.tickLower
	token0, token1, _ := poolPathDivide(poolPath)
	if token1 < token0 {
		tickUpper, tickLower = -tickLower, -tickUpper
	}
	upperTick := pool.ticks.Get(tickUpper)
	lowerTick := pool.ticks.Get(tickLower)
	// XXX: Tick ordering code, memoing for future

	lastCollectHeight := deposit.lastCollectHeight

	initialUpperCross := upperTick.previousCross(lastCollectHeight)
	initialLowerCross := lowerTick.previousCross(lastCollectHeight)
	currentlyInRange := initialUpperCross && !initialLowerCross

	tickUpperCrosses := upperTick.crossInfo(lastCollectHeight, param.CurrentHeight)
	tickLowerCrosses := lowerTick.crossInfo(lastCollectHeight, param.CurrentHeight)

	internalRewards, internalPenalties := pool.InternalRewardOf(deposit).Calculate(int64(lastCollectHeight), int64(param.CurrentHeight), currentlyInRange, tickUpperCrosses, tickLowerCrosses)

	externalRewards, externalPenalties := pool.ExternalRewardOf(deposit).Calculate(int64(lastCollectHeight), int64(param.CurrentHeight), currentlyInRange, tickUpperCrosses, tickLowerCrosses)

	rewards := make([]Reward, len(internalRewards))
	for i := range internalRewards {
		rewards[i] = Reward{
			Internal:        internalRewards[i],
			InternalPenalty: internalPenalties[i],
		}
		if externalRewards != nil {
			if len(externalRewards[i]) > 0 {
				rewards[i].External = externalRewards[i]
				rewards[i].ExternalPenalty = externalPenalties[i]
			}
		}
	}
	return rewards
}

func ProcessUnClaimableReward(poolPath string, endHeight uint64) (uint64, map[string]uint64) {
	pool, ok := pools.Get(poolPath)
	if !ok {
		return 0, make(map[string]uint64)
	}
	return pool.processUnclaimableReward(poolTier, endHeight)
}
