package staker

// "Canonical" implementation of reward calculation.
// Used for testing and reference.

import (
	"math"
	"std"
	"errors"
	
	ufmt "gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
	i256 "gno.land/p/gnoswap/int256"
)

type reward struct {
	internal uint64
	internalPenalty uint64
	external map[string]uint64
	externalPenalty map[string]uint64
}

type canonicalPool struct {
	poolPath string
	tier uint64
	tick int32
	incentive []*ExternalIncentive

	tickCrossHook func(poolPath string, tickId int32, zeroForOne bool)
}

func (self *canonicalPool) MoveTick(tick int32) {
	if self.tick == tick {
		return
	}

	zeroForOne := tick < self.tick // true if moving left, false if moving right
	increment := int32(1)
	if zeroForOne {
		increment = -1
	}
	for i := self.tick; i != tick; i += increment {
		// update global state
		self.tickCrossHook(self.poolPath, i, zeroForOne)
	}

	// update canonical state
	self.tick = tick
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
	global *emulatedGlobalState

	pool map[string]*canonicalPool
	tickCrossHook func(poolPath string, tickId int32, zeroForOne bool)

	reward [][]reward // blockNumber -> depositId -> reward

	emissionUpdates *UintTree

	msPerBlock int64
	perBlockEmission uint64
}

func NewCanonicalRewardState(poolTier *PoolTier, pools *Pools, ticks *Ticks, deposits *Deposits, tickCrossHook func(pools *Pools, ticks *Ticks, height func() int64) func(poolPath string, tickId int32, zeroForOne bool)) *canonicalRewardState {
	result := &canonicalRewardState{
		global: &emulatedGlobalState{
			poolTier: poolTier,
			pools: pools,
			ticks: ticks,
			deposits: deposits,
		},
		pool: make(map[string]*canonicalPool),
		reward: make([][]reward, 0),
		emissionUpdates: NewUintTree(),
		msPerBlock: 1000,
		perBlockEmission: 1000000000,
	}
	result.tickCrossHook = tickCrossHook(pools, ticks, func() int64 {
		return int64(result.CurrentHeight())
	})

	result.SetEmissionUpdate(1000000000)

	return result
}

type emulatedGlobalState struct {
	poolTier *PoolTier
	pools *Pools
	ticks *Ticks
	deposits *Deposits
}

func (self *canonicalRewardState) isInRange(deposit *Deposit) bool {
	tick := self.pool[deposit.targetPoolPath].tick
	return deposit.tickLower <= tick && tick < deposit.tickUpper
}

func (self *canonicalRewardState) EmissionUpdates(startHeight uint64, endHeight uint64) ([]uint64, []uint64) {
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)
	self.emissionUpdates.ReverseIterate(0, startHeight, func(key uint64, value interface{}) bool {
		heights = append(heights, key)
		updates = append(updates, value.(uint64))
		if key == startHeight {
			startHeight = key + 1
		}
		return true
	})

	self.emissionUpdates.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
		heights = append(heights, key)
		updates = append(updates, value.(uint64))
		return false
	})

	return heights, updates
}

func (self *canonicalRewardState) SetEmissionUpdate(emission uint64) {
	self.emissionUpdates.Set(uint64(self.CurrentHeight()), emission)
	self.perBlockEmission = emission
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

	for _, pool := range self.pool {
		tierCount[pool.tier]++
	}
	ratio := TierRatioFromCounts(tierCount[1], tierCount[2], tierCount[3])

	for _, pool := range self.pool {
		reward[pool.poolPath] = pool.InternalReward(emission, ratio)
	}

	return reward
}

func (self *canonicalRewardState) ExternalRewardPerPool(currentHeight int) map[string]map[string]uint64 {
	reward := make(map[string]map[string]uint64)

	for _, pool := range self.pool {
		reward[pool.poolPath] = pool.ExternalReward(currentHeight)
	}

	return reward
}

