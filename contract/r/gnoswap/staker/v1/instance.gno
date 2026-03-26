package v1

import (
	avl "gno.land/p/nt/avl/v0"
	sr "gno.land/r/gnoswap/staker"
)

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

func (s *stakerV1) getStakers() *Stakers {
	return &Stakers{
		tree: s.store.GetStakers(),
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

func (s *stakerV1) updateExternalIncentivesByCreationTime(externalIncentivesByCreationTime *sr.UintTree) {
	err := s.store.SetExternalIncentivesByCreationTime(externalIncentivesByCreationTime)
	if err != nil {
		panic(err)
	}
}

func (s *stakerV1) getExternalIncentiveIdsByCreationTimeAndPoolPath(creationTime int64, poolPath string) (*avl.Tree, bool) {
	if !s.getExternalIncentivesByCreationTime().Has(creationTime) {
		return nil, false
	}

	poolPaths := s.getExternalIncentivePoolPathsByCreationTime(creationTime)
	if !poolPaths.Has(poolPath) {
		return nil, false
	}

	return s.store.GetExternalIncentiveIdsByCreationTimeAndPoolPath(creationTime, poolPath), true
}

func (s *stakerV1) setExternalIncentiveIdsByCreationTimeAndPoolPath(creationTime int64, poolPath string, ids *avl.Tree) {
	err := s.store.SetExternalIncentiveIdsByCreationTimeAndPoolPath(creationTime, poolPath, ids)
	if err != nil {
		panic(err)
	}
}

func (s *stakerV1) deleteExternalIncentiveIdsByCreationTimeAndPoolPath(creationTime int64, poolPath string) {
	err := s.store.DeleteExternalIncentiveIdsByCreationTimeAndPoolPath(creationTime, poolPath)
	if err != nil {
		panic(err)
	}
}

func (s *stakerV1) getExternalIncentivePoolPathsByCreationTime(creationTime int64) *avl.Tree {
	value, exists := s.getExternalIncentivesByCreationTime().Get(creationTime)
	if !exists {
		panic("external incentive creation time not found")
	}

	poolPaths, ok := value.(*avl.Tree)
	if !ok {
		panic("failed to cast external incentive pool paths to *avl.Tree")
	}

	return poolPaths
}

func NewStakerV1(stakerStore sr.IStakerStore, poolAccessor sr.PoolAccessor, emissionAccessor sr.EmissionAccessor, nftAccessor sr.NFTAccessor) *stakerV1 {
	return &stakerV1{
		store:            stakerStore,
		poolAccessor:     poolAccessor,
		emissionAccessor: emissionAccessor,
		nftAccessor:      nftAccessor,
	}
}
