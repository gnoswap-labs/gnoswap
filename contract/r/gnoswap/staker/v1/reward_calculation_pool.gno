package staker

import (
	"errors"
	"math"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	sr "gno.land/r/gnoswap/staker"
)

var q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")

// Pools represents the global pool storage
type Pools struct {
	tree *bptree.BPTree // string poolPath -> pool
}

// NewPools creates an empty resolver for global pool storage.
//
// Returns:
//   - pools: Pools resolver backed by a new B+ tree keyed by pool path.
func NewPools() *Pools {
	return &Pools{
		tree: sr.NewBPTreeN(16),
	}
}

// Get returns the pool stored under the given pool path.
//
// Parameters:
//   - poolPath: Pool path used as the storage key.
//
// Returns:
//   - pool: Stored pool pointer when poolPath exists; nil when absent.
//   - found: True when poolPath resolves to a pool; false when no entry exists.
func (self *Pools) Get(poolPath string) (*sr.Pool, bool) {
	v := self.tree.Get(poolPath)
	if v == nil {
		return nil, false
	}
	p, ok := v.(*sr.Pool)
	if !ok {
		panic(ufmt.Sprintf("failed to cast v to *Pool: %T", v))
	}
	return p, true
}

// GetPoolOrNil returns the pool for the given pool path, or nil when it does not exist.
//
// Parameters:
//   - poolPath: Pool path used as the storage key.
//
// Returns:
//   - pool: Stored pool pointer, or nil when poolPath is absent.
func (self *Pools) GetPoolOrNil(poolPath string) *sr.Pool {
	pool, ok := self.Get(poolPath)
	if !ok {
		return nil
	}
	return pool
}

// set stores a pool under its path.
//
// Parameters:
//   - poolPath: Pool path used as the storage key.
//   - pool: Pool state to associate with poolPath.
func (self *Pools) set(poolPath string, pool *sr.Pool) {
	self.tree.Set(poolPath, pool)
}

// Has reports whether a pool exists for the given pool path.
//
// Parameters:
//   - poolPath: Pool path used as the storage key.
//
// Returns:
//   - exists: True when poolPath is present in the pool tree; false otherwise.
func (self *Pools) Has(poolPath string) bool {
	return self.tree.Has(poolPath)
}

// IterateAll visits every stored pool until the callback requests that traversal stop.
//
// Parameters:
//   - fn: Callback receiving each pool path and pool pointer; return true to stop iteration, false to continue.
func (self *Pools) IterateAll(fn func(key string, pool *sr.Pool) bool) {
	self.tree.Iterate("", "", func(key string, value any) bool {
		p, ok := value.(*sr.Pool)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to *Pool: %T", value))
		}
		return fn(key, p)
	})
}

type PoolResolver struct {
	*sr.Pool

	// exit is set only when collecting an exit checkpoint, and overrides the pool reads that
	// would otherwise come from state the position no longer takes part in.
	exit *sr.UnstakedPosition
}

// IncentivesResolver returns a resolver over the pool's external-incentive state.
//
// Returns:
//   - resolver: Incentives resolver backed by this pool's incentive tree and unclaimable periods.
func (self *PoolResolver) IncentivesResolver() *IncentivesResolver {
	return NewIncentivesResolver(self.Incentives())
}

// CurrentGlobalRewardRatioAccumulation returns the latest stored global reward-ratio checkpoint in the [0, currentTime] range.
//
// Parameters:
//   - currentTime: Unix timestamp bounding the checkpoint lookup.
//
// Returns:
//   - time: Timestamp of the latest stored checkpoint at or before currentTime; zero when no checkpoint exists.
//   - acc: Decimal-encoded Q128-scaled global reward-ratio accumulation at time.
func (self *PoolResolver) CurrentGlobalRewardRatioAccumulation(currentTime int64) (time int64, acc string) {
	acc = "0"

	self.GlobalRewardRatioAccumulation().ReverseIterate(0, currentTime, func(key int64, value any) bool {
		time = key

		valueStr, ok := value.(string)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to string: %T", value))
		}

		acc = valueStr

		return true
	})

	return time, acc
}

