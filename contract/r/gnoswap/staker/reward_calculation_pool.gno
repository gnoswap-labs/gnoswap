package staker

import (
	"std"

	"gno.land/p/demo/avl"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
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
	return v.(*Pool), true
}

// GetOrCreate returns the pool for the given poolPath, or creates a new pool if it does not exist
func (self *Pools) GetOrCreate(poolPath string) *Pool {
	pool, ok := self.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, std.ChainHeight())
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
//   - lastUnclaimableHeight:
//     The height at which the unclaimable period started.
//     Set to 0 when the pool is not in an unclaimable period.
//
//   - unclaimableAcc:
//     The accumulated undisributed unclaimable reward.
//     Reset to 0 when processUnclaimableReward is called and sent to community pool.
//
//   - rewardCache:
//     The cached per-block reward emitted for this pool.
//     Stores new entry only when the reward is changed.
//     PoolTier.cacheReward() updates this.
//
// - incentives: The external incentives associated with the pool.
//
// - ticks: The Ticks associated with the pool.
//
//   - globalRewardAccumulation:
//     Global accumulation of actual reward per liquidity (since the pool creation)
//     Stores new entry only when tick cross or stake/unstake happens.
//     It is used to calculate the reward for a staked position at certain height.
//     Formula: accumulation += (pool_specific_reward) / total_staked_liquidity * Q128
//
//   - historicalTick:
//     The historical tick for the pool at a given height.
//     It does not reflect the exact tick at the blockNumber,
//     but it provides correct ordering for the staked position's ticks.
//     Therefore, you should not compare it for equality, only for ordering.
//     Set when tick cross happens or a new position is created.
type Pool struct {
	poolPath string

	stakedLiquidity *UintTree // uint64 blockNumber -> *u256.Uint(Q128)

	lastUnclaimableHeight int64
	unclaimableAcc        int64

	rewardCache *UintTree // uint64 blockNumber -> int64 gnsReward

	incentives Incentives

	ticks Ticks // int32 tickId -> Tick tick

	globalRewardAccumulation *UintTree // uint64 blockNumber -> *u256.Uint(Q128) rewardRatioAccumulation

	historicalTick *UintTree // uint64 blockNumber -> int32 tickId
}

// NewPool creates a new pool with the given poolPath and currentHeight.
func NewPool(poolPath string, currentHeight int64) *Pool {
	pool := &Pool{
		poolPath:                 poolPath,
		stakedLiquidity:          NewUintTree(),
		lastUnclaimableHeight:    currentHeight,
		unclaimableAcc:           0,
		rewardCache:              NewUintTree(),
		incentives:               NewIncentives(poolPath),
		ticks:                    NewTicks(),
		globalRewardAccumulation: NewUintTree(),
		historicalTick:           NewUintTree(),
	}

	pool.globalRewardAccumulation.set(currentHeight, u256.Zero())
	pool.rewardCache.set(currentHeight, int64(0))
	pool.stakedLiquidity.set(currentHeight, u256.Zero())

	return pool
}

// Get the latest global reward accumulation in [0, currentHeight] range.
// Returns the height and the accumulation.
func (self *Pool) CurrentGlobalRewardAccumulation(currentHeight int64) (int64, *u256.Uint) {
	var height int64
	var acc *u256.Uint
	self.globalRewardAccumulation.ReverseIterate(0, currentHeight, func(key int64, value any) bool {
		height = key
		acc = value.(*u256.Uint)
		return true
	})
	if acc == nil {
		panic("should not happen, globalRewardAccumulation must be set when pool is created")
	}
	return height, acc
}

// Get the latest tick in [0, currentHeight] range.
// Returns the tick.
func (self *Pool) CurrentTick(currentHeight int64) int32 {
	var tick int32
	self.historicalTick.ReverseIterate(0, currentHeight, func(key int64, value any) bool {
		tick = value.(int32)
		return true
	})
	return tick
}

func (self *Pool) CurrentStakedLiquidity(currentHeight int64) *u256.Uint {
	liquidity := u256.Zero()
	self.stakedLiquidity.ReverseIterate(0, currentHeight, func(key int64, value any) bool {
		liquidity = value.(*u256.Uint)
		return true
	})
	return liquidity
}

