package staker

import sr "gno.land/r/gnoswap/staker"

type stakerV1 struct {
	store            sr.IStakerStore
	poolAccessor     sr.PoolAccessor
	emissionAccessor sr.EmissionAccessor
	nftAccessor      sr.NFTAccessor
}

// getPools returns a resolver over the persisted pool tree.
//
// Returns:
//   - pools: Resolver backed by the store's pool records.
func (s *stakerV1) getPools() *Pools {
	return &Pools{
		tree: s.store.GetPools(),
	}
}

// getPoolTier assembles a resolver from the persisted pool-tier state.
//
// Returns:
//   - poolTier: Resolver combining tier memberships, ratios, counts, reward timestamps, emissions, and halving callbacks.
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

// updatePoolTier persists all components of the supplied pool-tier state.
//
// Parameters:
//   - _: Entry-point discriminator forwarded as 0 to each persistence setter.
//   - rlm: Propagated realm context forwarded to store setters, which validate it as current before writing.
//   - poolTier: Tier state whose memberships, ratios, counts, reward timestamp, emission, and emission callbacks are persisted.
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

// getDeposits returns a resolver over the persisted deposit tree.
//
// Returns:
//   - deposits: Resolver backed by the store's deposit records.
func (s *stakerV1) getDeposits() *Deposits {
	return &Deposits{
		tree: s.store.GetDeposits(),
	}
}

// getExternalIncentives returns a resolver over the persisted external-incentive tree.
//
// Returns:
//   - incentives: Resolver backed by the store's external incentive records.
func (s *stakerV1) getExternalIncentives() *ExternalIncentives {
	return &ExternalIncentives{
		tree: s.store.GetExternalIncentives(),
	}
}

// getDepositResolver creates a resolver for a stored deposit.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose deposit should be resolved.
//
// Returns:
//   - resolver: Resolver exposing reward and deposit state for lpTokenId.
//   - err: Non-nil when no deposit exists for lpTokenId or the deposit lookup fails.
func (s *stakerV1) getDepositResolver(lpTokenId uint64) (*DepositResolver, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return nil, err
	}
	return NewDepositResolver(deposit), nil
}

// NewStakerV1 constructs a version 1 staker implementation backed by the supplied accessors.
//
// Parameters:
//   - stakerStore: Persistent storage accessor for pools, deposits, incentives, tier state, and reward bookkeeping.
//   - poolAccessor: Accessor for pool state used while updating and resolving staked positions.
//   - emissionAccessor: Accessor for GNS emission data used to calculate rewards.
//   - nftAccessor: Accessor for the position NFT ownership and token operations.
//
// Returns:
//   - staker: New stakerV1 implementation wired to the supplied store and accessors.
func NewStakerV1(stakerStore sr.IStakerStore, poolAccessor sr.PoolAccessor, emissionAccessor sr.EmissionAccessor, nftAccessor sr.NFTAccessor) *stakerV1 {
	return &stakerV1{
		store:            stakerStore,
		poolAccessor:     poolAccessor,
		emissionAccessor: emissionAccessor,
		nftAccessor:      nftAccessor,
	}
}
