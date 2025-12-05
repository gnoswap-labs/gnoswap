package v1

import (
	"chain/runtime"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/emission"

	sr "gno.land/r/gnoswap/staker"
)

const (
	defaultDepositGnsAmount    = int64(1_000_000_000)
	defaultMinimumRewardAmount = int64(1_000_000_000)

	// unstakingFee is the fee charged when unstaking positions.
	// This parameter can be modified through governance.
	defaultUnstakingFee = int64(100) // 1%
)

var defaultAllowedTokens = []string{GNS_PATH, GNOT_DENOM}

func init() {
	registerStakerV1()
}

func registerStakerV1() {
	sr.RegisterInitializer(cross, func(stakerStore sr.IStakerStore, poolAccessor sr.PoolAccessor, emissionAccessor sr.EmissionAccessor, nftAccessor sr.NFTAccessor) sr.IStaker {
		err := initStoreData(stakerStore, emissionAccessor)
		if err != nil {
			panic(err)
		}

		instance := NewStakerV1(stakerStore, poolAccessor, emissionAccessor, nftAccessor)

		instance.setupSwapHooks()
		emissionAccessor.SetOnDistributionPctChangeCallback(instance.emissionCacheUpdateHook)

		return instance
	})
}

func initStoreData(stakerStore sr.IStakerStore, emissionAccessor sr.EmissionAccessor) error {
	if !stakerStore.HasDepositGnsAmountStoreKey() {
		err := stakerStore.SetDepositGnsAmount(defaultDepositGnsAmount)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasMinimumRewardAmountStoreKey() {
		err := stakerStore.SetMinimumRewardAmount(defaultMinimumRewardAmount)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasDepositsStoreKey() {
		err := stakerStore.SetDeposits(avl.NewTree())
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasExternalIncentivesStoreKey() {
		err := stakerStore.SetExternalIncentives(avl.NewTree())
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasStakersStoreKey() {
		err := stakerStore.SetStakers(avl.NewTree())
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasTotalEmissionSentStoreKey() {
		err := stakerStore.SetTotalEmissionSent(0)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasAllowedTokensStoreKey() {
		err := stakerStore.SetAllowedTokens(defaultAllowedTokens)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasIncentiveCounterStoreKey() {
		err := stakerStore.SetIncentiveCounter(sr.NewCounter())
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasTokenSpecificMinimumRewardsStoreKey() {
		err := stakerStore.SetTokenSpecificMinimumRewards(avl.NewTree())
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasUnstakingFeeStoreKey() {
		err := stakerStore.SetUnstakingFee(defaultUnstakingFee)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasWarmupTemplateStoreKey() {
		err := stakerStore.SetWarmupTemplate(sr.DefaultWarmupTemplate())
		if err != nil {
			return err
		}
	}

	initializedPoolTier, initializedPools := initializePoolTier(stakerStore)

	if !stakerStore.HasPoolsStoreKey() {
		err := stakerStore.SetPools(initializedPools.tree)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierMembershipsStoreKey() {
		err := stakerStore.SetPoolTierMemberships(initializedPoolTier.membership)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierRatioStoreKey() {
		err := stakerStore.SetPoolTierRatio(initializedPoolTier.tierRatio)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierCountsStoreKey() {
		err := stakerStore.SetPoolTierCounts(initializedPoolTier.counts)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierLastRewardCacheTimestampStoreKey() {
		err := stakerStore.SetPoolTierLastRewardCacheTimestamp(initializedPoolTier.lastRewardCacheTimestamp)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierLastRewardCacheHeightStoreKey() {
		err := stakerStore.SetPoolTierLastRewardCacheHeight(initializedPoolTier.lastRewardCacheHeight)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierCurrentEmissionStoreKey() {
		err := stakerStore.SetPoolTierCurrentEmission(initializedPoolTier.currentEmission)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierGetEmissionStoreKey() {
		getEmissionFn := func() int64 {
			return emissionAccessor.GetStakerEmissionAmountPerSecond()
		}

		err := stakerStore.SetPoolTierGetEmission(getEmissionFn)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierGetHalvingBlocksInRangeStoreKey() {
		getHalvingBlocksInRangeFn := func(start, end int64) ([]int64, []int64) {
			return emissionAccessor.GetStakerEmissionAmountPerSecondInRange(start, end)
		}

		err := stakerStore.SetPoolTierGetHalvingBlocksInRange(getHalvingBlocksInRangeFn)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasCurrentSwapBatchStoreKey() {
		err := stakerStore.SetCurrentSwapBatch(nil)
		if err != nil {
			return err
		}
	}

	return nil
}

func initializePoolTier(stakerStore sr.IStakerStore) (*PoolTier, *Pools) {
	const MUST_EXISTS_IN_TIER_1 = "gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000"

	pools := NewPools()
	pl := NewPools().GetPoolOrNil(MUST_EXISTS_IN_TIER_1)
	if pl == nil {
		pl = sr.NewPool(MUST_EXISTS_IN_TIER_1, time.Now().Unix())
		pools.set(MUST_EXISTS_IN_TIER_1, pl)
	}

	poolTier := NewPoolTier(
		pools,
		runtime.ChainHeight(),
		time.Now().Unix(),
		MUST_EXISTS_IN_TIER_1,
		emission.GetStakerEmissionAmountPerSecond,
		emission.GetStakerEmissionAmountPerSecondInRange,
	)

	return poolTier, pools
}