// CurrentTick returns the latest historical tick in the [0, currentTime] range.
//
// Parameters:
//   - currentTime: Unix timestamp bounding the historical-tick lookup.
//
// Returns:
//   - tick: Latest historical tick at or before currentTime; an exit resolver uses its pinned exit tick at or after exit time.
func (self *PoolResolver) CurrentTick(currentTime int64) (tick int32) {
	if self.exit != nil && currentTime >= self.exit.ExitTime() {
		return self.exit.ExitTick()
	}

	self.HistoricalTick().ReverseIterate(0, currentTime, func(key int64, value any) bool {
		res, ok := value.(int32)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to int32: %T", value))
		}
		tick = res
		return true
	})
	return tick
}

// CurrentStakedLiquidity returns the latest staked-liquidity checkpoint in the [0, currentTime] range.
//
// Parameters:
//   - currentTime: Unix timestamp bounding the staked-liquidity lookup.
//
// Returns:
//   - liquidity: Uint256 staked liquidity effective at or before currentTime; zero when no checkpoint exists.
func (self *PoolResolver) CurrentStakedLiquidity(currentTime int64) (liquidity *u256.Uint) {
	liquidity = u256.Zero()

	self.StakedLiquidity().ReverseIterate(0, currentTime, func(key int64, value any) bool {
		res, ok := value.(*u256.Uint)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to *u256.Uint: %T", value))
		}
		liquidity = res
		return true
	})
	return liquidity
}

// GetOrNewTick returns the existing tick or a new zero-valued tick.
//
// Parameters:
//   - tickId: Boundary tick identifier to retrieve or initialize.
//
// Returns:
//   - tick: Existing stored tick, or a zero-valued tick with tickId when no entry exists.
//
// Substituting a zero-valued tick on a read is safe because ticks are pruned
// only when their staked gross liquidity reaches zero, in the same call that
// removes the last deposit referencing them.
func (self *PoolResolver) GetOrNewTick(tickId int32) *sr.Tick {
	if self.exit != nil {
		if lowerTick := self.exit.LowerTick(); lowerTick != nil && lowerTick.Id() == tickId {
			return lowerTick
		}
		if upperTick := self.exit.UpperTick(); upperTick != nil && upperTick.Id() == tickId {
			return upperTick
		}
	}

	tick := self.Ticks().Get(tickId)
	if tick == nil {
		return sr.NewTick(tickId)
	}
	return tick
}

// outsideAccumulationAt returns a boundary tick's outside accumulation at currentTime.
//
// An exit checkpoint answers for its own exit timestamp from the value pinned when it was
// written: a tick cross later in the same block overwrites the entry at that timestamp, while
// earlier entries can no longer change.
//
// Parameters:
//   - tickId: Boundary tick identifier whose outside accumulation is requested.
//   - currentTime: Unix timestamp at which the outside accumulation is evaluated.
//
// Returns:
//   - accumulation: Q128-scaled outside reward-ratio accumulation for tickId at currentTime.
func (self *PoolResolver) outsideAccumulationAt(tickId int32, currentTime int64) *u256.Uint {
	if self.exit != nil && currentTime == self.exit.ExitTime() {
		switch tickId {
		case self.exit.Deposit().TickLower():
			return u256.MustFromDecimal(self.exit.LowerOutsideAcc())
		case self.exit.Deposit().TickUpper():
			return u256.MustFromDecimal(self.exit.UpperOutsideAcc())
		}
	}

	return NewTickResolver(self.GetOrNewTick(tickId)).CurrentOutsideAccumulation(currentTime)
}

// initializeNewTickOutsideAccumulation seeds a newly created boundary tick's outside accumulation.
//
// Parameters:
//   - currentTime: Unix timestamp at which the boundary tick is initialized.
//   - currentTick: Pool tick used to determine whether the new boundary is below or above the current range.
//   - tickId: Identifier of the boundary tick being initialized.
//   - tick: Tick object whose outside accumulation is updated when tickId is not above currentTick.
func (self *PoolResolver) initializeNewTickOutsideAccumulation(currentTime int64, currentTick, tickId int32, tick *sr.Tick) {
	if tickId > currentTick {
		return
	}

	globalAcc, _ := self.globalRewardRatioAccumulationAt(currentTime)
	tick.SetOutsideAccumulationAt(currentTime, globalAcc)
}

