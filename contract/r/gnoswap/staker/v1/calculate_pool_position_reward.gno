package staker

import (
	"time"

	"gno.land/p/gnoswap/gnsmath"
	ufmt "gno.land/p/nt/ufmt/v0"

	sr "gno.land/r/gnoswap/staker"
)

// Reward is a struct for storing reward for a position.
// Internal reward is the GNS reward, external reward is the reward for other incentives.
// Penalties are the amount that is deducted from the reward due to the position's warmup.
type Reward struct {
	Internal        int64
	InternalPenalty int64
	External        map[string]int64 // Incentive ID -> TokenAmount
	ExternalPenalty map[string]int64 // Incentive ID -> TokenAmount
}

// aggregateRewards sums the per-warmup rewards/penalties into a single Reward.
//
// Parameters:
//   - rewards: Per-warmup reward records to combine.
//
// Returns:
//   - aggregate: One reward containing summed internal values and per-incentive external values and penalties.
func aggregateRewards(rewards []Reward) Reward {
	internal := int64(0)
	internalPenalty := int64(0)

	rewardLen := len(rewards)
	externalReward := make(map[string]int64, rewardLen)
	externalPenalty := make(map[string]int64, rewardLen)

	for _, reward := range rewards {
		internal = gnsmath.SafeAddInt64(internal, reward.Internal)
		internalPenalty = gnsmath.SafeAddInt64(internalPenalty, reward.InternalPenalty)

		for incentive, amount := range reward.External {
			externalReward[incentive] = gnsmath.SafeAddInt64(externalReward[incentive], amount)
		}

		for incentive, penalty := range reward.ExternalPenalty {
			externalPenalty[incentive] = gnsmath.SafeAddInt64(externalPenalty[incentive], penalty)
		}
	}

	return Reward{
		Internal:        internal,
		InternalPenalty: internalPenalty,
		External:        externalReward,
		ExternalPenalty: externalPenalty,
	}
}

// calculatePositionRewardParam is a struct for calculating position reward
type calculatePositionRewardParam struct {
	// Environmental variables
	CurrentHeight int64
	CurrentTime   int64
	Deposits      *Deposits
	Pools         *Pools
	PoolTier      *PoolTier

	// Position variables
	PositionId uint64

	// Deposit overrides the Deposits lookup for a deposit that is no longer in the tree.
	Deposit *sr.Deposit
	// Exit pins the pool state to the moment the position left the pool; nil while staked.
	Exit *sr.UnstakedPosition
}

// deposit resolves the deposit the calculation runs against.
//
// Returns:
//   - deposit: Explicit parameter deposit when present; otherwise the deposit loaded for PositionId (missing stored data panics).
func (self *calculatePositionRewardParam) deposit() *sr.Deposit {
	if self.Deposit != nil {
		return self.Deposit
	}

	return self.Deposits.get(self.PositionId)
}

// positionRewardUpdate carries the persisted-state changes produced (but not applied) by a calculation.
// They are applied by the update* functions, so that only the collect path mutates state while the
// calculation stays pure.
type positionRewardUpdate struct {
	poolPath    string
	pool        *sr.Pool
	poolExisted bool

	// External incentive ids discovered as newly created since the deposit's last update; they must be
	// added to the deposit's incentive index.
	newExternalIncentiveIds []string
	// Whether the deposit's LastExternalIncentiveUpdatedAt cursor should be advanced to CurrentTime.
	advanceExternalIncentiveCursor bool

	// Incentive ids the calculation actually produced a reward for, in calculation order. The collect
	// path walks this instead of iterating the reward map, so delivery order is deterministic.
	externalIncentiveIds []string
}

// positionRewardContext carries the per-position state that both the internal (GNS emission) and the
// external (incentive) reward calculations need. Resolving it once lets each path be calculated on its
// own without duplicating the deposit/pool/reward-state setup.
type positionRewardContext struct {
	deposit         *sr.Deposit
	depositResolver *DepositResolver
	poolResolver    *PoolResolver
	rewardState     *RewardState
	warmupLen       int

	update positionRewardUpdate
}

