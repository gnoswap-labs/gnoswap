package staker

import (
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	// Q128 is 2^128
	q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")
	// Q192 is 2^192
	q192 = u256.MustFromDecimal("6277101735386680763835789423207666416102355444464034512896")

	// pools is the global pool storage
	pools *Pools
)

func init() {
	pools = NewPools()
}

// Pools represents the global pool storage
type Pools struct {
	tree *avl.Tree // string poolPath -> pool
}

func NewPools() *Pools {
	return &Pools{
		tree: avl.NewTree(),
	}
}

// Get returns the pool for the given poolPath
func (self *Pools) Get(poolPath string) (*Pool, bool) {
	v, ok := self.tree.Get(poolPath)
	if !ok {
		return nil, false
	}
	p, ok := v.(*Pool)
	if !ok {
		panic(ufmt.Sprintf("failed to cast v to *Pool: %T", v))
	}
	return p, true
}

// GetOrCreate returns the pool for the given poolPath, or creates a new pool if it does not exist
func (self *Pools) GetOrCreate(poolPath string) *Pool {
	pool, ok := self.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, time.Now().Unix())
		self.set(poolPath, pool)
	}
	return pool
}

// set sets the pool for the given poolPath
func (self *Pools) set(poolPath string, pool *Pool) {
	self.tree.Set(poolPath, pool)
}

// Has returns true if the pool exists for the given poolPath
func (self *Pools) Has(poolPath string) bool {
	return self.tree.Has(poolPath)
}

func (self *Pools) IterateAll(fn func(key string, pool *Pool) bool) {
	self.tree.Iterate("", "", func(key string, value any) bool {
		return fn(key, value.(*Pool))
	})
}

// Pool is a struct for storing an incentivized pool information
// Each pool stores Incentives and Ticks associated with it.
//
// Fields:
// - poolPath: The path of the pool.
//
//   - currentStakedLiquidity:
//     The current total staked liquidity of the in-range positions for the pool.
//     Updated when tick cross happens or stake/unstake happens.
//     Used to calculate the global reward ratio accumulation or
//     decide whether to enter/exit unclaimable period.
//
//   - lastUnclaimableTime:
//     The time at which the unclaimable period started.
//     Set to 0 when the pool is not in an unclaimable period.
//
//   - unclaimableAcc:
//     The accumulated undisributed unclaimable reward.
//     Reset to 0 when processUnclaimableReward is called and sent to community pool.
//
//   - rewardCache:
//     The cached per-second reward emitted for this pool.
//     Stores new entry only when the reward is changed.
//     PoolTier.cacheReward() updates this.
//
// - incentives: The external incentives associated with the pool.
//
// - ticks: The Ticks associated with the pool.
//
//   - globalRewardRatioAccumulation:
//     Global ratio of Time / TotalStake accumulation(since the pool creation)
//     Stores new entry only when tick cross or stake/unstake happens.
//     It is used to calculate the reward for a staked position at certain time.
//
//   - historicalTick:
//     The historical tick for the pool at a given time.
//     It does not reflect the exact tick at the timestamp,
//     but it provides correct ordering for the staked position's ticks.
//     Therefore, you should not compare it for equality, only for ordering.
//     Set when tick cross happens or a new position is created.
type Pool struct {
	poolPath string

	stakedLiquidity *UintTree // uint64 timestamp -> *u256.Uint(Q128)

	lastUnclaimableTime int64
	unclaimableAcc      int64

	rewardCache *UintTree // uint64 timestamp -> int64 gnsReward

	incentives Incentives

	ticks Ticks // int32 tickId -> Tick tick

	globalRewardRatioAccumulation *UintTree // uint64 timestamp -> *u256.Uint(Q128) rewardRatioAccumulation

	historicalTick *UintTree // uint64 timestamp -> int32 tickId
}

// NewPool creates a new pool with the given poolPath and currentHeight.
func NewPool(poolPath string, currentTime int64) *Pool {
	pool := &Pool{
		poolPath:                      poolPath,
		stakedLiquidity:               NewUintTree(),
		lastUnclaimableTime:           currentTime,
		unclaimableAcc:                0,
		rewardCache:                   NewUintTree(),
		incentives:                    NewIncentives(poolPath),
		ticks:                         NewTicks(),
		globalRewardRatioAccumulation: NewUintTree(),
		historicalTick:                NewUintTree(),
	}

	pool.globalRewardRatioAccumulation.set(currentTime, u256.Zero())
	pool.rewardCache.set(currentTime, int64(0))
	pool.stakedLiquidity.set(currentTime, u256.Zero())

	return pool
}

