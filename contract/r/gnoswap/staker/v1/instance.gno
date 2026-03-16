package v1

import sr "gno.land/r/gnoswap/staker"

type stakerV1 struct {
	store            sr.IStakerStore
	poolAccessor     sr.PoolAccessor
	emissionAccessor sr.EmissionAccessor
	nftAccessor      sr.NFTAccessor
}

func (s *stakerV1) getPools() *Pools {
	return &Pools{
		tree: s.store.GetPools(),
	}
}

func (s *stakerV1) updatePools(pools *Pools) {
	err := s.store.SetPools(pools.tree)
	if err != nil {
		panic(err)
	}
}

func (s *stakerV1) getPoolTier() *PoolTier {
	state := s.store.GetPoolTierState() // store.Get ×1 (was 8)

	// Explicit copy of array and struct to avoid cross-realm taint.
	// Fields of `*PoolTierState` belong to the proxy realm; direct mutation
	// of tainted objects (e.g., counts[tier]++) is not allowed by Gno VM.
	var counts [AllTierCount]uint64
	for i := range state.Counts {
		counts[i] = state.Counts[i]
	}
	tierRatio := sr.TierRatio{
		Tier1: state.TierRatio.Tier1,
		Tier2: state.TierRatio.Tier2,
		Tier3: state.TierRatio.Tier3,
	}

	return NewPoolTierBy(
		&state.Membership,
		tierRatio,
		counts,
		state.LastRewardCacheTimestamp,
		state.LastRewardCacheHeight,
		state.CurrentEmission,
		state.GetEmission,
		state.GetHalvingBlocksInRange,
	)
}

func (s *stakerV1) updatePoolTier(poolTier *PoolTier) {
	err := s.store.SetPoolTierState(&sr.PoolTierState{
		Membership:              *poolTier.membership,
		TierRatio:               poolTier.tierRatio,
		Counts:                  poolTier.counts,
		LastRewardCacheTimestamp: poolTier.lastRewardCacheTimestamp,
		LastRewardCacheHeight:   poolTier.lastRewardCacheHeight,
		CurrentEmission:         poolTier.currentEmission,
		GetEmission:             poolTier.getEmission,
		GetHalvingBlocksInRange: poolTier.getHalvingBlocksInRange,
	})
	if err != nil {
		panic(err)
	}
}

func (s *stakerV1) getDeposits() *Deposits {
	return &Deposits{
		tree: s.store.GetDeposits(),
	}
}

func (s *stakerV1) updateDeposits(deposits *Deposits) {
	err := s.store.SetDeposits(deposits.tree)
	if err != nil {
		panic(err)
	}
}

func (s *stakerV1) getStakers() *Stakers {
	return &Stakers{
		tree: s.store.GetStakers(),
	}
}

func (s *stakerV1) updateStakers(stakers *Stakers) {
	err := s.store.SetStakers(stakers.tree)
	if err != nil {
		panic(err)
	}
}

func (s *stakerV1) getExternalIncentives() *ExternalIncentives {
	return &ExternalIncentives{
		tree: s.store.GetExternalIncentives(),
	}
}

func (s *stakerV1) updateExternalIncentives(externalIncentives *ExternalIncentives) {
	err := s.store.SetExternalIncentives(externalIncentives.tree)
	if err != nil {
		panic(err)
	}
}

func (s *stakerV1) getDepositResolver(lpTokenId uint64) *DepositResolver {
	return NewDepositResolver(s.getDeposit(lpTokenId))
}

func (s *stakerV1) getExternalIncentivesByCreationTime() *sr.UintTree {
	return s.store.GetExternalIncentivesByCreationTime()
}

func (s *stakerV1) updateExternalIncentivesByCreationTime(externalIncentivesByCreationTime *sr.UintTree) {
	err := s.store.SetExternalIncentivesByCreationTime(externalIncentivesByCreationTime)
	if err != nil {
		panic(err)
	}
}

func NewStakerV1(stakerStore sr.IStakerStore, poolAccessor sr.PoolAccessor, emissionAccessor sr.EmissionAccessor, nftAccessor sr.NFTAccessor) *stakerV1 {
	return &stakerV1{
		store:            stakerStore,
		poolAccessor:     poolAccessor,
		emissionAccessor: emissionAccessor,
		nftAccessor:      nftAccessor,
	}
}