// newPositionRewardContext resolves the deposit, its pool and a fresh RewardState WITHOUT mutating
// persisted state. A missing pool is created ephemerally and its persistence is deferred to the
// update path.
//
// Parameters:
//   - param: Calculation inputs containing the position, deposit/pool stores, current time, and optional exit checkpoint.
//
// Returns:
//   - context: Read-only reward-calculation context with resolved deposit, pool, warmups, and deferred update state.
func (s *stakerV1) newPositionRewardContext(param *calculatePositionRewardParam) *positionRewardContext {
	deposit := param.deposit()
	poolPath := deposit.TargetPoolPath()

	pool, poolExisted := param.Pools.Get(poolPath)
	if !poolExisted {
		// Read-only: use an ephemeral pool; persistence is deferred to updatePositionReward.
		pool = sr.NewPool(poolPath, param.CurrentTime)
	}
	poolResolver := newPoolResolverWithExit(pool, param.Exit)

	return &positionRewardContext{
		deposit:         deposit,
		depositResolver: NewDepositResolver(deposit),
		poolResolver:    poolResolver,
		rewardState:     poolResolver.RewardStateOf(deposit),
		warmupLen:       len(deposit.Warmups()),
		update: positionRewardUpdate{
			poolPath:    poolPath,
			pool:        pool,
			poolExisted: poolExisted,
		},
	}
}

// newRewards allocates the empty per-warmup reward slice the compute* methods write into.
//
// Returns:
//   - rewards: Zero-initialized reward record for each warmup tier, including empty external reward and penalty maps.
func (self *positionRewardContext) newRewards() []Reward {
	rewards := make([]Reward, self.warmupLen)
	for i := 0; i < self.warmupLen; i++ {
		rewards[i] = Reward{
			External:        make(map[string]int64),
			ExternalPenalty: make(map[string]int64),
		}
	}

	return rewards
}

// computeInternalRewards writes the GNS emission reward and penalty of each warmup into rewards.
//
// The per-second emission-rate schedule is resolved up-front (resolveInternalRewardSegments) and fed to
// the single internal-reward calculator, so the calculation needs no reward-cache update.
//
// Parameters:
//   - param: Calculation inputs used to resolve the pool's internal emission schedule and collection interval.
//   - rewards: Per-warmup reward records to populate with internal reward and penalty amounts.
//
// Returns:
//   - err: Non-nil when resolving the internal reward schedule fails; nil after all warmup slots are populated.
func (self *positionRewardContext) computeInternalRewards(param *calculatePositionRewardParam, rewards []Reward) error {
	lastCollectTime := self.depositResolver.InternalRewardLastCollectTime()

	// Resolve the per-second reward-rate schedule (pure) and calculate internal rewards from it.
	internalSegments, err := self.poolResolver.resolveInternalRewardSegments(param.PoolTier, self.update.poolPath, lastCollectTime, param.CurrentTime)
	if err != nil {
		return err
	}
	calculatedInternalRewards, calculatedInternalPenalties := self.rewardState.calculateInternalReward(internalSegments)

	for i := 0; i < self.warmupLen; i++ {
		rewards[i].Internal = calculatedInternalRewards[i]
		rewards[i].InternalPenalty = calculatedInternalPenalties[i]
	}

	self.rewardState.reset()

	return nil
}

// discoverExternalIncentives records the incentives created since the deposit's last update on the
// update, WITHOUT mutating the deposit. The collect path adds them to the deposit's incentive index.
//
// ExternalRewardLastCollectTime falls back to StakeTime for ids not yet persisted, so a newly-discovered
// incentive yields the same calculation whether or not it is written to the deposit.
//
// Parameters:
//   - param: Calculation inputs whose deposit cursor and current time bound incentive discovery.
func (self *positionRewardContext) discoverExternalIncentives(param *calculatePositionRewardParam) {
	lastExternalIncentiveUpdatedAt := self.depositResolver.LastExternalIncentiveUpdatedAt()
	if lastExternalIncentiveUpdatedAt >= param.CurrentTime {
		return
	}

	// Discover incentives from this pool's own start-time index. Using the
	// local resolver keeps calculation read-only even for an ephemeral pool
	// that has not yet been persisted in param.Pools.
	newIds := make([]string, 0)
	self.poolResolver.IncentivesResolver().IterateIncentiveIdsByTime(lastExternalIncentiveUpdatedAt, param.CurrentTime, func(incentiveId string) bool {
		newIds = append(newIds, incentiveId)
		return false
	})

	self.update.newExternalIncentiveIds = newIds
	self.update.advanceExternalIncentiveCursor = true
}