// Get the latest global reward ratio accumulation in [0, currentTime] range.
// Returns the time and the accumulation.
func (self *Pool) CurrentGlobalRewardRatioAccumulation(currentTime int64) (time int64, acc *u256.Uint) {
	self.globalRewardRatioAccumulation.ReverseIterate(0, currentTime, func(key int64, value any) bool {
		time = key
		v, ok := value.(*u256.Uint)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to *u256.Uint: %T", value))
		}
		acc = v
		return true
	})
	if acc == nil {
		panic("should not happen, globalRewardRatioAccumulation must be set when pool is created")
	}
	return
}

// Get the latest tick in [0, currentTime] range.
// Returns the tick.
func (self *Pool) CurrentTick(currentTime int64) (tick int32) {
	self.historicalTick.ReverseIterate(0, currentTime, func(key int64, value any) bool {
		res, ok := value.(int32)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to int32: %T", value))
		}
		tick = res
		return true
	})
	return
}

func (self *Pool) CurrentStakedLiquidity(currentTime int64) (liquidity *u256.Uint) {
	self.stakedLiquidity.ReverseIterate(0, currentTime, func(key int64, value any) bool {
		res, ok := value.(*u256.Uint)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to *u256.Uint: %T", value))
		}
		liquidity = res
		return true
	})
	return
}

// IsExternallyIncentivizedPool returns true if the pool has any external incentives.
func (self *Pool) IsExternallyIncentivizedPool() bool {
	return self.incentives.incentives.Size() > 0
}

// Get the latest reward in [0, currentTime] range.
// Returns the reward.
func (self *Pool) CurrentReward(currentTime int64) (reward int64) {
	self.rewardCache.ReverseIterate(0, currentTime, func(key int64, value any) bool {
		res, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to int64: %T", value))
		}
		reward = res
		return true
	})
	return
}

// cacheReward sets the current reward for the pool
// If the pool is in unclaimable period, it will end the unclaimable period,  updates the reward, and start the unclaimable period again.
func (self *Pool) cacheReward(currentTime int64, currentTierReward int64) {
	oldTierReward := self.CurrentReward(currentTime)
	if oldTierReward == currentTierReward {
		return
	}

	isInUnclaimable := self.CurrentStakedLiquidity(currentTime).IsZero()
	if isInUnclaimable {
		self.endUnclaimablePeriod(currentTime)
	}

	self.rewardCache.set(currentTime, currentTierReward)

	if isInUnclaimable {
		self.startUnclaimablePeriod(currentTime)
	}
}

// cacheInternalReward caches the current emission and updates the global reward ratio accumulation.
func (self *Pool) cacheInternalReward(currentTime int64, currentEmission int64) {
	self.cacheReward(currentTime, currentEmission)

	currentStakedLiquidity := self.CurrentStakedLiquidity(currentTime)
	if currentStakedLiquidity.IsZero() {
		self.endUnclaimablePeriod(currentTime)
		self.startUnclaimablePeriod(currentTime)
	}

	self.updateGlobalRewardRatioAccumulation(currentTime, currentStakedLiquidity)
}

func (self *Pool) calculateGlobalRewardRatioAccumulation(currentTime int64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	oldAccTime, oldAcc := self.CurrentGlobalRewardRatioAccumulation(currentTime)
	timeDiff := currentTime - oldAccTime
	if timeDiff == 0 {
		return oldAcc.Clone()
	}
	if timeDiff < 0 {
		panic("time cannot go backwards")
	}

	if currentStakedLiquidity.IsZero() {
		return oldAcc.Clone()
	}

	acc := u256.MulDiv(
		u256.NewUintFromInt64(timeDiff),
		q128,
		currentStakedLiquidity,
	)
	return u256.Zero().Add(oldAcc, acc)
}

// updateGlobalRewardRatioAccumulation updates the global reward ratio accumulation and returns the new accumulation.
func (self *Pool) updateGlobalRewardRatioAccumulation(currentTime int64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	newAcc := self.calculateGlobalRewardRatioAccumulation(currentTime, currentStakedLiquidity)

	self.globalRewardRatioAccumulation.set(currentTime, newAcc)
	return newAcc
}

// RewardState is a struct for storing the intermediate state for reward calculation.
type RewardState struct {
	pool    *Pool
	deposit *Deposit

	// accumulated rewards for each warmup
	rewards   []int64
	penalties []int64
}

