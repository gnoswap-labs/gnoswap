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

func (s *stakerV1) getPoolTier() *PoolTier {
	return NewPoolTierBy(
		s.store.GetPoolTierMemberships(),
		s.store.GetPoolTierRatio(),
		s.store.GetPoolTierCounts(),
		s.store.GetPoolTierLastRewardCacheTimestamp(),
		s.store.GetPoolTierCurrentEmission(),
		s.store.GetPoolTierGetEmission(),
		s.store.GetPoolTierGetHalvingBlocksInRange(),
	)
}

func (s *stakerV1) updatePoolTier(_ int, rlm realm, poolTier *PoolTier) {
	err := s.store.SetPoolTierMemberships(0, rlm, poolTier.membership)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierRatio(0, rlm, poolTier.tierRatio)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierCounts(0, rlm, poolTier.counts)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierLastRewardCacheTimestamp(0, rlm, poolTier.lastRewardCacheTimestamp)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierCurrentEmission(0, rlm, poolTier.currentEmission)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierGetEmission(0, rlm, poolTier.getEmission)
	if err != nil {
		panic(err)
	}

	err = s.store.SetPoolTierGetHalvingBlocksInRange(0, rlm, poolTier.getHalvingBlocksInRange)
	if err != nil {
		panic(err)
	}
}

func (s *stakerV1) getDeposits() *Deposits {
	return &Deposits{
		tree: s.store.GetDeposits(),
	}
}

func (s *stakerV1) getExternalIncentives() *ExternalIncentives {
	return &ExternalIncentives{
		tree: s.store.GetExternalIncentives(),
	}
}

func (s *stakerV1) getDepositResolver(lpTokenId uint64) *DepositResolver {
	return NewDepositResolver(s.getDeposit(lpTokenId))
}

func (s *stakerV1) getExternalIncentivesByCreationTime() *sr.UintTree {
	return s.store.GetExternalIncentivesByCreationTime()
}

func (s *stakerV1) updateExternalIncentivesByCreationTime(_ int, rlm realm, externalIncentivesByCreationTime *sr.UintTree) {
	err := s.store.SetExternalIncentivesByCreationTime(0, rlm, externalIncentivesByCreationTime)
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