// externalIncentiveIds returns the deposit's effective incentive-id set: the ids stored on the deposit
// plus the ones discoverExternalIncentives found. Call it after discoverExternalIncentives.
//
// Returns:
//   - incentiveIds: Deposit-indexed incentive IDs combined with IDs newly discovered during this calculation, without duplicates.
func (self *positionRewardContext) externalIncentiveIds() []string {
	seen := make(map[string]bool)
	incentiveIds := make([]string, 0)

	self.deposit.IterateExternalIncentiveIds(func(incentiveId string) bool {
		if !seen[incentiveId] {
			seen[incentiveId] = true
			incentiveIds = append(incentiveIds, incentiveId)
		}
		return false
	})

	for _, incentiveId := range self.update.newExternalIncentiveIds {
		if !seen[incentiveId] {
			seen[incentiveId] = true
			incentiveIds = append(incentiveIds, incentiveId)
		}
	}

	return incentiveIds
}

// computeExternalReward writes one incentive's external reward and penalty of each warmup into rewards.
// An incentive that does not exist on the pool or has not started yet contributes nothing.
//
// Parameters:
//   - param: Calculation inputs containing the current time and pool/incentive state.
//   - rewards: Per-warmup reward records to populate for incentiveId.
//   - incentiveId: External incentive ID to calculate; missing or not-yet-started incentives add no rewards.
func (self *positionRewardContext) computeExternalReward(param *calculatePositionRewardParam, rewards []Reward, incentiveId string) {
	incentive, ok := self.poolResolver.IncentivesResolver().Get(incentiveId)
	if !ok {
		return
	}

	incentiveResolver := NewExternalIncentiveResolver(incentive)

	// Check if incentive is active during this specific collection period
	if !incentiveResolver.IsStarted(param.CurrentTime) {
		return
	}

	// External incentivized pool.
	// Calculate reward for each warmup using per-incentive lastCollectTime
	externalLastCollectTime := self.depositResolver.ExternalRewardLastCollectTime(incentiveId)
	externalReward, externalPenalty := self.rewardState.calculateExternalReward(externalLastCollectTime, param.CurrentTime, incentive)

	for i := range externalReward {
		if externalReward[i] > 0 || externalPenalty[i] > 0 {
			rewards[i].External[incentiveId] = externalReward[i]
			rewards[i].ExternalPenalty[incentiveId] = externalPenalty[i]
		}
	}

	self.update.externalIncentiveIds = append(self.update.externalIncentiveIds, incentiveId)
	self.rewardState.reset()
}

// computeExternalRewards writes every incentive of the deposit into rewards.
//
// Parameters:
//   - param: Calculation inputs containing the deposit, current time, and pool state.
//   - rewards: Per-warmup reward records to populate for every effective incentive.
func (self *positionRewardContext) computeExternalRewards(param *calculatePositionRewardParam, rewards []Reward) {
	self.discoverExternalIncentives(param)

	for _, incentiveId := range self.externalIncentiveIds() {
		self.computeExternalReward(param, rewards, incentiveId)
	}
}