// IsExternallyIncentivizedPool reports whether the pool has any external incentive that has not ended,
// including incentives whose start time is still in the future.
//
// Returns:
//   - incentivized: True when at least one non-ended external incentive is indexed for the pool; false when all are ended or none exist.
func (self *PoolResolver) IsExternallyIncentivizedPool() bool {
	currentTime := time.Now().Unix()
	hasIncentive := false
	// With a maximum duration of 365 days, older starts have already ended.
	// Keep future starts eligible and retain historical records for reward claims.
	self.Incentives().IterateIncentiveIdsByTime(stakeScanLowerBound(currentTime), math.MaxInt64, func(incentiveId string) bool {
		incentive, ok := self.Incentives().Incentive(incentiveId)
		if !ok {
			panic("incentive missing from pool start-time index")
		}

		resolver := NewExternalIncentiveResolver(incentive)
		if !resolver.IsEnded(currentTime) {
			hasIncentive = true
			return true
		}

		return false
	})

	return hasIncentive
}

// CurrentReward returns the latest cached per-pool reward rate in the [0, currentTime] range.
//
// Parameters:
//   - currentTime: Unix timestamp bounding the reward-cache lookup.
//
// Returns:
//   - reward: Latest cached GNS reward rate at or before currentTime, in units per second; zero when no checkpoint exists.
func (self *PoolResolver) CurrentReward(currentTime int64) (reward int64) {
	self.RewardCache().ReverseIterate(0, currentTime, func(key int64, value any) bool {
		res, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to int64: %T", value))
		}
		reward = res
		return true
	})
	return reward
}

func (self *PoolResolver) isChangedTick(currentTime int64, currentTick int32) bool {
	if self.HistoricalTick().Size() == 0 {
		return true
	}

	previousTick := self.CurrentTick(currentTime)

	return previousTick != currentTick
}

// cacheReward sets the current reward rate for the pool and maintains unclaimable-period tracking.
//
// Parameters:
//   - currentTime: Unix timestamp at which the reward checkpoint and any period transition occur.
//   - currentTierReward: New per-pool reward rate for the pool's current tier, in GNS units per second.
//
// When a pool first receives a positive reward with zero liquidity, tracking starts at currentTime so the emission window is accounted for.
func (self *PoolResolver) cacheReward(currentTime int64, currentTierReward int64) {
	oldTierReward := self.CurrentReward(currentTime)
	if oldTierReward == currentTierReward {
		return
	}

	isInUnclaimable := self.CurrentStakedLiquidity(currentTime).IsZero()
	if isInUnclaimable {
		// End any existing unclaimable period
		// Note: If lastUnclaimableTime is 0 (not yet tracking), this is a no-op
		self.endUnclaimablePeriod(currentTime)
	}

	self.Pool.SetRewardCacheAt(currentTime, currentTierReward)

	if isInUnclaimable {
		// Start/restart unclaimable period tracking
		// This handles initial tier assignment when lastUnclaimableTime is 0
		self.startUnclaimablePeriod(currentTime)
	}
}

func (self *PoolResolver) calculateGlobalRewardRatioAccumulation(currentTime int64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	oldAccTime, oldAccStr := self.CurrentGlobalRewardRatioAccumulation(currentTime)
	timeDiff := gnsmath.SafeSubInt64(currentTime, oldAccTime)
	if timeDiff == 0 {
		return u256.MustFromDecimal(oldAccStr)
	}
	if timeDiff < 0 {
		panic("time cannot go backwards")
	}

	if currentStakedLiquidity.IsZero() {
		return u256.MustFromDecimal(oldAccStr)
	}

	oldAcc := u256.MustFromDecimal(oldAccStr)
	acc := u256.MulDiv(
		u256.NewUintFromInt64(timeDiff),
		q128,
		currentStakedLiquidity,
	)
	return u256.Zero().Add(oldAcc, acc)
}

// globalRewardRatioAccumulationAt computes the global reward-ratio accumulation at currentTime.
//
// Unlike CurrentGlobalRewardRatioAccumulation, this derives elapsed accumulation from the latest stored checkpoint and current staked liquidity, so it includes time since the checkpoint.
//
// Parameters:
//   - currentTime: Unix timestamp at which the ratio and liquidity are evaluated.
//
// Returns:
//   - accumulation: Q128-scaled global reward-ratio accumulation at currentTime.
//   - stakedLiquidity: Staked liquidity value effective at currentTime.
func (self *PoolResolver) globalRewardRatioAccumulationAt(currentTime int64) (*u256.Uint, *u256.Uint) {
	stakedLiquidity := self.CurrentStakedLiquidity(currentTime)
	accumulation := self.calculateGlobalRewardRatioAccumulation(currentTime, stakedLiquidity)

	return accumulation, stakedLiquidity
}

