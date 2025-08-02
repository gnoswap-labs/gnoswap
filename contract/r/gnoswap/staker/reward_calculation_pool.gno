package staker

import (
	"std"

	"gno.land/p/demo/avl"

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
//   - globalRewardRatioAccumulation:
//     Global ratio of BlockNumber / TotalStake accumulation(since the pool creation)
//     Stores new entry only when tick cross or stake/unstake happens.
//     It is used to calculate the reward for a staked position at certain height.
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

	globalRewardRatioAccumulation *UintTree // uint64 blockNumber -> *u256.Uint(Q128) rewardRatioAccumulation

	historicalTick *UintTree // uint64 blockNumber -> int32 tickId

	// New fields for tracking cumulative distribution
	lastDistributedAmount int64 // Cumulative distribution amount at last update
	lastUpdateHeight      int64 // Block height of last update
}

// NewPool creates a new pool with the given poolPath and currentHeight.
func NewPool(poolPath string, currentHeight int64) *Pool {
	pool := &Pool{
		poolPath:                      poolPath,
		stakedLiquidity:               NewUintTree(),
		lastUnclaimableHeight:         currentHeight,
		unclaimableAcc:                0,
		rewardCache:                   NewUintTree(),
		incentives:                    NewIncentives(poolPath),
		ticks:                         NewTicks(),
		globalRewardRatioAccumulation: NewUintTree(),
		historicalTick:                NewUintTree(),
		lastDistributedAmount:         0,
		lastUpdateHeight:              currentHeight,
	}

	pool.globalRewardRatioAccumulation.set(currentHeight, u256.Zero())
	pool.rewardCache.set(currentHeight, int64(0))
	pool.stakedLiquidity.set(currentHeight, u256.Zero())

	return pool
}

// Get the latest global reward ratio accumulation in [0, currentHeight] range.
// Returns the height and the accumulation.
func (self *Pool) CurrentGlobalRewardRatioAccumulation(currentHeight int64) (int64, *u256.Uint) {
	var height int64
	var acc *u256.Uint
	self.globalRewardRatioAccumulation.ReverseIterate(0, currentHeight+1, func(key int64, value any) bool {
		height = key
		acc = value.(*u256.Uint)
		return true
	})
	if acc == nil {
		panic("should not happen, globalRewardRatioAccumulation must be set when pool is created")
	}
	return height, acc
}

// Get the latest tick in [0, currentHeight] range.
// Returns the tick.
func (self *Pool) CurrentTick(currentHeight int64) int32 {
	var tick int32
	self.historicalTick.ReverseIterate(0, currentHeight+1, func(key int64, value any) bool {
		tick = value.(int32)
		return true
	})
	return tick
}