// calculateCollectablePositionReward calculates the aggregated position reward WITHOUT mutating any persisted state.
//
// It is the shared, read-only entry point used by the Collectable* view getters.
// This keeps the calculation identical for every caller and guarantees views never write.
//
// Parameters:
//   - currentHeight: Chain height associated with this read-only calculation.
//   - currentTimestamp: Evaluation time in Unix seconds; an exit checkpoint overrides this with its exit time.
//   - positionId: LP position NFT ID whose accumulated rewards should be calculated.
//
// Returns:
//   - reward: Aggregated internal and external rewards across all warmup tiers.
//   - err: Non-nil when internal reward schedule resolution fails; nil when reward calculation succeeds.
func (s *stakerV1) calculateCollectablePositionReward(currentHeight, currentTimestamp int64, positionId uint64) (Reward, error) {
	param := &calculatePositionRewardParam{
		CurrentHeight: currentHeight,
		CurrentTime:   currentTimestamp,
		Deposits:      s.getDeposits(),
		Pools:         s.getPools(),
		PoolTier:      s.getPoolTier(),
		PositionId:    positionId,
	}

	// An unstaked position quotes against its exit checkpoint, at its exit time.
	if checkpoint := s.getUnstakedPositions().get(positionId); checkpoint != nil {
		param.CurrentTime = checkpoint.ExitTime()
		param.Deposit = checkpoint.Deposit()
		param.Exit = checkpoint
	}

	rewards, _, err := s.calculatePositionReward(param)
	if err != nil {
		return Reward{}, err
	}

	return aggregateRewards(rewards), nil
}

// calculatePositionReward computes a position's per-warmup internal AND external rewards WITHOUT
// mutating persisted state. All would-be state changes are returned as a positionRewardUpdate for the
// caller to apply (collect only).
//
// Parameters:
//   - param: Position calculation inputs, including stores, time, position ID, and optional exit state.
//
// Returns:
//   - rewards: Per-warmup internal and external reward records.
//   - update: Deferred pool and deposit-index changes produced by the read-only calculation.
//   - err: Non-nil when internal reward schedule resolution fails; nil on success.
func (s *stakerV1) calculatePositionReward(param *calculatePositionRewardParam) ([]Reward, positionRewardUpdate, error) {
	ctx := s.newPositionRewardContext(param)
	rewards := ctx.newRewards()

	if err := ctx.computeInternalRewards(param, rewards); err != nil {
		return nil, positionRewardUpdate{}, err
	}
	ctx.computeExternalRewards(param, rewards)

	return rewards, ctx.update, nil
}

// calculateInternalPositionReward computes only a position's per-warmup GNS emission rewards, WITHOUT
// mutating persisted state. Used by the emission collect path.
//
// Parameters:
//   - param: Position calculation inputs, including stores, time, position ID, and optional exit state.
//
// Returns:
//   - rewards: Per-warmup GNS emission reward and penalty records.
//   - update: Deferred pool-cache changes produced by the read-only calculation.
//   - err: Non-nil when internal reward schedule resolution fails; nil on success.
func (s *stakerV1) calculateInternalPositionReward(param *calculatePositionRewardParam) ([]Reward, positionRewardUpdate, error) {
	ctx := s.newPositionRewardContext(param)
	rewards := ctx.newRewards()

	if err := ctx.computeInternalRewards(param, rewards); err != nil {
		return nil, positionRewardUpdate{}, err
	}

	return rewards, ctx.update, nil
}

// calculateExternalPositionReward computes a position's per-warmup reward for one external incentive,
// WITHOUT mutating persisted state. Used by the external incentive collect path.
//
// Incentive discovery still runs over every incentive, so the deposit's incentive index stays complete
// no matter which incentive the caller asked for.
//
// Parameters:
//   - param: Position calculation inputs, including stores, time, position ID, and optional exit state.
//   - incentiveId: External incentive ID whose per-warmup reward should be calculated.
//
// Returns:
//   - rewards: Per-warmup records containing the requested incentive's reward and penalty when applicable.
//   - update: Deferred pool persistence and newly discovered deposit-incentive index changes.
func (s *stakerV1) calculateExternalPositionReward(param *calculatePositionRewardParam, incentiveId string) ([]Reward, positionRewardUpdate) {
	ctx := s.newPositionRewardContext(param)
	rewards := ctx.newRewards()

	ctx.discoverExternalIncentives(param)
	ctx.computeExternalReward(param, rewards, incentiveId)

	return rewards, ctx.update
}

