package staker

// "Canonical" implementation of reward calculation.
// Used for testing and reference.

import (
	"errors"
	"math"
	"std"
	"testing"

	"gno.land/p/demo/avl"
	ufmt "gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

type canonicalPool struct {
	poolPath  string
	tier      uint64
	tick      int32
	incentive []*ExternalIncentive

	tickCrossHook func(poolPath string, tickId int32, zeroForOne bool)

	// Cumulative distribution tracking for canonical test
	lastAccuDistributed int64 // Last cumulative distributed amount
	lastUpdateHeight    int64 // Last update height
}

func (self *canonicalPool) InternalReward(accuDistributed int64, currentHeight int64, ratio TierRatio, count uint64) (int64, bool) {
	// Calculate delta since last update
	distributedDelta := accuDistributed - self.lastAccuDistributed
	if distributedDelta <= 0 {
		return 0, false
	}

	// Update state
	self.lastAccuDistributed = accuDistributed
	self.lastUpdateHeight = currentHeight

	// Calculate reward based on tier using cumulative distribution method
	switch self.tier {
	case 0:
		return 0, true
	case 1:
		// Use percentage (not scaled by 100) and divide by pool count to match actual implementation
		tierAllocation := distributedDelta * int64(ratio.Tier1) / 100
		return tierAllocation / int64(count), true
	case 2:
		tierAllocation := distributedDelta * int64(ratio.Tier2) / 100
		return tierAllocation / int64(count), true
	case 3:
		tierAllocation := distributedDelta * int64(ratio.Tier3) / 100
		return tierAllocation / int64(count), true
	default:
		panic("invalid tier")
	}
}

// CalculateInternalRewardReadOnly calculates internal reward without changing state
func (self *canonicalPool) CalculateInternalRewardReadOnly(accuDistributed int64, ratio TierRatio, count uint64) int64 {
	// Calculate delta since last update
	distributedDelta := accuDistributed - self.lastAccuDistributed
	if distributedDelta <= 0 {
		return 0
	}

	// Calculate reward based on tier (without updating state) using cumulative distribution method
	switch self.tier {
	case 0:
		return 0
	case 1:
		tierAllocation := distributedDelta * int64(ratio.Tier1) / 100
		return tierAllocation / int64(count)
	case 2:
		tierAllocation := distributedDelta * int64(ratio.Tier2) / 100
		return tierAllocation / int64(count)
	case 3:
		tierAllocation := distributedDelta * int64(ratio.Tier3) / 100
		return tierAllocation / int64(count)
	default:
		panic("invalid tier")
	}
}

func (self *canonicalPool) ExternalReward(currentHeight int64) map[string]int64 {
	reward := make(map[string]int64)

	for _, incentive := range self.incentive {
		if incentive.startHeight > int64(currentHeight) || incentive.endHeight < int64(currentHeight) {
			continue
		}

		// Use incentiveId as key to match actual implementation behavior
		reward[incentive.incentiveId] += incentive.rewardPerBlock
	}

	return reward
}

type canonicalRewardState struct {
	t *testing.T

	global *emulatedGlobalState

	Pool          map[string]*canonicalPool
	tickCrossHook func(poolPath string, tickId int32, zeroForOne bool)

	Reward []map[uint64]Reward // blockNumber -> depositId -> reward

	PerBlockEmission uint64

	// emulated reward claimed by unstake
	emulatedClaimedReward map[uint64]int64

	// Cumulative distribution tracking
	accuDistributed int64 // Total accumulated distributed amount

	// Last calculated pool rewards for testing
	lastPoolRewards map[string]int64 // poolPath -> reward amount

	lastUpdateHeight int64
}

func NewCanonicalRewardState(t *testing.T, pools *Pools, deposits *Deposits, tickCrossHook func(pools *Pools, height func() int64) func(poolPath string, tickId int32, zeroForOne bool)) *canonicalRewardState {
	result := &canonicalRewardState{
		t: t,
		global: &emulatedGlobalState{
			poolTier: poolTier,
			pools:    pools,
			deposits: deposits,
		},
		Pool:             make(map[string]*canonicalPool),
		Reward:           make([]map[uint64]Reward, std.ChainHeight()),
		PerBlockEmission: 1000000000,

		emulatedClaimedReward: make(map[uint64]int64),
		accuDistributed:       0,
		lastPoolRewards:       make(map[string]int64),
		lastUpdateHeight:      std.ChainHeight(),
	}
	result.tickCrossHook = tickCrossHook(pools, func() int64 {
		return result.CurrentHeight()
	})

	// Initialize empty PoolTier for testing
	// Tests will explicitly create and configure pools as needed
	result.global.poolTier = &PoolTier{
		membership:            avl.NewTree(),
		tierRatio:             TierRatioFromCounts(0, 0, 0), // No pools initially
		lastRewardCacheHeight: result.CurrentHeight(),
		lastAccumulatedReward: result.CurrentHeight(),
		getAccumulatedReward: func() int64 {
			return result.accuDistributed
		},
	}

	result.NextBlock() // must skip height 0

	result.SetEmissionUpdate(1000000000)

	return result
}

type emulatedGlobalState struct {
	poolTier *PoolTier
	pools    *Pools
	deposits *Deposits
}

func (self *canonicalRewardState) isInRange(deposit *Deposit) bool {
	tick := self.Pool[deposit.targetPoolPath].tick
	return deposit.tickLower <= tick && tick < deposit.tickUpper
}

func (self *canonicalRewardState) SetEmissionUpdate(emission uint64) {
	self.PerBlockEmission = emission
}

func (self *canonicalRewardState) LiquidityPerPool() map[string]*u256.Uint {
	liquidity := make(map[string]*u256.Uint)
	self.global.deposits.Iterate(0, math.MaxUint64, func(positionId uint64, deposit *Deposit) bool {
		if !self.isInRange(deposit) {
			return false
		}

		poolLiquidity, ok := liquidity[deposit.targetPoolPath]
		if !ok {
			poolLiquidity = u256.Zero()
		}

		poolLiquidity = poolLiquidity.Add(poolLiquidity, deposit.liquidity)
		liquidity[deposit.targetPoolPath] = poolLiquidity
		return false
	})

	return liquidity
}

func (self *canonicalRewardState) InternalRewardPerPool(accuDistributed int64) map[string]int64 {
	reward := make(map[string]int64)
	tierCount := []uint64{0, 0, 0, 0}

	for _, pool := range self.Pool {
		tierCount[pool.tier]++
	}
	ratio := TierRatioFromCounts(tierCount[1], tierCount[2], tierCount[3])

	for _, pool := range self.Pool {
		// Use read-only calculation to avoid modifying state during testing
		internal := pool.CalculateInternalRewardReadOnly(accuDistributed, ratio, tierCount[pool.tier])
		if internal > 0 {
			reward[pool.poolPath] = internal
		}
	}

	return reward
}

func (self *canonicalRewardState) ExternalRewardPerPool(currentHeight int64) map[string]map[string]int64 {
	reward := make(map[string]map[string]int64)

	for _, pool := range self.Pool {
		reward[pool.poolPath] = pool.ExternalReward(currentHeight)
	}

	return reward
}

func (self *canonicalRewardState) CurrentHeight() int64 {
	return std.ChainHeight()
}

// Process block with canonical reward calculation
func (self *canonicalRewardState) CalculateCanonicalReward() map[uint64]Reward {
	currentHeight := self.CurrentHeight()
	rewards := make(map[uint64]Reward)

	liquidityPerPool := self.LiquidityPerPool()

	// Calculate internal reward per pool for this block only
	internalRewardPerPool := make(map[string]int64)
	tierCount := []uint64{0, 0, 0, 0}
	for _, pool := range self.Pool {
		tierCount[pool.tier]++
	}
	ratio := TierRatioFromCounts(tierCount[1], tierCount[2], tierCount[3])

	// Calculate per-block reward for each pool
	blockEmission := int64(self.PerBlockEmission)
	for _, pool := range self.Pool {
		if pool.tier > 0 {
			// Calculate this pool's share of the block emission
			tierAllocation := blockEmission * int64(ratio.Get(pool.tier)) / 100
			poolReward := tierAllocation / int64(tierCount[pool.tier])
			internalRewardPerPool[pool.poolPath] = poolReward

			// Update canonical pool state
			pool.lastAccuDistributed = self.accuDistributed
			pool.lastUpdateHeight = currentHeight
		}
	}

	externalRewardPerPool := self.ExternalRewardPerPool(int64(currentHeight))

	// Update lastPoolRewards for testing
	if self.lastUpdateHeight < self.CurrentHeight() {
		self.lastUpdateHeight = self.CurrentHeight()
		self.lastPoolRewards = internalRewardPerPool
	}

	self.global.deposits.Iterate(0, math.MaxUint64, func(positionId uint64, deposit *Deposit) bool {
		if !self.isInRange(deposit) {
			return false
		}

		warmup := deposit.warmups[deposit.FindWarmup(int64(currentHeight))]
		internal, internalPenalty := warmup.apply(internalRewardPerPool[deposit.targetPoolPath], deposit.liquidity, liquidityPerPool[deposit.targetPoolPath])
		poolExternals := externalRewardPerPool[deposit.targetPoolPath]
		externals := make(map[string]int64)
		externalPenalties := make(map[string]int64)
		// Use incentiveId as key consistently
		for incentiveId, value := range poolExternals {
			external, externalPenalty := warmup.apply(value, deposit.liquidity, liquidityPerPool[deposit.targetPoolPath])
			externals[incentiveId] = external
			externalPenalties[incentiveId] = externalPenalty
		}

		rewards[positionId] = Reward{
			Internal:        internal,
			External:        externals,
			InternalPenalty: internalPenalty,
			ExternalPenalty: externalPenalties,
		}
		return false
	})

	return rewards
}

func (self *canonicalRewardState) NextBlock() {
	// Update accumulated distribution internally instead of calling emission contract
	self.accuDistributed += int64(self.PerBlockEmission)
	testing.SkipHeights(1)

	if self.lastUpdateHeight < self.CurrentHeight() {
		self.Reward = append(self.Reward, self.CalculateCanonicalReward())
	}
}

func (self *canonicalRewardState) NextBlockNoCanonical() {
	// Update accumulated distribution internally instead of calling emission contract
	self.accuDistributed += int64(self.PerBlockEmission)
	testing.SkipHeights(1)
}

func (self *canonicalRewardState) UnclaimableExternalRewardOf(depositId uint64, incentiveId string) int64 {
	pool, ok := self.global.pools.Get(self.global.deposits.get(depositId).targetPoolPath)
	if !ok {
		panic("pool not found")
	}

	return pool.incentives.calculateUnclaimableReward(incentiveId)
}

func (self *canonicalRewardState) CanonicalRewardOf(depositId uint64) Reward {
	return self.Reward[len(self.Reward)-1][depositId]
}

func (self *canonicalRewardState) SafeCanonicalRewardOf(depositId uint64) (Reward, bool) {
	rewards := self.Reward[len(self.Reward)-1]
	reward, ok := rewards[depositId]
	return reward, ok
}

func (self *canonicalRewardState) CanonicalRewardOfHeight(depositId uint64, height uint64) Reward {
	return self.Reward[height][depositId]
}

func (self *canonicalRewardState) EmulateCalcPositionReward(positionId uint64) ([]int64, []int64, []map[string]int64, []map[string]int64) {
	deposit := self.global.deposits.get(positionId)
	poolPath := deposit.targetPoolPath

	// Get canonical pool reward for this position
	canonicalPool, ok := self.Pool[poolPath]
	if !ok {
		// Return zero rewards if pool not found
		internalRewards := make([]int64, len(deposit.warmups))
		internalPenalties := make([]int64, len(deposit.warmups))
		externalRewards := make([]map[string]int64, len(deposit.warmups))
		externalPenalties := make([]map[string]int64, len(deposit.warmups))
		for i := range externalRewards {
			externalRewards[i] = make(map[string]int64)
			externalPenalties[i] = make(map[string]int64)
		}
		return internalRewards, internalPenalties, externalRewards, externalPenalties
	}

	currentHeight := self.CurrentHeight()
	lastCollectHeight := deposit.lastCollectHeight

	// Initialize result arrays
	internalRewards := make([]int64, len(deposit.warmups))
	internalPenalties := make([]int64, len(deposit.warmups))
	externalRewards := make([]map[string]int64, len(deposit.warmups))
	externalPenalties := make([]map[string]int64, len(deposit.warmups))

	for i := range externalRewards {
		externalRewards[i] = make(map[string]int64)
		externalPenalties[i] = make(map[string]int64)
	}

	// Calculate internal rewards if pool is in a tier
	if canonicalPool.tier > 0 {
		// Use the pre-calculated pool reward from the last canonical calculation
		poolReward, ok := self.lastPoolRewards[poolPath]
		if ok && poolReward > 0 {
			// Apply to position if in range
			if self.isInRange(deposit) {
				liquidityPerPool := self.LiquidityPerPool()
				totalLiquidity := liquidityPerPool[poolPath]
				if !totalLiquidity.IsZero() {
					// Calculate position's share and apply to current warmup
					warmupIndex := deposit.FindWarmup(currentHeight)
					if warmupIndex < len(deposit.warmups) {
						warmup := deposit.warmups[warmupIndex]
						reward, penalty := warmup.apply(poolReward, deposit.liquidity, totalLiquidity)
						internalRewards[warmupIndex] = reward
						internalPenalties[warmupIndex] = penalty
					}
				}
			}
		}
	}

	// Calculate external rewards
	for _, incentive := range canonicalPool.incentive {
		if currentHeight >= incentive.startHeight && currentHeight <= incentive.endHeight && self.isInRange(deposit) {
			liquidityPerPool := self.LiquidityPerPool()
			totalLiquidity := liquidityPerPool[poolPath]
			if !totalLiquidity.IsZero() {
				// Calculate blocks elapsed since last collect (or start of incentive)
				startHeight := lastCollectHeight
				if startHeight < incentive.startHeight {
					startHeight = incentive.startHeight
				}
				endHeight := currentHeight
				if endHeight > incentive.endHeight {
					endHeight = incentive.endHeight
				}

				if endHeight > startHeight {
					blockCount := endHeight - startHeight
					totalExternalReward := blockCount * incentive.rewardPerBlock

					// Apply to current warmup
					warmupIndex := deposit.FindWarmup(currentHeight)
					if warmupIndex < len(deposit.warmups) {
						warmup := deposit.warmups[warmupIndex]
						reward, penalty := warmup.apply(totalExternalReward, deposit.liquidity, totalLiquidity)
						externalRewards[warmupIndex][incentive.incentiveId] = reward
						externalPenalties[warmupIndex][incentive.incentiveId] = penalty
					}
				}
			}
		}
	}

	return internalRewards, internalPenalties, externalRewards, externalPenalties
}

func (self *canonicalRewardState) EmulatedRewardOf(depositId uint64) Reward {
	if !self.global.deposits.Has(depositId) {
		claimed := self.emulatedClaimedReward[depositId]
		self.emulatedClaimedReward[depositId] = 0
		return Reward{
			Internal:        claimed,
			InternalPenalty: 0,
			External:        make(map[string]int64),
			ExternalPenalty: make(map[string]int64),
		}
	}

	rewards, penalties, externalRewards, externalPenalties := self.EmulateCalcPositionReward(depositId)

	internal := int64(0)
	for _, reward := range rewards {
		internal += reward
	}
	claimed, ok := self.emulatedClaimedReward[depositId]
	if ok {
		internal += claimed
		self.emulatedClaimedReward[depositId] = 0
	}
	internalPenalty := int64(0)
	for _, penalty := range penalties {
		internalPenalty += penalty
	}
	external := make(map[string]int64)
	for _, er := range externalRewards {
		for incentiveId, reward := range er {
			external[incentiveId] += reward
		}
	}
	externalPenalty := make(map[string]int64)
	for _, ep := range externalPenalties {
		for incentiveId, penalty := range ep {
			externalPenalty[incentiveId] += penalty
		}
	}

	return Reward{
		Internal:        internal,
		InternalPenalty: internalPenalty,
		External:        external,
		ExternalPenalty: externalPenalty,
	}
}

// Emulation of staker.gno public entrypoints
func (self *canonicalRewardState) StakeToken(positionId uint64, targetPoolPath string, owner std.Address, tickLower int32, tickUpper int32, liquidity *u256.Uint) error {
	currentHeight := self.CurrentHeight()
	pool, ok := self.global.pools.Get(targetPoolPath)
	if !ok {
		panic(ufmt.Sprintf("pool not found in global state: %s", targetPoolPath))
	}

	deposit := &Deposit{
		owner:             owner,
		stakeHeight:       currentHeight,
		targetPoolPath:    targetPoolPath,
		tickLower:         tickLower,
		tickUpper:         tickUpper,
		liquidity:         liquidity,
		lastCollectHeight: currentHeight,
		warmups:           instantiateWarmup(currentHeight),
	}
	canonicalPool, ok := self.Pool[deposit.targetPoolPath]
	if !ok {
		return errors.New("pool not found")
	}
	if canonicalPool.tier == 0 && len(canonicalPool.incentive) == 0 {
		return errors.New("pool has no tier or incentive")
	}

	// update global state
	self.global.deposits.set(positionId, deposit)

	self.global.poolTier.cacheReward(currentHeight, self.global.pools)

	signedLiquidity := i256.FromUint256(deposit.liquidity)
	if self.isInRange(deposit) {
		pool.modifyDeposit(signedLiquidity, currentHeight, canonicalPool.tick)
	}
	// historical tick must be set regardless of the deposit's range
	pool.historicalTick.set(currentHeight, canonicalPool.tick)

	pool.ticks.Get(deposit.tickLower).modifyDepositLower(currentHeight, canonicalPool.tick, signedLiquidity)
	pool.ticks.Get(deposit.tickUpper).modifyDepositUpper(currentHeight, canonicalPool.tick, signedLiquidity)

	return nil
}

func (self *canonicalRewardState) UnstakeToken(positionId uint64) {
	deposit := self.global.deposits.get(positionId)

	currentHeight := self.CurrentHeight()

	canonicalPool, ok := self.Pool[deposit.targetPoolPath]
	if !ok {
		panic(ufmt.Sprintf("canonical pool not found for path: %s", deposit.targetPoolPath))
	}

	// Emulating CollectReward()
	reward := self.EmulatedRewardOf(positionId)
	self.emulatedClaimedReward[positionId] += reward.Internal

	// update global state
	// we will not gonna actually remove the deposit in sake of logic simplicity
	self.global.deposits.remove(positionId)

	pool, ok := self.global.pools.Get(deposit.targetPoolPath)
	if !ok {
		panic(ufmt.Sprintf("pool not found in global state during unstake: %s", deposit.targetPoolPath))
	}
	signedLiquidity := i256.FromUint256(deposit.liquidity)
	signedLiquidity = signedLiquidity.Neg(signedLiquidity)
	if self.isInRange(deposit) {
		pool.modifyDeposit(signedLiquidity, currentHeight, canonicalPool.tick)
	}
	pool.ticks.Get(deposit.tickLower).modifyDepositLower(currentHeight, canonicalPool.tick, signedLiquidity)
	pool.ticks.Get(deposit.tickUpper).modifyDepositUpper(currentHeight, canonicalPool.tick, signedLiquidity)
}

// Simplified version - remove unused timestamp-related functionality
func newExternalIncentiveByHeight(
	targetPoolPath string,
	rewardToken string,
	rewardAmount int64,
	startHeight int64,
	endHeight int64,
	refundee std.Address,
) *ExternalIncentive {
	caller := std.OriginCaller()
	rewardPerBlock := rewardAmount / (endHeight - startHeight)

	incentiveId := nextIncentiveID(caller, startHeight)

	return &ExternalIncentive{
		incentiveId:      incentiveId,
		targetPoolPath:   targetPoolPath,
		rewardToken:      rewardToken,
		rewardAmount:     rewardAmount,
		startTimestamp:   0, // Simplified - not used in tests
		endTimestamp:     0, // Simplified - not used in tests
		startHeight:      startHeight,
		endHeight:        endHeight,
		rewardPerBlock:   rewardPerBlock,
		refundee:         refundee,
		createdHeight:    startHeight,
		depositGnsAmount: 0,
	}
}

func (self *canonicalRewardState) CreateExternalIncentive(targetPoolPath string, rewardToken string, rewardAmount int64, startHeight, endHeight int64, refundee std.Address) string {
	incentive := newExternalIncentiveByHeight(targetPoolPath, rewardToken, rewardAmount, startHeight, endHeight, refundee)

	// update canonical state
	pool, ok := self.Pool[targetPoolPath]
	if !ok {
		self.Pool[targetPoolPath] = &canonicalPool{
			poolPath:            targetPoolPath,
			tier:                0,
			tick:                0,
			incentive:           make([]*ExternalIncentive, 0),
			tickCrossHook:       self.tickCrossHook,
			lastAccuDistributed: 0, // Start from 0 to ensure rewards are calculated
			lastUpdateHeight:    self.CurrentHeight(),
		}
		pool = self.Pool[targetPoolPath]
	}
	pool.incentive = append(pool.incentive, incentive)

	// update global state
	self.global.pools.GetOrCreate(targetPoolPath).incentives.create(refundee, incentive)

	return incentive.incentiveId
}

func (self *canonicalRewardState) ChangePoolTier(poolPath string, tier uint64) {
	// update canonical state
	pool, ok := self.Pool[poolPath]
	if !ok {
		pool = &canonicalPool{
			poolPath:            poolPath,
			tier:                tier,
			tick:                0,
			incentive:           make([]*ExternalIncentive, 0),
			tickCrossHook:       self.tickCrossHook,
			lastAccuDistributed: 0, // Start from 0 to ensure rewards are calculated
			lastUpdateHeight:    self.CurrentHeight(),
		}
		self.Pool[poolPath] = pool
	}
	pool.tier = tier

	// update global state
	if !self.global.pools.Has(poolPath) {
		self.global.pools.set(poolPath, NewPool(poolPath, self.CurrentHeight()))
	}
	self.global.poolTier.changeTier(self.CurrentHeight(), self.global.pools, poolPath, tier)
}

func (self *canonicalRewardState) CreatePool(poolPath string, initialTier uint64, initialTick int32) {
	// Create canonical pool
	self.Pool[poolPath] = &canonicalPool{
		poolPath:            poolPath,
		tier:                initialTier,
		tick:                initialTick,
		incentive:           make([]*ExternalIncentive, 0),
		tickCrossHook:       self.tickCrossHook,
		lastAccuDistributed: 0, // Start from 0 to ensure rewards are calculated from first block
		lastUpdateHeight:    self.CurrentHeight(),
	}

	// Create global pool and update tier
	self.global.pools.set(poolPath, NewPool(poolPath, self.CurrentHeight()))

	// Update tier membership and recalculate ratios
	if initialTier > 0 {
		self.global.poolTier.membership.Set(poolPath, initialTier)

		// Recalculate tier ratios based on current membership
		counts := self.global.poolTier.CurrentAllTierCounts()
		self.global.poolTier.tierRatio = TierRatioFromCounts(counts[Tier1], counts[Tier2], counts[Tier3])

		// Update last distributed amount
		self.global.poolTier.lastAccumulatedReward = self.accuDistributed
	}
}

func (self *canonicalRewardState) MoveTick(poolPath string, tick int32) {
	pool, ok := self.Pool[poolPath]
	if !ok {
		panic(ufmt.Sprintf("canonical pool not found for tick movement: %s", poolPath))
	}
	globalPool, ok := self.global.pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("global pool not found for tick movement: %s", poolPath))
	}

	if pool.tick == tick {
		return
	}

	self.t.Logf("	[%d] (%d->%d) %s", self.CurrentHeight(), pool.tick, tick, pool.poolPath)

	zeroForOne := tick < pool.tick // true if moving left, false if moving right
	if zeroForOne {
		// backward
		for i := pool.tick; i > tick; i-- {
			// uninitialized tick
			if !globalPool.ticks.Has(i) {
				continue
			}

			// update global state
			pool.tickCrossHook(pool.poolPath, i, zeroForOne)
		}
	} else {
		// forward
		for i := pool.tick + 1; i <= tick; i++ {
			// uninitialized tick
			if !globalPool.ticks.Has(i) {
				continue
			}

			// update global state
			pool.tickCrossHook(pool.poolPath, i, zeroForOne)
		}
	}

	// update canonical state
	pool.tick = tick
}