// RewardStateOf initializes a new RewardState for the given deposit.
func (self *Pool) RewardStateOf(deposit *Deposit) *RewardState {
	result := &RewardState{
		pool:      self,
		deposit:   deposit,
		rewards:   make([]int64, len(deposit.warmups)),
		penalties: make([]int64, len(deposit.warmups)),
	}

	for i := range result.rewards {
		result.rewards[i] = 0
		result.penalties[i] = 0
	}

	return result
}

// calculateInternalReward calculates the internal reward for the deposit.
// It calls rewardPerWarmup for each rewardCache interval, applies warmup, and returns the rewards and penalties.
func (self *RewardState) calculateInternalReward(startTime, endTime int64) ([]int64, []int64) {
	currentReward := self.pool.CurrentReward(startTime)
	self.pool.rewardCache.Iterate(startTime, endTime, func(key int64, value any) bool {
		// we calculate per-position reward
		err := self.rewardPerWarmup(startTime, key, currentReward)
		if err != nil {
			panic(err)
		}

		reward, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to int64: %T", value))
		}
		startTime = key
		currentReward = reward
		return false
	})

	if startTime < endTime {
		err := self.rewardPerWarmup(startTime, endTime, currentReward)
		if err != nil {
			panic(err)
		}
	}

	self.applyWarmup()

	return self.rewards, self.penalties
}

// calculateExternalReward calculates the external reward for the deposit.
// It calls rewardPerWarmup for startTime to endTime(clamped to the incentive period), applies warmup and returns the rewards and penalties.
func (self *RewardState) calculateExternalReward(startTime, endTime int64, incentive *ExternalIncentive) ([]int64, []int64) {
	if startTime < self.deposit.lastCollectTime {
		// This must not happen, but adding some guards just in case.
		startTime = self.deposit.lastCollectTime
	}

	if endTime < incentive.startTimestamp {
		return nil, nil // Not started yet
	}

	if startTime < incentive.startTimestamp {
		startTime = incentive.startTimestamp
	}

	if endTime > incentive.endTimestamp {
		endTime = incentive.endTimestamp
	}

	if startTime > incentive.endTimestamp {
		return nil, nil // Already ended
	}

	err := self.rewardPerWarmup(startTime, endTime, incentive.rewardPerSecond)
	if err != nil {
		panic(err)
	}

	self.applyWarmup()

	return self.rewards, self.penalties
}

// applyWarmup applies the warmup to the rewards and calculate penalties.
func (self *RewardState) applyWarmup() {
	for i, warmup := range self.deposit.warmups {
		refactorReward := self.rewards[i]
		self.rewards[i] = safeMulInt64(refactorReward, int64(warmup.WarmupRatio)) / 100
		self.penalties[i] = safeSubInt64(refactorReward, self.rewards[i])
	}
}

// rewardPerWarmup calculates the reward for each warmup, adds to the RewardState's rewards array.
func (self *RewardState) rewardPerWarmup(startTime, endTime int64, rewardPerSecond int64) error {
	for i, warmup := range self.deposit.warmups {
		if startTime >= warmup.NextWarmupTime {
			// passed the warmup
			continue
		}

		if endTime < warmup.NextWarmupTime {
			rewardAcc := self.pool.CalculateRewardForPosition(
				startTime,
				self.pool.CurrentTick(startTime),
				endTime,
				self.pool.CurrentTick(endTime),
				self.deposit,
			)

			rewardAcc = u256.Zero().Mul(rewardAcc, self.deposit.liquidity)
			rewardAcc = u256.MulDiv(rewardAcc, u256.NewUintFromInt64(rewardPerSecond), q128)
			self.rewards[i] += safeConvertToInt64(rewardAcc)

			break
		}

		rewardAcc := self.pool.CalculateRewardForPosition(
			startTime,
			self.pool.CurrentTick(startTime),
			warmup.NextWarmupTime,
			self.pool.CurrentTick(warmup.NextWarmupTime),
			self.deposit,
		)

		rewardAcc = u256.Zero().Mul(rewardAcc, self.deposit.liquidity)
		rewardAcc = u256.MulDiv(rewardAcc, u256.NewUintFromInt64(rewardPerSecond), q128)
		self.rewards[i] += safeConvertToInt64(rewardAcc)

		startTime = warmup.NextWarmupTime
	}

	return nil
}