// persistLazyPool persists a pool that calculation created ephemerally because it did not exist yet.
//
// Parameters:
//   - param: Calculation inputs whose Pools store receives a lazily created pool.
//   - updateParams: Deferred update containing the pool path, pool value, and whether it already existed.
func (s *stakerV1) persistLazyPool(param *calculatePositionRewardParam, updateParams positionRewardUpdate) {
	if !updateParams.poolExisted {
		param.Pools.set(updateParams.poolPath, updateParams.pool)
	}
}

// updateInternalRewardCache advances the reward cache up to CurrentTime (halving boundaries). The
// calculation itself no longer needs this, but downstream unclaimable processing (which reads
// CurrentReward) and off-chain history rely on the cache, so it is advanced on the emission collect path.
//
// Parameters:
//   - param: Calculation inputs containing the pool tier, pool store, and calculation timestamp.
//   - updateParams: Deferred update identifying the pool whose cache should be advanced.
func (s *stakerV1) updateInternalRewardCache(param *calculatePositionRewardParam, updateParams positionRewardUpdate) {
	// Always at the current time, never at param.CurrentTime: the cache and the unclaimable
	// tracking it drives are pool-global, and a checkpoint collect would rewind them to its exit
	// timestamp, where the pool may have had no staked liquidity.
	param.PoolTier.cacheRewardForPool(time.Now().Unix(), param.Pools, updateParams.poolPath)
}

// applyExternalIncentiveIndex persists the deposit incentive-index updates discovered during calculation.
//
// Parameters:
//   - param: Calculation inputs whose deposit receives discovered incentive IDs and cursor changes.
//   - updateParams: Deferred update containing newly discovered IDs and the cursor-advance flag.
func (s *stakerV1) applyExternalIncentiveIndex(param *calculatePositionRewardParam, updateParams positionRewardUpdate) {
	if len(updateParams.newExternalIncentiveIds) == 0 && !updateParams.advanceExternalIncentiveCursor {
		return
	}

	deposit := param.deposit()
	for _, incentiveId := range updateParams.newExternalIncentiveIds {
		deposit.AddExternalIncentiveId(incentiveId)
	}
	if updateParams.advanceExternalIncentiveCursor {
		deposit.SetLastExternalIncentiveUpdatedAt(param.CurrentTime)
	}
}

// updatePositionReward applies the persisted-state changes produced by calculatePositionReward.
// It is called ONLY by the collect path; the Collectable* view getters discard the update.
//
// Parameters:
//   - param: Position calculation inputs used to resolve the target deposit and pool stores.
//   - updateParams: Deferred internal-cache, lazy-pool, and external-incentive-index changes to apply.
func (s *stakerV1) updatePositionReward(param *calculatePositionRewardParam, updateParams positionRewardUpdate) {
	s.persistLazyPool(param, updateParams)
	s.updateInternalRewardCache(param, updateParams)
	s.applyExternalIncentiveIndex(param, updateParams)
}

// updateInternalPositionReward applies the state changes belonging to the emission collect path only.
//
// Parameters:
//   - param: Position calculation inputs used for lazy-pool persistence and cache advancement.
//   - updateParams: Deferred pool and internal reward-cache changes from emission calculation.
func (s *stakerV1) updateInternalPositionReward(param *calculatePositionRewardParam, updateParams positionRewardUpdate) {
	s.persistLazyPool(param, updateParams)
	s.updateInternalRewardCache(param, updateParams)
}

// updateExternalPositionReward applies the state changes belonging to the external collect path only.
//
// Parameters:
//   - param: Position calculation inputs whose deposit may receive newly discovered incentive IDs.
//   - updateParams: Deferred lazy-pool and external-incentive-index changes from incentive calculation.
func (s *stakerV1) updateExternalPositionReward(param *calculatePositionRewardParam, updateParams positionRewardUpdate) {
	s.persistLazyPool(param, updateParams)
	s.applyExternalIncentiveIndex(param, updateParams)
}