// updateGlobalRewardRatioAccumulation computes and persists the pool's global reward-ratio accumulation.
//
// Parameters:
//   - currentTime: Unix timestamp at which the checkpoint is written.
//   - currentStakedLiquidity: Staked liquidity used to accrue the ratio over elapsed time.
//
// Returns:
//   - accumulation: Newly calculated Q128-scaled global reward-ratio accumulation.
func (self *PoolResolver) updateGlobalRewardRatioAccumulation(currentTime int64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	newAcc := self.calculateGlobalRewardRatioAccumulation(currentTime, currentStakedLiquidity)

	// Persist as string to reduce stored object complexity.
	self.Pool.SetGlobalRewardRatioAccumulationAt(currentTime, newAcc.ToString())
	return newAcc
}

// RewardStateOf initializes a new RewardState for the given deposit, allocating reward and penalty slots for each warmup.
//
// Parameters:
//   - deposit: Staked deposit whose pool, liquidity, and warmup schedule will be resolved.
//
// Returns:
//   - state: RewardState initialized with zeroed per-warmup reward and penalty accumulators.
func (self *PoolResolver) RewardStateOf(deposit *sr.Deposit) *RewardState {
	warmups := len(deposit.Warmups())
	result := &RewardState{
		pool:      self,
		deposit:   NewDepositResolver(deposit),
		rewards:   make([]int64, warmups),
		penalties: make([]int64, warmups),
	}

	return result
}

// reset clears cached rewards/penalties so a RewardState can be reused without re-allocating.
func (self *RewardState) reset() {
	for i := range self.rewards {
		self.rewards[i] = 0
		self.penalties[i] = 0
	}
}

// NewPoolResolver wraps a pool's persisted reward, liquidity, tick, and incentive state for calculations.
//
// Parameters:
//   - pool: Pool state to resolve.
//
// Returns:
//   - resolver: Pool resolver backed by pool.
func NewPoolResolver(pool *sr.Pool) *PoolResolver {
	return &PoolResolver{
		Pool: pool,
	}
}

// newPoolResolverWithExit builds a resolver that reads the pool through an exit checkpoint.
//
// Parameters:
//   - pool: Pool state containing the live reward and tick histories.
//   - exit: Unstaked position checkpoint whose pinned tick, boundaries, and tier context override live reads at exit time.
//
// Returns:
//   - resolver: Pool resolver configured to reproduce reward calculations for exit.
func newPoolResolverWithExit(pool *sr.Pool, exit *sr.UnstakedPosition) *PoolResolver {
	return &PoolResolver{
		Pool: pool,
		exit: exit,
	}
}

// RewardState is a struct for storing the intermediate state for reward calculation.
type RewardState struct {
	pool    *PoolResolver
	deposit *DepositResolver

	// accumulated rewards for each warmup
	rewards   []int64
	penalties []int64
}

// calculateInternalReward computes the position's per-warmup rewards and penalties from a pre-resolved
// per-second reward-rate schedule (see PoolResolver.resolveInternalRewardSegments).
//
// It is pure with respect to pool state: it reads no tier/emission state and writes no persistent state.
// Each segment [start, end) is applied at its constant per-second rate, then warmup ratios are applied.
//
// Parameters:
//   - segments: Ordered internal reward-rate segments, each describing a time interval and its per-second rate.
//
// Returns:
//   - rewards: Per-warmup rewards after warmup ratios, in GNS units and warmup order.
//   - penalties: Per-warmup amounts withheld by warmup ratios, in GNS units and warmup order.
func (self *RewardState) calculateInternalReward(segments []internalRewardSegment) ([]int64, []int64) {
	for _, seg := range segments {
		if err := self.rewardPerWarmup(seg.start, seg.end, seg.rewardPerSecond); err != nil {
			panic(err)
		}
	}

	self.applyWarmup()

	return self.rewards, self.penalties
}