func (self *canonicalRewardState) CurrentHeight() int {
	return len(self.reward)
}

// Process block
func (self *canonicalRewardState) CalculateReward() {
	currentHeight := self.CurrentHeight() + 1
	rewards := make([]reward, self.global.deposits.Size())
	
	liquidityPerPool := self.LiquidityPerPool()
	internalRewardPerPool := self.InternalRewardPerPool(self.perBlockEmission)
	externalRewardPerPool := self.ExternalRewardPerPool(currentHeight)

	for i := 0; i < self.global.deposits.Size(); i++ {
		deposit := self.global.deposits.Get(uint64(i))
		if deposit.liquidity.IsZero() { // removed deposit
			continue
		}
		if !self.isInRange(deposit) {
			continue
		}

		warmup := deposit.warmups[deposit.FindWarmup(uint64(currentHeight))]
		
		internal, internalPenalty := warmup.CalculateReward(uint64(currentHeight), internalRewardPerPool[deposit.targetPoolPath], deposit.liquidity, liquidityPerPool[deposit.targetPoolPath])
		poolExternals := externalRewardPerPool[deposit.targetPoolPath]
		externals := make(map[string]uint64)
		externalPenalties := make(map[string]uint64)
		for key, value := range poolExternals {
			external, externalPenalty := warmup.CalculateReward(uint64(currentHeight), value, deposit.liquidity, liquidityPerPool[deposit.targetPoolPath])
			externals[key] = external
			externalPenalties[key] = externalPenalty
		}
		rewards[i] = reward {
			internal: internal, 
			external: externals,
			internalPenalty: internalPenalty,
			externalPenalty: externalPenalties,
		}
	}

	self.reward = append(self.reward, rewards)
}

func (self *canonicalRewardState) CanonicalRewardOf(depositId uint64) reward {
	return self.reward[self.CurrentHeight() - 1][depositId]
}

func (self *canonicalRewardState) EmulatedRewardOf(depositId uint64) reward {
	emissionUpdateHeights, emissionUpdates := self.EmissionUpdates(*self.global.poolTier.lastRewardCacheHeight, uint64(self.CurrentHeight()))

	rewards, penalties := CalcPositionReward(uint64(self.CurrentHeight()), depositId, self.global.deposits, self.global.pools, self.global.ticks, self.global.poolTier, emissionUpdateHeights, emissionUpdates)

	internal := uint64(0)
	for _, reward := range rewards {
		internal += reward
	}
	internalPenalty := uint64(0)
	for _, penalty := range penalties {
		internalPenalty += penalty
	}
	return reward {
		internal: internal,
		internalPenalty: internalPenalty,
		external: nil,
		externalPenalty: nil,
	}
}

// Emulation of gns.gno emission changes
func (self *canonicalRewardState) SetMsPerBlock(msPerBlock int64) () {
	// TODO: implement
}

func (self *canonicalRewardState) SetPerBlockEmission(perBlockEmission uint64) () {
	// TODO: implement
}

// Emulation of staker.gno public entrypoints
func (self *canonicalRewardState) StakeToken(tokenId uint64, targetPoolPath string, owner std.Address, tickLower int32, tickUpper int32, liquidity *u256.Uint) error {
	currentHeight := uint64(self.CurrentHeight())
	deposit := &Deposit{
		owner: owner,
		stakeHeight: int64(currentHeight),
		targetPoolPath: targetPoolPath,
		tickLower: tickLower,
		tickUpper: tickUpper,
		liquidity: liquidity,
		lastCollectHeight: uint64(currentHeight),
		warmups: DefaultWarmups(uint64(currentHeight), uint64(self.msPerBlock)),
	}
	canonicalPool, ok := self.pool[deposit.targetPoolPath]
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
	self.global.ticks.Get(deposit.tickLower).modifyDepositLower(currentHeight, canonicalPool.tick, signedLiquidity)
	self.global.ticks.Get(deposit.tickUpper).modifyDepositUpper(currentHeight, canonicalPool.tick, signedLiquidity)

	return nil
}