// internalRewardSegment is a [start, end) span over which the per-second emission reward rate is constant.
type internalRewardSegment struct {
	start           int64
	end             int64
	rewardPerSecond int64
}

// resolveInternalRewardSegments builds the per-second reward-rate schedule over [startTime, endTime]
// WITHOUT mutating state.
//
// Persisted reward-cache entries cover the historical portion: they record tier/count changes and any
// halvings already materialized by past collects, so no un-materialized halving exists strictly between
// two persisted entries. The tail beyond the last persisted entry is split by halvings using the current
// tier ratio/count, which are necessarily constant there (a change would have written a cache entry). The
// tail rate is recomputed with the same calculatePoolReward arithmetic the cache writer uses, so a
// schedule resolved from a fully materialized cache and one resolved from the emission halvings are
// identical.
//
// Parameters:
//   - poolTier: Pool-tier state used to derive reward rates after the persisted cache tail.
//   - poolPath: Pool identifier whose tier context and halving schedule are resolved.
//   - startTime: Inclusive beginning of the requested schedule in Unix seconds.
//   - endTime: Exclusive end of the requested schedule in Unix seconds.
//
// Returns:
//   - segments: Constant-rate spans covering [startTime, endTime).
//   - err: Non-nil when tier or halving data cannot be resolved; nil for a complete schedule.
func (self *PoolResolver) resolveInternalRewardSegments(poolTier *PoolTier, poolPath string, startTime, endTime int64) ([]internalRewardSegment, error) {
	segments := make([]internalRewardSegment, 0)
	if startTime >= endTime {
		return segments, nil
	}

	currentReward := self.CurrentReward(startTime)
	cursor := startTime

	self.RewardCache().Iterate(startTime, endTime, func(key int64, value any) bool {
		reward, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to int64: %T", value))
		}

		segments = append(segments, internalRewardSegment{start: cursor, end: key, rewardPerSecond: currentReward})
		cursor = key
		currentReward = reward
		return false
	})

	if cursor < endTime {
		var err error
		segments, err = appendInternalRewardTailSegments(segments, poolTier, poolPath, cursor, endTime, currentReward, self.exit)
		if err != nil {
			return nil, err
		}
	}

	return segments, nil
}

// appendInternalRewardTailSegments appends the schedule for the tail [startTime, endTime], where no
// persisted cache entry exists beyond startTime. Over this span tier/count are constant, so the rate
// changes only at halving boundaries.
//
// Parameters:
//   - segments: Existing constant-rate spans to extend.
//   - poolTier: Pool-tier state used to resolve live tier context and halving emissions.
//   - poolPath: Pool identifier whose tier and halving schedule are used.
//   - startTime: Inclusive beginning of the uncached tail in Unix seconds.
//   - endTime: Exclusive end of the requested tail in Unix seconds.
//   - baseReward: Rate already effective at startTime, in reward-token units per second.
//   - exit: Optional exit checkpoint supplying the tier context captured when the position unstaked.
//
// Returns:
//   - segments: Input spans followed by tail spans split at applicable halving times.
//   - err: Non-nil when live tier context or halving data cannot be resolved; nil on success.
func appendInternalRewardTailSegments(segments []internalRewardSegment, poolTier *PoolTier, poolPath string, startTime, endTime, baseReward int64, exit *sr.UnstakedPosition) ([]internalRewardSegment, error) {
	// A checkpoint reads the tier context it exited under: this window closed at the exit, and
	// the live lookup is skipped so a checkpoint collect never depends on live tier state.
	var tier, ratio, count uint64
	if exit != nil {
		tier, ratio, count = exit.Tier(), exit.TierRatio(), exit.TierCount()
	} else {
		var err error
		tier, ratio, count, err = poolTier.tierContextOf(poolPath)
		if err != nil {
			return nil, err
		}
	}

	if tier == 0 || tier >= AllTierCount {
		// Not currently tiered: the rate cannot increase; the base is 0 after de-tier.
		return append(segments, internalRewardSegment{start: startTime, end: endTime, rewardPerSecond: baseReward}), nil
	}

	tierRatioInt64 := int64(ratio)
	tierCount := int64(count)

	halvingTimestamps, halvingEmissions, err := poolTier.getHalvingBlocksInRange(startTime, endTime)
	if err != nil {
		return nil, err
	}

	segStart := startTime
	rate := baseReward
	for i, hv := range halvingTimestamps {
		if hv <= segStart {
			// Halving effective at/before the segment start: only switch the rate.
			rate, err = calculatePoolReward(halvingEmissions[i], tierRatioInt64, tierCount)
			if err != nil {
				return nil, err
			}
			continue
		}
		if hv >= endTime {
			break
		}

		segments = append(segments, internalRewardSegment{start: segStart, end: hv, rewardPerSecond: rate})
		rate, err = calculatePoolReward(halvingEmissions[i], tierRatioInt64, tierCount)
		if err != nil {
			return nil, err
		}
		segStart = hv
	}

	return append(segments, internalRewardSegment{start: segStart, end: endTime, rewardPerSecond: rate}), nil
}