// updateExternalReward advances external reward accounting for a deposit over a requested interval.
// It clamps start and end to the deposit cursor and the incentive's active window before calculating rewards.
//
// Parameters:
//   - startTime: Requested interval start as a Unix timestamp.
//   - endTime: Requested interval end as a Unix timestamp.
//   - incentive: External incentive whose ID, window, and Q128 reward rate are used.
//
// Returns:
//   - err: Nil when the interval is processed or lies outside the incentive window; arithmetic failures panic.
func (self *RewardState) updateExternalReward(startTime, endTime int64, incentive *sr.ExternalIncentive) error {
	lastCollectTime := self.deposit.ExternalRewardLastCollectTime(incentive.IncentiveId())
	if startTime < lastCollectTime {
		// This must not happen, but adding some guards just in case.
		startTime = lastCollectTime
	}

	ictvStart := incentive.StartTimestamp()
	if endTime < ictvStart {
		return nil // Not started yet
	}

	if startTime < ictvStart {
		startTime = ictvStart
	}

	ictvEnd := incentive.EndTimestamp()
	if endTime > ictvEnd {
		endTime = ictvEnd
	}

	if startTime > ictvEnd {
		return nil // Already ended
	}

	return self.rewardPerWarmupX128(startTime, endTime, incentive.RewardPerSecondX128())
}

// calculateCollectableExternalReward calculates the total external reward generated for a requested interval.
// It clamps the interval to the incentive window and the deposit cursor, then sums the raw per-warmup entries.
//
// Parameters:
//   - startTime: Requested interval start as a Unix timestamp.
//   - endTime: Requested interval end as a Unix timestamp.
//   - incentive: External incentive whose reward rate and window are used.
//
// Returns:
//   - reward: Sum of generated external reward entries in incentive-token units; warmup ratios are not applied by this helper.
func (self *RewardState) calculateCollectableExternalReward(startTime, endTime int64, incentive *sr.ExternalIncentive) int64 {
	err := self.updateExternalReward(startTime, endTime, incentive)
	if err != nil {
		panic(err)
	}

	currentReward := u256.Zero()

	for i := range self.rewards {
		currentReward = currentReward.Add(currentReward, u256.NewUintFromInt64(self.rewards[i]))
	}

	return gnsmath.SafeConvertToInt64(currentReward)
}

// calculateExternalReward calculates per-warmup external reward and penalty for a requested interval.
// The interval is clamped to the incentive window and the deposit's last collection cursor before warmup ratios are applied.
//
// Parameters:
//   - startTime: Requested interval start as a Unix timestamp.
//   - endTime: Requested interval end as a Unix timestamp.
//   - incentive: External incentive whose reward rate and window are used.
//
// Returns:
//   - rewards: Reward amounts after each warmup ratio, in incentive-token units and warmup order.
//   - penalties: Amount withheld by each warmup ratio, in incentive-token units and warmup order.
func (self *RewardState) calculateExternalReward(startTime, endTime int64, incentive *sr.ExternalIncentive) ([]int64, []int64) {
	err := self.updateExternalReward(startTime, endTime, incentive)
	if err != nil {
		panic(err)
	}

	// apply warmup to collect rewards
	self.applyWarmup()

	return self.rewards, self.penalties
}

// applyWarmup applies each deposit warmup ratio to accumulated rewards and records the withheld amount as a penalty.
func (self *RewardState) applyWarmup() {
	for i, warmup := range self.deposit.Warmups() {
		warmupReward := self.rewards[i]

		// calculate warmup reward applying warmup ratio
		self.rewards[i] = gnsmath.SafeMulDivInt64(warmupReward, int64(warmup.WarmupRatio), 100)

		// warmup penalty is the difference between the warmup reward and the warmup reward applying warmup ratio
		self.penalties[i] = gnsmath.SafeSubInt64(warmupReward, self.rewards[i])
	}
}