// IsExternallyIncentivizedPool returns true if the pool has any external incentives.
func (self *Pool) IsExternallyIncentivizedPool() bool {
	return self.incentives.incentives.Size() > 0
}

// Get the latest reward in [0, currentHeight] range.
// Returns the reward.
func (self *Pool) CurrentReward(currentHeight int64) int64 {
	var reward int64
	self.rewardCache.ReverseIterate(0, currentHeight, func(key int64, value any) bool {
		reward = value.(int64)
		return true
	})
	return reward
}

// cacheReward sets the current reward for the pool
// If the pool is in unclaimable period, it will end the unclaimable period,  updates the reward, and start the unclaimable period again.
func (self *Pool) cacheReward(currentHeight int64, currentTierReward int64) {
	oldTierReward := self.CurrentReward(currentHeight)
	if oldTierReward == currentTierReward {
		return
	}

	isInUnclaimable := self.CurrentStakedLiquidity(currentHeight).IsZero()
	if isInUnclaimable {
		self.endUnclaimablePeriod(currentHeight)
	}

	self.rewardCache.set(currentHeight, currentTierReward)

	if isInUnclaimable {
		self.startUnclaimablePeriod(currentHeight)
	}
}

// cacheInternalReward updates the global reward accumulation based on the pool-specific reward from PoolTier.
func (self *Pool) cacheInternalReward(currentHeight int64, poolReward int64) {
	// Cache the reward amount for reference (needed for unclaimable period calculation)
	self.cacheReward(currentHeight, poolReward)

	currentStakedLiquidity := self.CurrentStakedLiquidity(currentHeight)
	if currentStakedLiquidity.IsZero() {
		self.endUnclaimablePeriod(currentHeight)
		self.startUnclaimablePeriod(currentHeight)
		// Set accumulation to previous value when no liquidity
		oldAccHeight, oldAcc := self.CurrentGlobalRewardAccumulation(currentHeight)
		if currentHeight > oldAccHeight {
			self.globalRewardAccumulation.set(currentHeight, oldAcc)
		}
		return
	}

	// Update accumulation based on the pool-specific reward from PoolTier
	self.updateGlobalRewardRatioAccumulation(currentHeight, currentStakedLiquidity, poolReward)
}