// processUnClaimableReward settles the pool's accumulated internal reward that cannot be claimed by positions.
//
// Parameters:
//   - poolPath: Pool identifier whose unclaimable internal reward should be processed.
//   - endTimestamp: Unix timestamp through which unclaimable reward is settled.
//
// Returns:
//   - amount: Internal reward amount moved from the pool's unclaimable accumulator, or 0 when the pool is absent.
func (s *stakerV1) processUnClaimableReward(poolPath string, endTimestamp int64) int64 {
	pool, ok := s.getPools().Get(poolPath)
	if !ok {
		return 0
	}
	poolResolver := NewPoolResolver(pool)

	return poolResolver.processUnclaimableReward(endTimestamp)
}

// getExternalIncentiveIdsBy returns incentive IDs created for a pool during the requested time range.
//
// Parameters:
//   - poolPath: Pool identifier whose incentive start-time index should be queried.
//   - startTime: Inclusive beginning of the incentive-discovery time range in Unix seconds.
//   - endTime: End of the incentive-discovery time range in Unix seconds.
//
// Returns:
//   - incentiveIds: Incentive IDs indexed for poolPath in the requested time range, in index iteration order.
func (s *stakerV1) getExternalIncentiveIdsBy(poolPath string, startTime, endTime int64) []string {
	currentIncentiveIds := make([]string, 0)

	pool, ok := s.getPools().Get(poolPath)
	if !ok {
		return currentIncentiveIds
	}
	poolResolver := NewPoolResolver(pool)

	// Look up the pool's own start-time index instead of a global
	// creation-time index. The index is scoped to this pool's incentives, so
	// discovery cost is bounded by the number of incentives for this pool
	// within the queried range, and no longer grows with the total number of
	// incentives system-wide.
	poolResolver.IncentivesResolver().IterateIncentiveIdsByTime(startTime, endTime, func(incentiveId string) bool {
		currentIncentiveIds = append(currentIncentiveIds, incentiveId)
		return false
	})

	return currentIncentiveIds
}

// getInitialCollectTime determines the initial collection time for an incentive
// by taking the maximum of the deposit's stake time and the incentive's start time.
// This ensures rewards are only calculated from when both conditions are met:
// - The position must be staked (deposit.stakeTime)
// - The incentive must be active (incentive.startTimestamp)
//
// This function is used for lazy initialization when a position collects
// from an incentive for the first time, avoiding the need to iterate through
// all deposits when a new incentive is created.
//
// Parameters:
//   - deposit: Deposit whose stake time bounds reward eligibility.
//   - incentive: External incentive whose start time bounds reward eligibility.
//
// Returns:
//   - collectTime: Later of deposit.StakeTime() and incentive.StartTimestamp(), in Unix seconds.
func getInitialCollectTime(deposit *sr.Deposit, incentive *sr.ExternalIncentive) int64 {
	if deposit.StakeTime() > incentive.StartTimestamp() {
		return deposit.StakeTime()
	}
	return incentive.StartTimestamp()
}