// rewardPerWarmup computes each warmup's internal-emission reward over a time interval using an integer per-second rate.
//
// Parameters:
//   - startTime: Unix timestamp at the beginning of the interval.
//   - endTime: Unix timestamp at the end of the interval; empty intervals produce no reward.
//   - rewardPerSecond: Integer GNS reward rate per second.
//
// Returns:
//   - err: Nil when reward entries are updated; arithmetic overflow is raised as a panic rather than returned.
func (self *RewardState) rewardPerWarmup(startTime, endTime int64, rewardPerSecond int64) error {
	// Return early if startTime equals endTime to avoid unnecessary computation
	if startTime == endTime {
		return nil
	}

	startTick := self.pool.CurrentTick(startTime)
	startRaw := self.pool.CalculateRawRewardForPosition(startTime, startTick, self.deposit.Deposit)

	for i, warmup := range self.deposit.Warmups() {
		if startTime >= warmup.NextWarmupTime {
			// passed the warmup
			continue
		}

		if endTime < warmup.NextWarmupTime {
			endTick := self.pool.CurrentTick(endTime)
			endRaw := self.pool.CalculateRawRewardForPosition(endTime, endTick, self.deposit.Deposit)
			// Modular by design: boundary ticks created at different times give a
			// wrapped base, so the borrow is expected and the wrapped difference
			// is the true accumulation (Uniswap V3 subtracts unchecked too).
			rewardAcc := u256.Zero().Sub(endRaw, startRaw)

			rewardAcc, overflow := u256.Zero().MulOverflow(rewardAcc, self.deposit.Liquidity())
			if overflow {
				panic(errors.New(errOverflow))
			}

			rewardAcc = u256.MulDiv(rewardAcc, u256.NewUintFromInt64(rewardPerSecond), q128)
			self.rewards[i] = gnsmath.SafeAddInt64(self.rewards[i], gnsmath.SafeConvertToInt64(rewardAcc))

			break
		}

		endTick := self.pool.CurrentTick(warmup.NextWarmupTime)
		endRaw := self.pool.CalculateRawRewardForPosition(warmup.NextWarmupTime, endTick, self.deposit.Deposit)
		// See the note above: the subtraction is intentionally modular.
		rewardAcc := u256.Zero().Sub(endRaw, startRaw)

		rewardAcc, overflow := u256.Zero().MulOverflow(rewardAcc, self.deposit.Liquidity())
		if overflow {
			panic(errors.New(errOverflow))
		}

		rewardAcc = u256.MulDiv(rewardAcc, u256.NewUintFromInt64(rewardPerSecond), q128)
		self.rewards[i] = gnsmath.SafeAddInt64(self.rewards[i], gnsmath.SafeConvertToInt64(rewardAcc))

		startTime = warmup.NextWarmupTime
		startTick = endTick
		startRaw = endRaw
	}

	return nil
}

// rewardPerWarmupX128 computes each warmup's external-incentive reward over a time interval using a Q128-scaled rate.
//
// Parameters:
//   - startTime: Unix timestamp at the beginning of the interval.
//   - endTime: Unix timestamp at the end of the interval; empty intervals produce no reward.
//   - rewardPerSecondX128: Per-second reward rate scaled by 2^128, as stored on an external incentive.
//
// Returns:
//   - err: Nil when reward entries are updated; arithmetic overflow is raised as a panic rather than returned.
func (self *RewardState) rewardPerWarmupX128(startTime, endTime int64, rewardPerSecondX128 *u256.Uint) error {
	if startTime == endTime {
		return nil
	}

	startTick := self.pool.CurrentTick(startTime)
	startRaw := self.pool.CalculateRawRewardForPosition(startTime, startTick, self.deposit.Deposit)

	for i, warmup := range self.deposit.Warmups() {
		if startTime >= warmup.NextWarmupTime {
			continue
		}

		if endTime < warmup.NextWarmupTime {
			endTick := self.pool.CurrentTick(endTime)
			endRaw := self.pool.CalculateRawRewardForPosition(endTime, endTick, self.deposit.Deposit)
			// Modular by design: boundary ticks created at different times give a
			// wrapped base, so the borrow is expected and the wrapped difference
			// is the true accumulation (Uniswap V3 subtracts unchecked too).
			rewardAcc := u256.Zero().Sub(endRaw, startRaw)

			rewardAcc, overflow := u256.Zero().MulOverflow(rewardAcc, self.deposit.Liquidity())
			if overflow {
				panic(errors.New(errOverflow))
			}

			rewardAcc = u256.MulDiv(rewardAcc, rewardPerSecondX128, q128)
			rewardAcc = u256.Zero().Rsh(rewardAcc, 128)
			self.rewards[i] = gnsmath.SafeAddInt64(self.rewards[i], gnsmath.SafeConvertToInt64(rewardAcc))

			break
		}

		endTick := self.pool.CurrentTick(warmup.NextWarmupTime)
		endRaw := self.pool.CalculateRawRewardForPosition(warmup.NextWarmupTime, endTick, self.deposit.Deposit)
		// See the note above: the subtraction is intentionally modular.
		rewardAcc := u256.Zero().Sub(endRaw, startRaw)

		rewardAcc, overflow := u256.Zero().MulOverflow(rewardAcc, self.deposit.Liquidity())
		if overflow {
			panic(errors.New(errOverflow))
		}

		rewardAcc = u256.MulDiv(rewardAcc, rewardPerSecondX128, q128)
		rewardAcc = u256.Zero().Rsh(rewardAcc, 128)
		self.rewards[i] = gnsmath.SafeAddInt64(self.rewards[i], gnsmath.SafeConvertToInt64(rewardAcc))

		startTime = warmup.NextWarmupTime
		startTick = endTick
		startRaw = endRaw
	}

	return nil
}

