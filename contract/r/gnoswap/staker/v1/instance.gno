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
	err := s.store.SetPoolTierMemberships(poolTier.membership)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierRatio(poolTier.tierRatio)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierCounts(poolTier.counts)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierLastRewardCacheTimestamp(poolTier.lastRewardCacheTimestamp)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierLastRewardCacheHeight(poolTier.lastRewardCacheHeight)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierCurrentEmission(poolTier.currentEmission)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierGetEmission(poolTier.getEmission)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierGetHalvingBlocksInRange(poolTier.getHalvingBlocksInRange)
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
