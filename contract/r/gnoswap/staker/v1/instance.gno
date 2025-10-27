package v1

import sr "gno.land/r/gnoswap/staker"

var _ sr.IStaker = &stakerV1{}

type stakerV1 struct {
	store            sr.IStakerStore
	emissionAccessor sr.EmissionAccessor
	currentSwapBatch *SwapBatchProcessor
}

func (s *stakerV1) getPools() *Pools {
	return &Pools{
		tree: s.store.GetPools(),
	}
}

func (s *stakerV1) updatePools(pools *Pools) {
	s.store.SetPools(pools.tree)
}

func (s *stakerV1) getPoolTier() *PoolTier {
	return NewPoolTierBy(
		s.store.GetPoolTierMemberships(),
		s.store.GetPoolTierRatio(),
		s.store.GetPoolTierCounts(),
		s.store.GetPoolTierLastRewardCacheTimestamp(),
		s.store.GetPoolTierLastRewardCacheHeight(),
		s.store.GetPoolTierCurrentEmission(),
		s.store.GetPoolTierGetEmission(),
		s.store.GetPoolTierGetHalvingBlocksInRange(),
	)
}

func (s *stakerV1) updatePoolTier(poolTier *PoolTier) {
	s.store.SetPoolTierMemberships(poolTier.membership)
	s.store.SetPoolTierRatio(poolTier.tierRatio)
	s.store.SetPoolTierCounts(poolTier.counts)
	s.store.SetPoolTierLastRewardCacheTimestamp(poolTier.lastRewardCacheTimestamp)
	s.store.SetPoolTierLastRewardCacheHeight(poolTier.lastRewardCacheHeight)
	s.store.SetPoolTierCurrentEmission(poolTier.currentEmission)
	s.store.SetPoolTierGetEmission(poolTier.getEmission)
	s.store.SetPoolTierGetHalvingBlocksInRange(poolTier.getHalvingBlocksInRange)
}

func (s *stakerV1) getDeposits() *Deposits {
	return &Deposits{
		tree: s.store.GetDeposits(),
	}
}

func (s *stakerV1) updateDeposits(deposits *Deposits) {
	s.store.SetDeposits(deposits.tree)
}

func (s *stakerV1) getStakers() *Stakers {
	return &Stakers{
		tree: s.store.GetStakers(),
	}
}

func (s *stakerV1) updateStakers(stakers *Stakers) {
	s.store.SetStakers(stakers.tree)
}

func (s *stakerV1) getExternalIncentives() *ExternalIncentives {
	return &ExternalIncentives{
		tree: s.store.GetExternalIncentives(),
	}
}

func (s *stakerV1) updateExternalIncentives(externalIncentives *ExternalIncentives) {
	s.store.SetExternalIncentives(externalIncentives.tree)
}

func NewStakerV1(stakerStore sr.IStakerStore, emissionAccessor sr.EmissionAccessor) *stakerV1 {
	return &stakerV1{
		store:            stakerStore,
		emissionAccessor: emissionAccessor,
		currentSwapBatch: nil,
	}
}