func (self *canonicalRewardState) CollectReward(tokenId uint64) {
	// TODO: implement
}

func (self *canonicalRewardState) UnstakeToken(tokenId uint64) {
	deposit := self.global.deposits.Get(tokenId)

	currentHeight := uint64(self.CurrentHeight())

	canonicalPool, ok := self.pool[deposit.targetPoolPath]
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
	self.global.ticks.Get(deposit.tickLower).modifyDepositLower(currentHeight, canonicalPool.tick, signedLiquidity)
	self.global.ticks.Get(deposit.tickUpper).modifyDepositUpper(currentHeight, canonicalPool.tick, signedLiquidity)
}

func (self *canonicalRewardState) CreateExternalIncentive(targetPoolPath string, rewardToken string, rewardAmount uint64, startTimestamp int64, endTimestamp int64, refundee std.Address, createdHeight int, depositGnsAmount uint64, currentTime int64) {
	incentive := NewExternalIncentive(targetPoolPath, rewardToken, rewardAmount, startTimestamp, endTimestamp, refundee, int64(createdHeight), depositGnsAmount, self.msPerBlock, currentTime)

	// update canonical state
	pool, ok := self.pool[targetPoolPath]
	if !ok {
		self.pool[targetPoolPath] = &canonicalPool{
			poolPath: targetPoolPath,
			tier: 0,
			tick: 0,
			incentive: make([]*ExternalIncentive, 0),
			tickCrossHook: self.tickCrossHook,
		}
	}
	pool.incentive = append(pool.incentive, incentive)

	// update global state
	self.global.pools.GetOrCreate(targetPoolPath).incentives.add(refundee, incentive)
}

func (self *canonicalRewardState) EndExternalIncentive(targetPoolPath string, rewardToken string) {
	// TODO: implement
}

func (self *canonicalRewardState) ChangePoolTier(poolPath string, tier uint64) {
	// update canonical state
	pool, ok := self.pool[poolPath]
	if !ok {
		pool = &canonicalPool{
			poolPath: poolPath,
			tier: tier,
			tick: 0,
			incentive: make([]*ExternalIncentive, 0),
			tickCrossHook: self.tickCrossHook,
		}
		self.pool[poolPath] = pool
	}
	pool.tier = tier
	
	// update global state
	if !self.global.pools.Has(poolPath) {
		self.global.pools.Set(poolPath, NewPool(poolPath, uint64(self.CurrentHeight())))
	}
	self.global.poolTier.changeTier(uint64(self.CurrentHeight()), poolPath, tier)
}

func (self *canonicalRewardState) CreatePool(poolPath string, initialTier uint64, initialTick int32) {
	self.pool[poolPath] = &canonicalPool{
		poolPath: poolPath,
		tier: initialTier,
		tick: initialTick,
		incentive: make([]*ExternalIncentive, 0),
		tickCrossHook: self.tickCrossHook,
	}
	self.global.pools.Set(poolPath, NewPool(poolPath, uint64(self.CurrentHeight())))
	self.global.poolTier.changeTier(uint64(self.CurrentHeight()), poolPath, initialTier)
}

func (self *canonicalRewardState) MoveTick(poolPath string, tick int32) {
	pool, ok := self.pool[poolPath]
	if !ok {
		panic("should not happen")
	}
	pool.MoveTick(tick)
}

// Testing helpers

func (self *canonicalRewardState) AssertCanonicalInternalRewardPerPool(poolPath string, expected uint64) {
	internalRewardPerPool := self.InternalRewardPerPool(self.perBlockEmission)
	actual := internalRewardPerPool[poolPath]
	if actual != expected {
		panic(ufmt.Sprintf("internal reward per pool mismatch: expected %d, got %d", expected, actual))
	}
}
