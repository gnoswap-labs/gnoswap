package staker

// "Canonical" implementation of reward calculation.
// Used for testing and reference.

import (
	"errors"
	"math"
	"std"
	"testing"

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
}

func (self *canonicalPool) InternalReward(emission uint64, ratio *TierRatio) uint64 {
	switch self.tier {
	case 0:
		return 0
	case 1:
		return emission * ratio.Tier1 / 100
	case 2:
		return emission * ratio.Tier2 / 100
	case 3:
		return emission * ratio.Tier3 / 100
	default:
		panic("invalid tier")
	}
}

func (self *canonicalPool) ExternalReward(currentHeight int) map[string]uint64 {
	reward := make(map[string]uint64)

	for _, incentive := range self.incentive {
		if incentive.startHeight > int64(currentHeight) || incentive.endHeight < int64(currentHeight) {
			continue
		}

		reward[incentive.rewardToken] += incentive.rewardPerBlock
	}

	return reward
}

type canonicalRewardState struct {
	t *testing.T

	global *emulatedGlobalState

	Pool          map[string]*canonicalPool
	tickCrossHook func(poolPath string, tickId int32, zeroForOne bool)

	Reward [][]Reward // blockNumber -> depositId -> reward

	emissionUpdates *UintTree

	MsPerBlock       int64
	PerBlockEmission uint64

	CurrentTimestamp int64
}

func NewCanonicalRewardState(t *testing.T, poolTier *PoolTier, pools *Pools, deposits *Deposits, tickCrossHook func(pools *Pools, height func() int64) func(poolPath string, tickId int32, zeroForOne bool)) *canonicalRewardState {
	result := &canonicalRewardState{
		t: t,
		global: &emulatedGlobalState{
			poolTier: poolTier,
			pools:    pools,
			deposits: deposits,
		},
		Pool:             make(map[string]*canonicalPool),
		Reward:           make([][]Reward, 0),
		emissionUpdates:  NewUintTree(),
		MsPerBlock:       1000,
		PerBlockEmission: 1000000000,
		CurrentTimestamp: 0,
	}
	result.tickCrossHook = tickCrossHook(pools, func() int64 {
		return int64(result.CurrentHeight())
	})

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

func (self *canonicalRewardState) EmissionUpdates(startHeight uint64, endHeight uint64) ([]uint64, []uint64) {
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)
	self.emissionUpdates.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
		heights = append(heights, key)
		updates = append(updates, value.(uint64))
		return false
	})

	return heights, updates
}

func (self *canonicalRewardState) SetEmissionUpdate(emission uint64) {
	self.emissionUpdates.Set(uint64(self.CurrentHeight()), emission)
	self.PerBlockEmission = emission
}