// modifyDeposit applies a signed staked-liquidity change and updates time-dependent pool checkpoints.
//
// Parameters:
//   - delta: Signed liquidity change to apply; a negative result is rejected if it would underflow.
//   - currentTime: Unix timestamp at which the liquidity and reward-ratio checkpoints are updated.
//   - nextTick: Tick value to record when the historical tick changes.
//
// Returns:
//   - accumulation: New global reward-ratio accumulation computed at currentTime before applying delta.
func (self *PoolResolver) modifyDeposit(delta *i256.Int, currentTime int64, nextTick int32) *u256.Uint {
	// update staker side pool info
	lastStakedLiquidity := self.CurrentStakedLiquidity(currentTime)
	deltaApplied := gnsmath.LiquidityMathAddDelta(lastStakedLiquidity, delta)
	result := self.updateGlobalRewardRatioAccumulation(currentTime, lastStakedLiquidity)

	// historical tick does NOT actually reflect the tick at the timestamp, but it provides correct ordering for the staked positions
	// because TickCrossHook is assured to be called for the staked-initialized ticks
	if self.isChangedTick(currentTime, nextTick) {
		self.Pool.SetHistoricalTickAt(currentTime, nextTick)
	}

	switch deltaApplied.Sign() {
	case -1:
		panic("stakedLiquidity is less than 0, should not happen")
	case 0:
		if lastStakedLiquidity.Sign() == 1 {
			// StakedLiquidity moved from positive to zero, start unclaimable period
			self.startUnclaimablePeriod(currentTime)
			self.IncentivesResolver().startUnclaimablePeriod(currentTime)
		}
	case 1:
		if lastStakedLiquidity.Sign() == 0 {
			// StakedLiquidity moved from zero to positive, end unclaimable period
			self.endUnclaimablePeriod(currentTime)
			self.IncentivesResolver().endUnclaimablePeriod(currentTime)
		}
	}

	// Only append a staked-liquidity entry when the value actually changes (e.g. a tick cross whose
	// net delta is zero leaves it unchanged). Unlike the global reward ratio accumulation, this tree
	// carries no time-checkpoint semantics: it is read purely as a point-in-time value via
	// CurrentStakedLiquidity (latest entry <= t), so omitting a duplicate-valued entry preserves
	// behavior while keeping this append-only tree from growing on no-op updates.
	if !lastStakedLiquidity.Eq(deltaApplied) {
		self.Pool.SetStakedLiquidityAt(currentTime, deltaApplied)
	}

	return result
}

// startUnclaimablePeriod starts tracking reward while the pool has no staked liquidity.
//
// Parameters:
//   - currentTime: Unix timestamp at which zero-liquidity tracking begins.
//
// If tracking is already active, currentTime does not replace the original start.
func (self *PoolResolver) startUnclaimablePeriod(currentTime int64) {
	if self.LastUnclaimableTime() == 0 {
		// We set only if it's the first time entering(0 indicates not set yet)
		self.SetLastUnclaimableTime(currentTime)
	}
}

