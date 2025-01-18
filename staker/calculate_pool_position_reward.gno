package staker

import (
	"gno.land/r/gnoswap/v1/consts"
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

func calcPositionRewardByWarmups(currentHeight int64, tokenId uint64) []Reward {
	rewards := CalcPositionReward(CalcPositionRewardParam{
		CurrentHeight: currentHeight,
		Deposits:      deposits,
		Pools:         pools,
		PoolTier:      poolTier,
		TokenId:       tokenId,
	})

	return rewards
}

func calcPositionReward(currentHeight int64, tokenId uint64) Reward {
	rewards := CalcPositionReward(CalcPositionRewardParam{
		CurrentHeight: currentHeight,
		Deposits:      deposits,
		Pools:         pools,
		PoolTier:      poolTier,
		TokenId:       tokenId,
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
	CurrentHeight int64
	Deposits      *Deposits
	Pools         *Pools
	PoolTier      *PoolTier

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
		pool = NewPool(poolPath, param.CurrentHeight, pl.PoolGetSlot0Tick(poolPath))
		param.Pools.Set(poolPath, pool)
	}

	lastCollectHeight := deposit.lastCollectHeight

	// 풀이 꼭 인터널이 있어야 하는건 아님
	// 익스터널 인센티브만 있는 풀도 있을 수 있음
	// 따라서 예외처리 해야 함
	// > 단순 초기화가 아니라 굳이 4개의 아이템을 넣어주는 이유는 리턴할 때 internalRewards 길이만큼 돌면서 externalReward 값을 대입하기 때문
	internalRewards := []uint64{0, 0, 0, 0}
	internalPenalties := []uint64{0, 0, 0, 0}

	if param.PoolTier.CurrentTier(poolPath) != 0 {
		internalRewards, internalPenalties = pool.RewardStateOf(deposit).CalculateInternalReward(lastCollectHeight, param.CurrentHeight, pool.rewardCache)
	}

	allIncentives := pool.incentives.GetAllInHeights(lastCollectHeight, param.CurrentHeight)

	externalRewards := make([]map[string]uint64, 4)
	externalPenalties := make([]map[string]uint64, 4)
	for i := range externalRewards {
		externalRewards[i] = make(map[string]uint64)
		externalPenalties[i] = make(map[string]uint64)
	}

	for incentiveId, incentive := range allIncentives {
		externalReward, externalPenalty := pool.RewardStateOf(deposit).CalculateExternalReward(int64(lastCollectHeight), int64(param.CurrentHeight), incentive)

		for i := range externalReward {
			externalRewards[i][incentiveId] = externalReward[i]
			externalPenalties[i][incentiveId] = externalPenalty[i]
		}
	}

	rewards := make([]Reward, len(internalRewards))
	for i := range internalRewards {
		rewards[i] = Reward{
			Internal:        internalRewards[i],
			InternalPenalty: internalPenalties[i],
			External:        externalRewards[i],
			ExternalPenalty: externalPenalties[i],
		}
	}

	return rewards
}

func ProcessUnClaimableReward(poolPath string, endHeight int64) uint64 {
	pool, ok := pools.Get(poolPath)
	if !ok {
		return 0
	}
	return pool.processUnclaimableReward(poolTier, endHeight)
}