// Testing helpers

func (self *canonicalRewardState) AssertCanonicalInternalRewardPerPool(poolPath string, expected int64) {
	// Use the last calculated pool rewards from CalculateCanonicalReward
	actual, ok := self.lastPoolRewards[poolPath]
	if !ok {
		actual = 0 // Pool has no rewards
	}

	if actual != expected {
		panic(ufmt.Sprintf("internal reward per pool mismatch: expected %d, got %d", expected, actual))
	}
}

func (self *canonicalRewardState) AssertEmulatedRewardOf(depositId uint64, expected uint64) {
	reward := self.EmulatedRewardOf(depositId)
	if reward.Internal < 0 {
		panic("reward cannot be negative")
	}
	if expected != uint64(reward.Internal) {
		self.t.Errorf("emulated reward of %d mismatch: expected %d, got %d", depositId, expected, reward.Internal)
		panic("emulated reward mismatch")
	}
}

func (self *canonicalRewardState) AssertEmulatedExternalRewardOf(depositId uint64, incentiveId string, expected uint64) {
	reward := self.EmulatedRewardOf(depositId)
	if reward.External[incentiveId] < 0 {
		panic("external reward cannot be negative")
	}
	if expected != uint64(reward.External[incentiveId]) {
		self.t.Errorf("!!!!emulated external reward of %d mismatch: expected %d, got %d", depositId, expected, reward.External[incentiveId])
	}
}

func (self *canonicalRewardState) AssertCanonicalRewardOf(depositId uint64, expected uint64) {
	reward := self.CanonicalRewardOf(depositId)
	if reward.Internal < 0 {
		panic("canonical reward cannot be negative")
	}
	if expected != uint64(reward.Internal) {
		self.t.Errorf("canonical reward of %d mismatch: expected %d, got %d", depositId, expected, reward.Internal)
	}
}

func (self *canonicalRewardState) AssertEquivalence(depositId uint64) {
	reward := self.CanonicalRewardOf(depositId)
	emulatedReward := self.EmulatedRewardOf(depositId)
	if reward.Internal < 0 || emulatedReward.Internal < 0 {
		panic("rewards cannot be negative")
	}
	if reward.Internal != emulatedReward.Internal {
		self.t.Errorf("canonical reward of %d mismatch: expected %d, got %d", depositId, reward.Internal, emulatedReward.Internal)
	}
}

func (self *canonicalRewardState) AssertCanonicalRewardMap(expected map[uint64]int64) {
	for key, value := range expected {
		if value < 0 {
			panic("expected reward cannot be negative")
		}
		self.AssertCanonicalRewardOf(key, uint64(value))
	}
}
