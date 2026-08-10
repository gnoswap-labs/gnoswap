package staker

import (
	"errors"
	"time"

	"gno.land/r/gnoswap/emission"

	sr "gno.land/r/gnoswap/staker"
)

const (
	defaultDepositGnsAmount    = int64(1_000_000_000)
	defaultMinimumRewardAmount = int64(1_000_000_000)

	// unstakingFee is the fee charged when unstaking positions.
	// This parameter can be modified through governance.
	defaultUnstakingFee = uint64(100) // 1%
)

func init(cur realm) {
	registerStakerV1(cur)
}

func registerStakerV1(cur realm) {
	sr.RegisterInitializer(cross(cur), func(_ int, rlm realm, stakerStore sr.IStakerStore, poolAccessor sr.PoolAccessor, emissionAccessor sr.EmissionAccessor, nftAccessor sr.NFTAccessor) sr.IStaker {
		if !rlm.IsCurrent() {
			panic(errors.New(errSpoofedRealm))
		}

		err := initStoreData(0, rlm, stakerStore, emissionAccessor)
		if err != nil {
			panic(err)
		}

		instance := NewStakerV1(stakerStore, poolAccessor, emissionAccessor, nftAccessor)
		instance.setupSwapHooks(0, rlm)
		emissionAccessor.SetOnDistributionPctChangeCallback(0, rlm, instance.emissionCacheUpdateHook)

		return instance
	})
}

func initStoreData(_ int, rlm realm, stakerStore sr.IStakerStore, emissionAccessor sr.EmissionAccessor) error {
	if !stakerStore.HasDepositGnsAmountStoreKey() {
		err := stakerStore.SetDepositGnsAmount(0, rlm, defaultDepositGnsAmount)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasMinimumRewardAmountStoreKey() {
		err := stakerStore.SetMinimumRewardAmount(0, rlm, defaultMinimumRewardAmount)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasDepositsStoreKey() {
		err := stakerStore.SetDeposits(0, rlm, sr.NewBPTreeN(16))
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasExternalIncentivesStoreKey() {
		err := stakerStore.SetExternalIncentives(0, rlm, sr.NewBPTreeN(16))
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasTotalEmissionSentStoreKey() {
		err := stakerStore.SetTotalEmissionSent(0, rlm, 0)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasAllowedTokensStoreKey() {
		// Copy the package-level default slice so each store owns its own
		// allowed-tokens slice. Storing sr.DefaultAllowedTokens directly would
		// alias the shared (sr-owned) slice across every store, leaking
		// mutations and tripping the readonly-taint gate on later writes.
		err := stakerStore.SetAllowedTokens(0, rlm, sr.DefaultAllowedTokens())
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasIncentiveCounterStoreKey() {
		err := stakerStore.SetIncentiveCounter(0, rlm, sr.NewCounter())
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasTokenSpecificMinimumRewardsStoreKey() {
		err := stakerStore.SetTokenSpecificMinimumRewards(0, rlm, make(map[string]int64))
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasUnstakingFeeStoreKey() {
		err := stakerStore.SetUnstakingFee(0, rlm, defaultUnstakingFee)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPendingProtocolFeesStoreKey() {
		err := stakerStore.SetPendingProtocolFees(0, rlm, make(map[string]int64))
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasWarmupTemplateStoreKey() {
		err := stakerStore.SetWarmupTemplate(0, rlm, sr.DefaultWarmupTemplate())
		if err != nil {
			return err
		}
	}

	initializedPoolTier, initializedPools, initialPoolTierTime, initialTierRewards := initializePoolTier(stakerStore)

	previousRealm := rlm.Previous()
	emitSetPoolTier(
		previousRealm.Address().String(),
		previousRealm.PkgPath(),
		emission.DefaultInitialPoolTierPath,
		uint64(Tier1),
		initializedPoolTier.currentEmission,
		initialTierRewards,
		initializedPoolTier.counts,
		initialPoolTierTime,
	)

	if !stakerStore.HasPoolsStoreKey() {
		err := stakerStore.SetPools(0, rlm, initializedPools.tree)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierMembershipsStoreKey() {
		err := stakerStore.SetPoolTierMemberships(0, rlm, initializedPoolTier.membership)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierRatioStoreKey() {
		err := stakerStore.SetPoolTierRatio(0, rlm, initializedPoolTier.tierRatio)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierCountsStoreKey() {
		err := stakerStore.SetPoolTierCounts(0, rlm, initializedPoolTier.counts)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierLastRewardCacheTimestampStoreKey() {
		err := stakerStore.SetPoolTierLastRewardCacheTimestamp(0, rlm, initializedPoolTier.lastRewardCacheTimestamp)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierCurrentEmissionStoreKey() {
		err := stakerStore.SetPoolTierCurrentEmission(0, rlm, initializedPoolTier.currentEmission)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierGetEmissionStoreKey() {
		getEmissionFn := func() int64 {
			return emissionAccessor.GetStakerEmissionAmountPerSecond()
		}

		err := stakerStore.SetPoolTierGetEmission(0, rlm, getEmissionFn)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasPoolTierGetHalvingBlocksInRangeStoreKey() {
		getHalvingBlocksInRangeFn := func(start, end int64) ([]int64, []int64) {
			return emissionAccessor.GetStakerEmissionAmountPerSecondInRange(start, end)
		}

		err := stakerStore.SetPoolTierGetHalvingBlocksInRange(0, rlm, getHalvingBlocksInRangeFn)
		if err != nil {
			return err
		}
	}

	if !stakerStore.HasCurrentSwapBatchStoreKey() {
		err := stakerStore.SetCurrentSwapBatch(0, rlm, nil)
		if err != nil {
			return err
		}
	}

	return nil
}

// initializePoolTier seeds the staker's pool tiering state on first init.
//
// The default pool is the canonical WUGNOT:GNS:3000 pool, sourced from the
// emission realm's DefaultInitialPoolTierPath constant so that the staker's
// tier-1 base pool is guaranteed to match the pool emission distributes to.
//
// When SetDistributionStartTime executes, emission distributes to this default
// pool and the staker uses the same path as the base tier-1 pool for reward
// accrual. Keeping both sides on emission's single constant structurally
// enforces that invariant and removes any risk of the two realms drifting
// apart on the canonical default pool identity.
func initializePoolTier(stakerStore sr.IStakerStore) (*PoolTier, *Pools, int64, map[uint64]int64) {
	pools := NewPools()
	currentTime := time.Now().Unix()

	pl := NewPools().GetPoolOrNil(emission.DefaultInitialPoolTierPath)
	if pl == nil {
		pl = sr.NewPool(emission.DefaultInitialPoolTierPath, currentTime)
		pools.set(emission.DefaultInitialPoolTierPath, pl)
	}

	poolTier := NewPoolTier(
		pools,
		currentTime,
		emission.DefaultInitialPoolTierPath,
		emission.GetStakerEmissionAmountPerSecond,
		emission.GetStakerEmissionAmountPerSecondInRange,
	)

	return poolTier, pools, currentTime, poolTier.computeTierRewards(poolTier.currentEmission)
}