// endUnclaimablePeriod ends an open unclaimable period and records its accumulated reward.
//
// Parameters:
//   - currentTime: Unix timestamp at which the period ends and its reward is accrued.
//
// If no period is being tracked, the operation is a no-op; otherwise it resets the period marker after accumulation.
func (self *PoolResolver) endUnclaimablePeriod(currentTime int64) {
	if self.LastUnclaimableTime() == 0 {
		// lastUnclaimableTime = 0 means tracking hasn't started yet
		// This is normal during initial pool creation or when called from cacheReward
		// during tier assignment with zero liquidity
		return
	}

	self.updateUnclaimableAccumulateRewards(currentTime)
	self.SetLastUnclaimableTime(0)
}

// updateUnclaimableAccumulateRewards accrues reward for the current unclaimable period.
//
// Parameters:
//   - currentTime: Unix timestamp through which the open period is accrued.
//
// When currentTime is not after the period start, the accumulator is left unchanged.
func (self *PoolResolver) updateUnclaimableAccumulateRewards(currentTime int64) {
	if self.LastUnclaimableTime() >= currentTime {
		return
	}

	unclaimableDuration := gnsmath.SafeSubInt64(currentTime, self.LastUnclaimableTime())
	currentUnclaimableReward := gnsmath.SafeMulInt64(unclaimableDuration, self.CurrentReward(self.LastUnclaimableTime()))
	self.SetUnclaimableAcc(gnsmath.SafeAddInt64(self.UnclaimableAcc(), currentUnclaimableReward))
}

// processUnclaimableReward finalizes and returns the pool's accumulated unclaimable internal reward.
//
// Parameters:
//   - endTime: Unix timestamp through which an open unclaimable period is accrued.
//
// Returns:
//   - reward: Accumulated unclaimable internal reward in GNS units; the stored accumulator is reset to zero.
func (self *PoolResolver) processUnclaimableReward(endTime int64) int64 {
	// Check current pool liquidity state
	isZeroStakedLiquidity := self.CurrentStakedLiquidity(endTime).IsZero()

	if self.LastUnclaimableTime() > 0 {
		// We have an ongoing unclaimable period tracking
		self.updateUnclaimableAccumulateRewards(endTime)

		if isZeroStakedLiquidity {
			// Still unclaimable - accumulate rewards up to endTime
			// Update tracking time for continuing unclaimable period
			self.SetLastUnclaimableTime(endTime)
		} else {
			// Was unclaimable but now has liquidity - properly end the period
			self.SetLastUnclaimableTime(0)
		}
	} else {
		if isZeroStakedLiquidity {
			// No previous tracking but currently unclaimable - this shouldn't normally happen
			// as startUnclaimablePeriod should have been called when liquidity reached 0
			// Start tracking from now
			self.SetLastUnclaimableTime(endTime)
		}
	}

	// Return and reset accumulated unclaimable rewards
	internalUnClaimable := self.UnclaimableAcc()
	self.SetUnclaimableAcc(0)
	return internalUnClaimable
}

// CalculateRawRewardForPosition calculates the theoretical reward accumulator for a position without debt or warmup adjustments.
//
// Parameters:
//   - currentTime: Unix timestamp at which pool reward state is evaluated.
//   - currentTick: Pool tick used to determine whether the position is below, inside, or above its range.
//   - deposit: Position deposit whose liquidity and boundary ticks determine the raw reward.
//
// Returns:
//   - reward: Q128-scaled raw reward accumulator for the position; debt, warmup ratios, and fees are not applied.
func (self *PoolResolver) CalculateRawRewardForPosition(currentTime int64, currentTick int32, deposit *sr.Deposit) *u256.Uint {
	var rewardAcc *u256.Uint

	globalAcc := self.calculateGlobalRewardRatioAccumulation(currentTime, self.CurrentStakedLiquidity(currentTime))

	lowerAcc := self.outsideAccumulationAt(deposit.TickLower(), currentTime)
	upperAcc := self.outsideAccumulationAt(deposit.TickUpper(), currentTime)
	if currentTick < deposit.TickLower() {
		rewardAcc = u256.Zero().Sub(lowerAcc, upperAcc)
	} else if currentTick >= deposit.TickUpper() {
		rewardAcc = u256.Zero().Sub(upperAcc, lowerAcc)
	} else {
		rewardAcc = u256.Zero().Sub(globalAcc, lowerAcc)
		rewardAcc = rewardAcc.Sub(rewardAcc, upperAcc)
	}

	return rewardAcc
}