// updateGlobalRewardRatioAccumulation updates the global reward ratio accumulation based on pool-specific reward from PoolTier.
func (self *Pool) updateGlobalRewardRatioAccumulation(currentHeight int64, currentStakedLiquidity *u256.Uint, poolReward int64) *u256.Uint {
	oldAccHeight, oldAcc := self.CurrentGlobalRewardAccumulation(currentHeight)

	// If already updated for this height, return existing accumulation
	if currentHeight == oldAccHeight {
		return oldAcc
	}

	// If no staked liquidity, no accumulation change
	if currentStakedLiquidity.IsZero() {
		self.globalRewardAccumulation.set(currentHeight, oldAcc)
		return oldAcc
	}

	// If no reward for this pool, no accumulation change
	if poolReward <= 0 {
		self.globalRewardAccumulation.set(currentHeight, oldAcc)
		return oldAcc
	}

	// Use the pool-specific reward from PoolTier (already calculated per pool)
	totalReward := u256.NewUintFromInt64(poolReward)

	// Calculate reward per liquidity with enhanced X128 precision
	// Use MulDiv to minimize precision loss: (totalReward * Q128) / currentStakedLiquidity
	// This gives us 128-bit precision in intermediate calculation
	rewardPerLiquidity := u256.MulDiv(totalReward, q128, currentStakedLiquidity)

	// Add to existing accumulation
	newAcc := u256.Zero().Add(oldAcc, rewardPerLiquidity)

	// Update and return new accumulation
	self.globalRewardAccumulation.set(currentHeight, newAcc)
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

// modifyDeposit updates the pool's staked liquidity and returns the new accumulation.
// updates when there is a change in the staked liquidity(tick cross, stake, unstake)
func (self *Pool) modifyDeposit(delta *i256.Int, currentHeight int64, nextTick int32) *u256.Uint {
	// update staker side pool info
	lastStakedLiquidity := self.CurrentStakedLiquidity(currentHeight)
	deltaApplied := liquidityMathAddDelta(lastStakedLiquidity, delta)
	result := self.updateGlobalRewardRatioAccumulation(currentHeight, lastStakedLiquidity, 0) // Pass 0 for currentEmission as it's not a direct emission change

	// historical tick does NOT actually reflect the tick at the blockNumber, but it provides correct ordering for the staked positions
	// because TickCrossHook is assured to be called for the staked-initialized ticks
	self.historicalTick.set(currentHeight, nextTick)

	switch deltaApplied.Sign() {
	case -1:
		panic("stakedLiquidity is less than 0, should not happen")
	case 0:
		if lastStakedLiquidity.Sign() == 1 {
			// StakedLiquidity moved from positive to zero, start unclaimable period
			self.startUnclaimablePeriod(currentHeight)
			self.incentives.startUnclaimablePeriod(currentHeight)
		}
	case 1:
		if lastStakedLiquidity.Sign() == 0 {
			// StakedLiquidity moved from zero to positive, end unclaimable period
			self.endUnclaimablePeriod(currentHeight)
			self.incentives.endUnclaimablePeriod(currentHeight)
		}
	}

	self.stakedLiquidity.set(currentHeight, deltaApplied)

	return result
}

// startUnclaimablePeriod starts the unclaimable period.
func (self *Pool) startUnclaimablePeriod(currentHeight int64) {
	if self.lastUnclaimableHeight == 0 {
		// We set only if it's the first time entering(0 indicates not set yet)
		self.lastUnclaimableHeight = currentHeight
	}
}

// endUnclaimablePeriod ends the unclaimable period.
// Accumulates to unclaimableAcc and resets lastUnclaimableHeight to 0.
func (self *Pool) endUnclaimablePeriod(currentHeight int64) {
	if self.lastUnclaimableHeight == 0 {
		// This should not happen, but guarding just in case
		return
	}
	unclaimableHeights := currentHeight - self.lastUnclaimableHeight
	self.unclaimableAcc += int64(unclaimableHeights) * self.CurrentReward(self.lastUnclaimableHeight)
	self.lastUnclaimableHeight = 0
}

// processUnclaimableReward processes the unclaimable reward and returns the accumulated reward.
// It resets unclaimableAcc to 0 and updates lastUnclaimableHeight to endHeight.
func (self *Pool) processUnclaimableReward(poolTier *PoolTier, endHeight int64) int64 {
	internalUnClaimable := self.unclaimableAcc
	self.unclaimableAcc = 0
	self.lastUnclaimableHeight = endHeight
	return internalUnClaimable
}

// Calculates reward for a position *without* considering debt or warmup
// It calculates the theoretical total reward for the position if it has been staked since the pool creation
func (self *Pool) CalculateRawRewardForPosition(currentHeight int64, currentTick int32, deposit *Deposit) *u256.Uint {
	var rewardAcc *u256.Uint

	_, globalAcc := self.CurrentGlobalRewardAccumulation(currentHeight)
	lowerAcc := self.ticks.Get(deposit.tickLower).CurrentOutsideAccumulation(currentHeight)
	upperAcc := self.ticks.Get(deposit.tickUpper).CurrentOutsideAccumulation(currentHeight)

	if !isPositionInRange(currentTick, deposit.tickLower, deposit.tickUpper) {
		// Position is out-of-range, no active liquidity, no reward
		rewardAcc = u256.Zero()
	} else {
		// Position is in-range, calculate reward based on accumulation
		rewardAcc = u256.Zero().Sub(globalAcc, lowerAcc)
		rewardAcc = rewardAcc.Sub(rewardAcc, upperAcc)
	}

	return rewardAcc
}

// Calculate actual reward in [startHeight, endHeight) for a position by
// subtracting the startHeight's raw reward from the endHeight's raw reward
func (self *Pool) CalculateRewardForPosition(startHeight int64, startTick int32, endHeight int64, endTick int32, deposit *Deposit) *u256.Uint {
	rewardAcc := self.CalculateRawRewardForPosition(endHeight, endTick, deposit)

	debtAcc := self.CalculateRawRewardForPosition(startHeight, startTick, deposit)

	rewardAcc = rewardAcc.Sub(rewardAcc, debtAcc)

	return rewardAcc
}