func (self *canonicalRewardState) LiquidityPerPool() (map[string]*u256.Uint) {
	liquidity := make(map[string]*u256.Uint)
	self.global.deposits.Iterate(0, math.MaxUint64, func(tokenId uint64, deposit *Deposit) bool {
		if deposit.liquidity.IsZero() { // removed deposit
			return false
		}

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

func (self *canonicalRewardState) InternalRewardPerPool(emission uint64) map[string]uint64 {
	reward := make(map[string]uint64)
	tierCount := []uint64{0, 0, 0, 0}

	for _, pool := range self.Pool {
		tierCount[pool.tier]++
	}
	ratio := TierRatioFromCounts(tierCount[1], tierCount[2], tierCount[3])

	for _, pool := range self.Pool {
		reward[pool.poolPath] = pool.InternalReward(emission, ratio)
	}

	return reward
}

func (self *canonicalRewardState) ExternalRewardPerPool(currentHeight int) map[string]map[string]uint64 {
	reward := make(map[string]map[string]uint64)

	for _, pool := range self.Pool {
		reward[pool.poolPath] = pool.ExternalReward(currentHeight)
	}

	return reward
}

func (self *canonicalRewardState) CurrentHeight() int {
	return len(self.Reward)
}

// Process block with canonical reward calculation
func (self *canonicalRewardState) CalculateCanonicalReward() []Reward {
	currentHeight := self.CurrentHeight() + 1
	rewards := make([]Reward, self.global.deposits.Size())

	liquidityPerPool := self.LiquidityPerPool()
	internalRewardPerPool := self.InternalRewardPerPool(self.PerBlockEmission)
	externalRewardPerPool := self.ExternalRewardPerPool(currentHeight)

	for i := 0; i < self.global.deposits.Size(); i++ {
		deposit := self.global.deposits.Get(uint64(i))
		if deposit.liquidity.IsZero() { // removed deposit
			continue
		}
		if !self.isInRange(deposit) {
			continue
		}

		warmup := deposit.warmups[deposit.FindWarmup(int64(currentHeight))]
		internal, internalPenalty := warmup.Apply(internalRewardPerPool[deposit.targetPoolPath], deposit.liquidity, liquidityPerPool[deposit.targetPoolPath])
		poolExternals := externalRewardPerPool[deposit.targetPoolPath]
		externals := make(map[string]uint64)
		externalPenalties := make(map[string]uint64)
		for key, value := range poolExternals {
			external, externalPenalty := warmup.Apply(value, deposit.liquidity, liquidityPerPool[deposit.targetPoolPath])
			externals[key] = external
			externalPenalties[key] = externalPenalty
		}
		rewards[i] = Reward{
			Internal:        internal,
			External:        externals,
			InternalPenalty: internalPenalty,
			ExternalPenalty: externalPenalties,
		}
	}

	return rewards
}

func (self *canonicalRewardState) NextBlock() {
	self.Reward = append(self.Reward, self.CalculateCanonicalReward())
	self.CurrentTimestamp += self.MsPerBlock
}

func (self *canonicalRewardState) NextBlockNoCanonical() {
	self.Reward = append(self.Reward, nil) // just placeholder
}

func (self *canonicalRewardState) CanonicalRewardOf(depositId uint64) Reward {
	return self.Reward[self.CurrentHeight()-1][depositId]
}

func (self *canonicalRewardState) CanonicalRewardOfHeight(depositId uint64, height uint64) Reward {
	return self.Reward[height][depositId]
}

func (self *canonicalRewardState) EmulateCalcPositionReward(tokenId uint64) ([]uint64, []uint64, []map[string]uint64, []map[string]uint64) {
	currentHeight := uint64(self.CurrentHeight())
	emissionUpdateHeights, emissionUpdates := self.EmissionUpdates(*self.global.poolTier.lastRewardCacheHeight, currentHeight)
	deposits := self.global.deposits
	pools := self.global.pools
	poolTier := self.global.poolTier

	// cache per-tier and per-pool rewards
	poolTier.cacheReward(currentHeight, emissionUpdateHeights, emissionUpdates)

	deposit := deposits.Get(tokenId)
	poolPath := deposit.targetPoolPath

	pool, ok := pools.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, currentHeight)
		pools.Set(poolPath, pool)
	}

	pool.cacheInternalReward(poolTier, currentHeight)
	pool.cacheExternalReward(currentHeight)

	// eligible(in-range) intervals for a position
	upperTick := pool.ticks.Get(deposit.tickUpper)
	lowerTick := pool.ticks.Get(deposit.tickLower)

	lastCollectHeight := deposit.lastCollectHeight

	initialUpperCross := upperTick.previousCross(lastCollectHeight)
	initialLowerCross := lowerTick.previousCross(lastCollectHeight)

	currentlyInRange := initialUpperCross && !initialLowerCross

	tickUpperCrosses := upperTick.crossInfo(lastCollectHeight, currentHeight)
	tickLowerCrosses := lowerTick.crossInfo(lastCollectHeight, currentHeight)

	internalRewards, internalPenalties := pool.InternalRewardOf(deposit).Calculate(int64(lastCollectHeight), int64(currentHeight), currentlyInRange, tickUpperCrosses, tickLowerCrosses)

	externalRewards, externalPenalties := pool.ExternalRewardOf(deposit).Calculate(int64(lastCollectHeight), int64(currentHeight), currentlyInRange, tickUpperCrosses, tickLowerCrosses)

	return internalRewards, internalPenalties, externalRewards, externalPenalties
}

func (self *canonicalRewardState) EmulatedRewardOf(depositId uint64) Reward {
	// emissionUpdateHeights, emissionUpdates := self.EmissionUpdates(*self.global.poolTier.lastRewardCacheHeight, uint64(self.CurrentHeight()))

	rewards, penalties, externalRewards, externalPenalties := self.EmulateCalcPositionReward(depositId)

	deposit := self.global.deposits.Get(depositId)
	deposit.lastCollectHeight = uint64(self.CurrentHeight())

	internal := uint64(0)
	for _, reward := range rewards {
		internal += reward
	}
	internalPenalty := uint64(0)
	for _, penalty := range penalties {
		internalPenalty += penalty
	}
	external := make(map[string]uint64)
	for _, er := range externalRewards {
		for tokenId, reward := range er {
			external[tokenId] += reward
		}
	}
	externalPenalty := make(map[string]uint64)
	for _, ep := range externalPenalties {
		for tokenId, penalty := range ep {
			externalPenalty[tokenId] += penalty
		}
	}

	return Reward{
		Internal:        internal,
		InternalPenalty: internalPenalty,
		External:        external,
		ExternalPenalty: externalPenalty,
	}
}

// Emulation of gns.gno emission changes
func (self *canonicalRewardState) SetMsPerBlock(msPerBlock int64) {
	// TODO: implement
}

func (self *canonicalRewardState) SetPerBlockEmission(perBlockEmission uint64) {
	// TODO: implement
}

// Emulation of staker.gno public entrypoints
func (self *canonicalRewardState) StakeToken(tokenId uint64, targetPoolPath string, owner std.Address, tickLower int32, tickUpper int32, liquidity *u256.Uint) error {
	currentHeight := uint64(self.CurrentHeight())
	deposit := &Deposit{
		owner:             owner,
		stakeHeight:       int64(currentHeight),
		targetPoolPath:    targetPoolPath,
		tickLower:         tickLower,
		tickUpper:         tickUpper,
		liquidity:         liquidity,
		lastCollectHeight: uint64(currentHeight),
		warmups:           InstantiateWarmup(int64(currentHeight)),
	}
	canonicalPool, ok := self.Pool[deposit.targetPoolPath]
	if !ok {
		return errors.New("pool not found")
	}
	if canonicalPool.tier == 0 && len(canonicalPool.incentive) == 0 {
		return errors.New("pool has no tier or incentive")
	}

	// update global state
	self.global.deposits.Set(tokenId, deposit)
	pool, ok := self.global.pools.Get(deposit.targetPoolPath)
	if !ok {
		panic("should not happen")
	}
	signedLiquidity := i256.FromUint256(deposit.liquidity)
	if self.isInRange(deposit) {
		pool.modifyDeposit(tokenId, signedLiquidity, currentHeight)
	}
	pool.ticks.Get(deposit.tickLower).modifyDepositLower(currentHeight, canonicalPool.tick, signedLiquidity)
	pool.ticks.Get(deposit.tickUpper).modifyDepositUpper(currentHeight, canonicalPool.tick, signedLiquidity)

	return nil
}

func (self *canonicalRewardState) CollectReward(tokenId uint64) {
	// TODO: implement
}

func (self *canonicalRewardState) UnstakeToken(tokenId uint64) {
	deposit := self.global.deposits.Get(tokenId)

	currentHeight := uint64(self.CurrentHeight())

	canonicalPool, ok := self.Pool[deposit.targetPoolPath]
	if !ok {
		panic("should not happen")
	}

	// update global state
	// we will not gonna actually remove the deposit in sake of logic simplicity
	// self.global.deposits.Remove(tokenId)
	self.global.deposits.Set(tokenId, &Deposit{
		liquidity: u256.Zero(),
	})
	pool, ok := self.global.pools.Get(deposit.targetPoolPath)
	if !ok {
		panic("should not happen")
	}
	signedLiquidity := i256.FromUint256(deposit.liquidity)
	signedLiquidity = signedLiquidity.Neg(signedLiquidity)
	if self.isInRange(deposit) {
		pool.modifyDeposit(tokenId, signedLiquidity, currentHeight)
	}
	pool.ticks.Get(deposit.tickLower).modifyDepositLower(currentHeight, canonicalPool.tick, signedLiquidity)
	pool.ticks.Get(deposit.tickUpper).modifyDepositUpper(currentHeight, canonicalPool.tick, signedLiquidity)
}

func newExternalIncentiveByHeight(
	targetPoolPath string,
	rewardToken string,
	rewardAmount uint64,
	startTimestamp int64,
	endTimestamp int64,
	startHeight int64,
	endHeight int64,
	refundee std.Address,
) *ExternalIncentive {
	rewardPerBlock := rewardAmount / uint64(endHeight-startHeight)

	return &ExternalIncentive{
		targetPoolPath:   targetPoolPath,
		rewardToken:      rewardToken,
		rewardAmount:     rewardAmount,
		startTimestamp:   startTimestamp,
		endTimestamp:     endTimestamp,
		startHeight:      startHeight,
		endHeight:        endHeight,
		rewardPerBlock:   rewardPerBlock,
		refundee:         refundee,
		createdHeight:    startHeight,
		depositGnsAmount: 0,
	}
}

func (self *canonicalRewardState) CreateExternalIncentive(targetPoolPath string, rewardToken string, rewardAmount uint64, startTimestamp, endTimestamp, startHeight, endHeight int64, refundee std.Address) string {
	incentive := newExternalIncentiveByHeight(targetPoolPath, rewardToken, rewardAmount, startTimestamp, endTimestamp, startHeight, endHeight, refundee)

	// update canonical state
	pool, ok := self.Pool[targetPoolPath]
	if !ok {
		self.Pool[targetPoolPath] = &canonicalPool{
			poolPath:      targetPoolPath,
			tier:          0,
			tick:          0,
			incentive:     make([]*ExternalIncentive, 0),
			tickCrossHook: self.tickCrossHook,
		}
	}
	pool.incentive = append(pool.incentive, incentive)

	// update global state
	self.global.pools.GetOrCreate(targetPoolPath).incentives.create(refundee, incentive)

	return incentive.incentiveId
}

func (self *canonicalRewardState) EndExternalIncentive(targetPoolPath string, rewardToken string) {
	// TODO: implement
}

func (self *canonicalRewardState) ChangePoolTier(poolPath string, tier uint64) {
	// update canonical state
	pool, ok := self.Pool[poolPath]
	if !ok {
		pool = &canonicalPool{
			poolPath:      poolPath,
			tier:          tier,
			tick:          0,
			incentive:     make([]*ExternalIncentive, 0),
			tickCrossHook: self.tickCrossHook,
		}
		self.Pool[poolPath] = pool
	}
	pool.tier = tier

	// update global state
	if !self.global.pools.Has(poolPath) {
		self.global.pools.Set(poolPath, NewPool(poolPath, uint64(self.CurrentHeight())))
	}
	self.global.poolTier.changeTier(uint64(self.CurrentHeight()), poolPath, tier)
}

func (self *canonicalRewardState) CreatePool(poolPath string, initialTier uint64, initialTick int32) {
	self.Pool[poolPath] = &canonicalPool{
		poolPath:      poolPath,
		tier:          initialTier,
		tick:          initialTick,
		incentive:     make([]*ExternalIncentive, 0),
		tickCrossHook: self.tickCrossHook,
	}
	self.global.pools.Set(poolPath, NewPool(poolPath, uint64(self.CurrentHeight())))
	self.global.poolTier.changeTier(uint64(self.CurrentHeight()), poolPath, initialTier)
}

func (self *canonicalRewardState) MoveTick(poolPath string, tick int32) {
	pool, ok := self.Pool[poolPath]
	if !ok {
		panic("should not happen")
	}
	globalPool, ok := self.global.pools.Get(poolPath)
	if !ok {
		panic("should not happen")
	}

	if pool.tick == tick {
		return
	}

	self.t.Logf("tick: %d, moving to %d", pool.tick, tick)

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

func (self *canonicalRewardState) AssertCanonicalInternalRewardPerPool(poolPath string, expected uint64) {
	internalRewardPerPool := self.InternalRewardPerPool(self.PerBlockEmission)
	actual := internalRewardPerPool[poolPath]
	if actual != expected {
		panic(ufmt.Sprintf("internal reward per pool mismatch: expected %d, got %d", expected, actual))
	}
}

// returns true if actual is within 0.0001% of expected
func isInErrorRange(expected uint64, actual uint64) bool {
	maxSafeValue := uint64(math.MaxUint64 / 100001)
	var lowerBound, upperBound uint64
	if expected > maxSafeValue {
		lowerBound = expected / 1000000 * 999999
		upperBound = expected / 1000000 * 1000001
	} else {
		lowerBound = expected * 999999 / 1000000
		upperBound = expected * 1000001 / 1000000
	}
	return actual >= lowerBound && actual <= upperBound
}

func (self *canonicalRewardState) AssertEmulatedRewardOf(depositId uint64, expected uint64) {
	reward := self.EmulatedRewardOf(depositId)
	if !isInErrorRange(expected, reward.Internal) {
		self.t.Errorf("emulated reward of %d mismatch: expected %d, got %d(%s@%d)", depositId, expected, reward.Internal, self.Pool[self.global.deposits.Get(depositId).targetPoolPath].poolPath, self.Pool[self.global.deposits.Get(depositId).targetPoolPath].tick)
	}
}

func (self *canonicalRewardState) AssertEmulatedExternalRewardOf(depositId uint64, tokenId string, expected uint64) {
	reward := self.EmulatedRewardOf(depositId)
	if !isInErrorRange(expected, reward.External[tokenId]) {
		self.t.Errorf("emulated external reward of %d mismatch: expected %d, got %d", depositId, expected, reward.External[tokenId])
	}
}

func (self *canonicalRewardState) AssertCanonicalRewardOf(depositId uint64, expected uint64) {
	reward := self.CanonicalRewardOf(depositId)
	if !isInErrorRange(expected, reward.Internal) {
		self.t.Errorf("canonical reward of %d mismatch: expected %d, got %d", depositId, expected, reward.Internal)
	}
}

func (self *canonicalRewardState) AssertEquivalence(depositId uint64) {
	reward := self.CanonicalRewardOf(depositId)
	emulatedReward := self.EmulatedRewardOf(depositId)
	if !isInErrorRange(reward.Internal, emulatedReward.Internal) {
		self.t.Errorf("canonical reward of %d mismatch: expected %d, got %d", depositId, reward.Internal, emulatedReward.Internal)
	}
}

func (self *canonicalRewardState) AssertEmulatedRewardMap(expected map[uint64]uint64) {
	for key, value := range expected {
		self.AssertEmulatedRewardOf(key, value)
	}
}