func (self *Pool) CurrentStakedLiquidity(currentHeight int64) *u256.Uint {
	liquidity := u256.Zero()
	self.stakedLiquidity.ReverseIterate(0, currentHeight+1, func(key int64, value any) bool {
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
	self.rewardCache.ReverseIterate(0, currentHeight+1, func(key int64, value any) bool {
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

// cacheInternalReward caches the current emission and updates the global reward ratio accumulation using cumulative distribution method.
func (self *Pool) cacheInternalReward(currentAccuDistributedAmount int64, currentHeight int64, poolSpecificEmission int64) {
	// Cache the pool-specific emission rate for this height
	// This should match the per-block rate calculated from the cumulative distribution
	self.cacheReward(currentHeight, poolSpecificEmission)

	// Handle unclaimable periods
	currentStakedLiquidity := self.CurrentStakedLiquidity(currentHeight)
	if currentStakedLiquidity.IsZero() {
		self.endUnclaimablePeriod(currentHeight)
		self.startUnclaimablePeriod(currentHeight)
	}
	
	// NOTE: Do NOT call updateGlobalRewardRatioAccumulation here
	// It will be called later in modifyDeposit when liquidity changes
}

func (self *Pool) calculateGlobalRewardRatioAccumulation(currentAccuDistributedAmount int64, currentHeight int64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	oldAccHeight, oldAcc := self.CurrentGlobalRewardRatioAccumulation(currentHeight)
	if currentHeight <= oldAccHeight {
		return oldAcc.Clone()
	}

	if currentStakedLiquidity.IsZero() {
		return oldAcc.Clone()
	}

	// Cumulative amount method: Calculate actual reward delta
	rewardDelta := self.calculateRewardDelta(currentAccuDistributedAmount, currentHeight)
	if rewardDelta <= 0 {
		return oldAcc.Clone()
	}

	// Scale reward delta to Q128
	rewardDeltaX128 := u256.NewUintFromInt64(rewardDelta)
	rewardDeltaX128 = rewardDeltaX128.Lsh(rewardDeltaX128, 128)

	// Divide by staked liquidity to get reward per unit
	accDelta := u256.Zero().Div(rewardDeltaX128, currentStakedLiquidity)

	return u256.Zero().Add(oldAcc, accDelta)
}

// calculateRewardDelta calculates the reward delta since last update using accurate tier-based distribution
func (self *Pool) calculateRewardDelta(currentAccuDistributedAmount int64, currentHeight int64) int64 {
	// Calculate the total distributed amount delta since last update
	distributedDelta := currentAccuDistributedAmount - self.lastDistributedAmount
	if distributedDelta <= 0 {
		return 0
	}

	// Get this pool's share in basis points (0-10000 range)
	poolRatioBasisPoints := self.getPoolTierRatio()
	if poolRatioBasisPoints <= 0 {
		return 0
	}

	// Calculate this pool's reward delta using basis points
	poolRewardDelta := distributedDelta * poolRatioBasisPoints / 10000

	// Update state
	self.lastDistributedAmount = currentAccuDistributedAmount
	self.lastUpdateHeight = currentHeight

	return poolRewardDelta
}

// getPoolTierRatio gets the accurate ratio for this specific pool within its tier
// Returns the ratio as a percentage (0-100) that this pool should receive from the total distributed amount
func (self *Pool) getPoolTierRatio() int64 {
	// poolTier is accessible as global variable
	tierNum := poolTier.CurrentTier(self.poolPath)
	if tierNum == 0 {
		return 0 // No tier assigned
	}

	// Get the tier's total percentage allocation
	tierPercentage := int64(poolTier.tierRatio.Get(tierNum))
	poolCount := int64(poolTier.CurrentCount(tierNum))
	if poolCount == 0 {
		return 0
	}

	// Calculate this individual pool's percentage from total emission
	// Each pool in a tier gets equal share of that tier's allocation
	return tierPercentage * 100 / poolCount // Return in basis points (0-10000)
}

// updateGlobalRewardRatioAccumulation updates the global reward ratio accumulation and returns the new accumulation.
func (self *Pool) updateGlobalRewardRatioAccumulation(currentAccuDistributedAmount int64, currentHeight int64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	newAcc := self.calculateGlobalRewardRatioAccumulation(currentAccuDistributedAmount, currentHeight, currentStakedLiquidity)

	self.globalRewardRatioAccumulation.set(currentHeight, newAcc)
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
func (self *RewardState) calculateInternalReward(currentAccuDistributedAmount int64, startHeight, endHeight int64) ([]int64, []int64) {
	// Don't use rewardPerBlock in cumulative amount method
	// Actual rewards are already reflected in Pool's globalRewardRatioAccumulation
	self.rewardPerWarmup(currentAccuDistributedAmount, startHeight, endHeight, 0) // rewardPerBlock is no longer used

	self.applyWarmup()

	return self.rewards, self.penalties
}

// calculateExternalReward calculates the external reward for the deposit.
// It calls rewardPerWarmup for startHeight to endHeight(clamped to the incentive period), applies warmup and returns the rewards and penalties.
func (self *RewardState) calculateExternalReward(currentAccuDistributedAmount int64, startHeight, endHeight int64, incentive *ExternalIncentive) ([]int64, []int64) {
	if startHeight < int64(self.deposit.lastCollectHeight) {
		// This must not happen, but adding some guards just in case.
		startHeight = int64(self.deposit.lastCollectHeight)
	}

	if endHeight < incentive.startHeight {
		return nil, nil // Not started yet
	}

	if startHeight < incentive.startHeight {
		startHeight = incentive.startHeight
	}

	if endHeight > incentive.endHeight {
		endHeight = incentive.endHeight
	}

	if startHeight > incentive.endHeight {
		return nil, nil // Already ended
	}

	rewardPerBlock := incentive.rewardPerBlock

	self.rewardPerWarmup(currentAccuDistributedAmount, startHeight, endHeight, rewardPerBlock)

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
func (self *RewardState) rewardPerWarmup(currentAccuDistributedAmount int64, startHeight, endHeight int64, rewardPerBlock int64) {
	for i, warmup := range self.deposit.warmups {
		if startHeight >= warmup.NextWarmupHeight {
			// passed the warmup
			continue
		}

		if endHeight < warmup.NextWarmupHeight {
			rewardAcc := self.pool.CalculateRewardForPosition(
				currentAccuDistributedAmount,
				startHeight,
				self.pool.CurrentTick(startHeight),
				endHeight,
				self.pool.CurrentTick(endHeight),
				self.deposit,
			)
			rewardAcc = u256.Zero().Mul(rewardAcc, self.deposit.liquidity)
			rewardAcc = u256.Zero().Div(rewardAcc, q128)
			self.rewards[i] += int64(rewardAcc.Uint64())
			// done
			break
		}

		rewardAcc := self.pool.CalculateRewardForPosition(
			currentAccuDistributedAmount,
			startHeight,
			self.pool.CurrentTick(startHeight),
			warmup.NextWarmupHeight,
			self.pool.CurrentTick(warmup.NextWarmupHeight),
			self.deposit,
		)
		rewardAcc = u256.Zero().Mul(rewardAcc, self.deposit.liquidity)
		rewardAcc = u256.Zero().Div(rewardAcc, q128)
		self.rewards[i] += int64(rewardAcc.Uint64())

		startHeight = warmup.NextWarmupHeight
	}
}

// modifyDeposit updates the pool's staked liquidity and returns the new staked liquidity.
// updates when there is a change in the staked liquidity(tick cross, stake, unstake)
func (self *Pool) modifyDeposit(currentAccuDistributedAmount int64, delta *i256.Int, currentHeight int64, nextTick int32) *u256.Uint {
	// Get current staked liquidity before modification
	lastStakedLiquidity := self.CurrentStakedLiquidity(currentHeight)
	
	// Update global reward ratio accumulation BEFORE modifying liquidity
	// This ensures rewards are calculated based on the previous liquidity state
	result := self.updateGlobalRewardRatioAccumulation(currentAccuDistributedAmount, currentHeight, lastStakedLiquidity)
	
	// Apply liquidity delta to get new staked liquidity
	deltaApplied := liquidityMathAddDelta(lastStakedLiquidity, delta)

	// historical tick does NOT actually reflect the tick at the blockNumber, but it provides correct ordering for the staked positions
	// because TickCrossHook is assured to be called for the staked-initialized ticks
	self.historicalTick.set(currentHeight, nextTick)

	// Handle unclaimable period transitions based on liquidity changes
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

	// Update the staked liquidity with the new value
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
func (self *Pool) CalculateRawRewardForPosition(currentAccuDistributedAmount int64, currentHeight int64, currentTick int32, deposit *Deposit) *u256.Uint {
	var rewardAcc *u256.Uint

	globalAcc := self.calculateGlobalRewardRatioAccumulation(currentAccuDistributedAmount, currentHeight, self.CurrentStakedLiquidity(currentHeight))
	lowerAcc := self.ticks.Get(deposit.tickLower).CurrentOutsideAccumulation(currentHeight)
	upperAcc := self.ticks.Get(deposit.tickUpper).CurrentOutsideAccumulation(currentHeight)
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

// Calculate actual reward in [startHeight, endHeight) for a position by
// subtracting the startHeight's raw reward from the endHeight's raw reward
func (self *Pool) CalculateRewardForPosition(
	currentAccuDistributedAmount int64,
	startHeight int64, startTick int32,
	endHeight int64, endTick int32,
	deposit *Deposit,
) *u256.Uint {
	rewardAcc := self.CalculateRawRewardForPosition(currentAccuDistributedAmount, endHeight, endTick, deposit)

	debtAcc := self.CalculateRawRewardForPosition(
		currentAccuDistributedAmount, startHeight, startTick, deposit,
	)

	rewardAcc = rewardAcc.Sub(rewardAcc, debtAcc)

	return rewardAcc
}

// ====== Validation Functions for Cumulative Distribution Accuracy ======

// ValidateRewardConsistency checks if the reward calculation is consistent between PoolTier and Pool levels
func (self *Pool) ValidateRewardConsistency(currentAccuDistributedAmount int64, emissionInInterval int64) bool {
	// Get pool's tier information
	tierNum := poolTier.CurrentTier(self.poolPath)
	if tierNum == 0 {
		return true // No tier, no need to validate
	}

	// Calculate expected reward using PoolTier logic
	tierPercentage := int64(poolTier.tierRatio.Get(tierNum))
	poolCount := int64(poolTier.CurrentCount(tierNum))
	expectedPoolEmission := emissionInInterval * tierPercentage / 100 / poolCount

	// Calculate actual reward using Pool logic
	distributedDelta := currentAccuDistributedAmount - self.lastDistributedAmount
	poolRatioBasisPoints := self.getPoolTierRatio()
	actualPoolReward := distributedDelta * poolRatioBasisPoints / 10000

	// For debugging: check if calculations are close (allowing small rounding differences)
	diff := expectedPoolEmission - actualPoolReward
	if diff < 0 {
		diff = -diff
	}
	
	// Allow 1% tolerance for rounding differences
	tolerance := expectedPoolEmission / 100
	if tolerance == 0 {
		tolerance = 1
	}
	
	return diff <= tolerance
}

// GetPoolRewardCalculationInfo returns detailed information for debugging reward calculations
func (self *Pool) GetPoolRewardCalculationInfo(currentAccuDistributedAmount int64) (
	tierNum uint64,
	tierPercentage int64,
	poolCount int64,
	distributedDelta int64,
	poolRatioBasisPoints int64,
	calculatedReward int64,
) {
	tierNum = poolTier.CurrentTier(self.poolPath)
	if tierNum == 0 {
		return 0, 0, 0, 0, 0, 0
	}
	
	tierPercentage = int64(poolTier.tierRatio.Get(tierNum))
	poolCount = int64(poolTier.CurrentCount(tierNum))
	distributedDelta = currentAccuDistributedAmount - self.lastDistributedAmount
	poolRatioBasisPoints = self.getPoolTierRatio()
	calculatedReward = distributedDelta * poolRatioBasisPoints / 10000
	
	return tierNum, tierPercentage, poolCount, distributedDelta, poolRatioBasisPoints, calculatedReward
}

// ValidateAccumulationUpdate checks if the reward accumulation update is correct
func (self *Pool) ValidateAccumulationUpdate(
	beforeAcc *u256.Uint,
	afterAcc *u256.Uint,
	rewardDelta int64,
	stakedLiquidity *u256.Uint,
) bool {
	if stakedLiquidity.IsZero() {
		// When no liquidity, accumulation should not change
		return beforeAcc.Cmp(afterAcc) == 0
	}
	
	// Calculate expected accumulation delta
	rewardDeltaX128 := u256.NewUintFromInt64(rewardDelta)
	rewardDeltaX128 = rewardDeltaX128.Lsh(rewardDeltaX128, 128)
	expectedAccDelta := u256.Zero().Div(rewardDeltaX128, stakedLiquidity)
	
	// Calculate actual accumulation delta
	actualAccDelta := u256.Zero().Sub(afterAcc, beforeAcc)
	
	// Check if they match (allowing for rounding differences)
	return expectedAccDelta.Cmp(actualAccDelta) == 0
}

// ====== End of Validation Functions ======