// modifyDeposit updates the pool's staked liquidity and returns the new staked liquidity.
// updates when there is a change in the staked liquidity(tick cross, stake, unstake)
func (self *Pool) modifyDeposit(delta *i256.Int, currentTime int64, nextTick int32) *u256.Uint {
	// update staker side pool info
	lastStakedLiquidity := self.CurrentStakedLiquidity(currentTime)
	deltaApplied := liquidityMathAddDelta(lastStakedLiquidity, delta)
	result := self.updateGlobalRewardRatioAccumulation(currentTime, lastStakedLiquidity)

	// historical tick does NOT actually reflect the tick at the timestamp, but it provides correct ordering for the staked positions
	// because TickCrossHook is assured to be called for the staked-initialized ticks
	self.historicalTick.set(currentTime, nextTick)

	switch deltaApplied.Sign() {
	case -1:
		panic("stakedLiquidity is less than 0, should not happen")
	case 0:
		if lastStakedLiquidity.Sign() == 1 {
			// StakedLiquidity moved from positive to zero, start unclaimable period
			self.startUnclaimablePeriod(currentTime)
			self.incentives.startUnclaimablePeriod(currentTime)
		}
	case 1:
		if lastStakedLiquidity.Sign() == 0 {
			// StakedLiquidity moved from zero to positive, end unclaimable period
			self.endUnclaimablePeriod(currentTime)
			self.incentives.endUnclaimablePeriod(currentTime)
		}
	}

	self.stakedLiquidity.set(currentTime, deltaApplied)

	return result
}

// startUnclaimablePeriod starts the unclaimable period.
func (self *Pool) startUnclaimablePeriod(currentTime int64) {
	if self.lastUnclaimableTime == 0 {
		// We set only if it's the first time entering(0 indicates not set yet)
		self.lastUnclaimableTime = currentTime
	}
}

// endUnclaimablePeriod ends the unclaimable period.
// Accumulates to unclaimableAcc and resets lastUnclaimableTime to 0.
func (self *Pool) endUnclaimablePeriod(currentTime int64) {
	if self.lastUnclaimableTime == 0 {
		// This should not happen, but guarding just in case
		return
	}
	unclaimableDuration := currentTime - self.lastUnclaimableTime
	self.unclaimableAcc += unclaimableDuration * self.CurrentReward(self.lastUnclaimableTime)
	self.lastUnclaimableTime = 0
}

// processUnclaimableReward processes the unclaimable reward and returns the accumulated reward.
// It resets unclaimableAcc to 0 and updates lastUnclaimableTime to endTime.
func (self *Pool) processUnclaimableReward(poolTier *PoolTier, endTime int64) int64 {
	internalUnClaimable := self.unclaimableAcc
	self.unclaimableAcc = 0
	self.lastUnclaimableTime = endTime
	return internalUnClaimable
}

// Calculates reward for a position *without* considering debt or warmup
// It calculates the theoretical total reward for the position if it has been staked since the pool creation
func (self *Pool) CalculateRawRewardForPosition(currentTime int64, currentTick int32, deposit *Deposit) *u256.Uint {
	var rewardAcc *u256.Uint

	globalAcc := self.calculateGlobalRewardRatioAccumulation(currentTime, self.CurrentStakedLiquidity(currentTime))
	lowerAcc := self.ticks.Get(deposit.tickLower).CurrentOutsideAccumulation(currentTime)
	upperAcc := self.ticks.Get(deposit.tickUpper).CurrentOutsideAccumulation(currentTime)
	if currentTick < deposit.tickLower {
		rewardAcc = u256.Zero().Sub(lowerAcc, upperAcc)
	} else if currentTick >= deposit.tickUpper {
		rewardAcc = u256.Zero().Sub(upperAcc, lowerAcc)
	} else {
		rewardAcc = u256.Zero().Sub(globalAcc, lowerAcc)
		rewardAcc = rewardAcc.Sub(rewardAcc, upperAcc)
	}

	return rewardAcc
}

// Calculate actual reward in [startTime, endTime) for a position by
// subtracting the startTime's raw reward from the endTime's raw reward
func (self *Pool) CalculateRewardForPosition(
	startTime int64,
	startTick int32,
	endTime int64,
	endTick int32,
	deposit *Deposit,
) *u256.Uint {
	rewardAcc := self.CalculateRawRewardForPosition(endTime, endTick, deposit)
	debtAcc := self.CalculateRawRewardForPosition(startTime, startTick, deposit)

	return u256.Zero().Sub(rewardAcc, debtAcc)
}
