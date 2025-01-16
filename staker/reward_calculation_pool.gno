package staker

import (
	"std"

	"gno.land/p/demo/avl"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"

	en "gno.land/r/gnoswap/v1/emission"

	pl "gno.land/r/gnoswap/v1/pool"
)

var (
	// Q128 is 2^128
	q128 = u256.MustFromDecimal(consts.Q128)
	// Q192 is 2^192
	q192 = u256.MustFromDecimal("6277101735386680763835789423207666416102355444464034512895")

	// pools is the global pool storage
	pools *Pools
)

func init() {
	pools = NewPools()
}

type Pools struct {
	tree *avl.Tree // string poolPath -> pool
}

func NewPools() *Pools {
	return &Pools{
		tree: avl.NewTree(),
	}
}

func (self *Pools) Get(poolPath string) (*Pool, bool) {
	v, ok := self.tree.Get(poolPath)
	if !ok {
		return nil, false
	}
	return v.(*Pool), true
}

func (self *Pools) GetOrCreate(poolPath string, currentTick int32) *Pool {
	pool, ok := self.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, uint64(std.GetHeight()), currentTick)
		self.Set(poolPath, pool)
	}
	return pool
}

func (self *Pools) Set(poolPath string, pool *Pool) {
	self.tree.Set(poolPath, pool)
}

func (self *Pools) Has(poolPath string) bool {
	return self.tree.Has(poolPath)
}

type Pool struct {
	poolPath string

	// conceptually equal with Pool.liquidity but only for the staked positions
	// updated each time when the pool crosses a staked tick
	stakedLiquidity *UintTree // blockNumber -> *u256.Uint

	lastUnclaimableHeight *uint64
	unclaimableAcc        *uint64

	tierRewardTotal *uint64 // current total internal reward per block, used for unclaimable reward calculation

	rewardCache           *RewardCacheTree // blockNumber -> *u256.Uint
	lastRewardCacheHeight *uint64

	incentives Incentives

	ticks *Ticks

	// BlockNumber / TotalStake accumulation, Q128.
	globalRewardRatioAccumulation *UintTree // blockNumber -> *u256.Uint
	// lastGlobalRewardRatioAccumulationHeight *uint64

	historicalTick *UintTree // blockNumber -> int32
}

func NewPool(poolPath string, currentHeight uint64, currentTick int32) *Pool {
	unclaimableAcc := uint64(0)
	tierRewardTotal := uint64(0)
	// For some reason we cannot use &currentHeight directly
	// currentHeightVar := currentHeight

	pool := &Pool{
		poolPath:              poolPath,
		stakedLiquidity:       NewUintTree(),
		lastUnclaimableHeight: &currentHeight,
		unclaimableAcc:        &unclaimableAcc,
		tierRewardTotal:       &tierRewardTotal,
		rewardCache:           NewRewardCacheTree(),
		lastRewardCacheHeight: &currentHeight,
		incentives:            NewIncentives(currentHeight),
		ticks:                 NewTicks(),
		globalRewardRatioAccumulation: NewUintTree(),
		// lastGlobalRewardRatioAccumulationHeight: &currentHeightVar,
		historicalTick: NewUintTree(),
	}

	pool.globalRewardRatioAccumulation.Set(currentHeight, u256.Zero())
	pool.historicalTick.Set(currentHeight, int32(currentTick))

	return pool
}

// Returns the latest staked liquidity at the height equal or before the current height
func (self *Pool) CurrentStakedLiquidity(currentHeight uint64) *u256.Uint {
	stakedLiquidity := u256.Zero()
	self.stakedLiquidity.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		stakedLiquidity = value.(*u256.Uint)
		println("[", currentHeight, "] >>>>>>>>>>>> stakedLiquidity : ", stakedLiquidity.ToString(), ", key : ", key)
		return true
	})
	return stakedLiquidity
}

func (self *Pool) CurrentReward(currentHeight uint64) *u256.Uint {
	reward := self.rewardCache.CurrentReward(currentHeight)
	if reward == nil {
		return u256.Zero()
	}
	return reward.(*u256.Uint)
}

func (self *Pool) CurrentGlobalRewardRatioAccumulation(currentHeight uint64) (uint64, *u256.Uint) {
	var height uint64
	var acc *u256.Uint
	self.globalRewardRatioAccumulation.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		height = key
		acc = value.(*u256.Uint)
		return true
	})
	if acc == nil {
		panic("should not happen, globalRewardRatioAccumulation must be set when pool is created")
	}
	return height, acc
}

func (self *Pool) CurrentTick(currentHeight uint64) int32 {
	var tick int32
	self.historicalTick.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		tick = value.(int32)
		return true
	})
	return tick
}

// cacheReward() MUST be called before this function
func (self *Pool) IsExternallyIncentivizedPool(currentHeight uint64) bool {
	return self.incentives.byTime.Size() != 0
}

func (self *Pool) updateRewardByLiquidityChange(currentTierReward uint64, currentHeight uint64, liquidity *u256.Uint) {
	ratio := u256.NewUint(currentTierReward)
	ratio = u256.Zero().Mul(ratio, q192)
	ratio = u256.Zero().Div(ratio, liquidity)
	self.rewardCache.Set(currentHeight, ratio)

	self.incentives.updateRewardByLiquidityChange(currentHeight, liquidity)
}

func (self *Pool) cacheRewardPerLiquidityUnit(startHeight, endHeight uint64, currentTierReward uint64) {
	println("\t\t\t->cacheRewardPerLiquidityUnit Start : [", startHeight, "], [", endHeight, "], (", currentTierReward, "), lastUnclaimableHeight ", *self.lastUnclaimableHeight, ", currentTierReward : ", currentTierReward)
	// Unclaimable reward calculation uses tierRewardTotal, so we need to update it
	if *self.lastUnclaimableHeight != 0 {
		self.endInternalUnclaimablePeriod(startHeight)
		*self.tierRewardTotal = currentTierReward
		println("		->tierRewardTotal : ", *self.tierRewardTotal)
		self.startInternalUnclaimablePeriod(startHeight)
	}

	if currentTierReward == 0 {
		self.rewardCache.Set(startHeight, u256.Zero())
		return
	}

	stakedLiquidity := self.CurrentStakedLiquidity(startHeight)

	self.updateRewardByLiquidityChange(currentTierReward, startHeight, stakedLiquidity)

	self.stakedLiquidity.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		stakedLiquidity := value.(*u256.Uint)
		self.updateRewardByLiquidityChange(currentTierReward, height, stakedLiquidity)

		return false
	})
}

func (self *Pool) cacheInternalReward(currentHeight, currentEmission uint64) {
	startHeight := *self.lastRewardCacheHeight

	self.cacheRewardPerLiquidityUnit(startHeight, currentHeight, currentEmission)

	if *self.lastUnclaimableHeight != 0 && self.CurrentStakedLiquidity(currentHeight).IsZero() {
		self.endInternalUnclaimablePeriod(currentHeight)
		self.startInternalUnclaimablePeriod(currentHeight)
	}

	*self.lastRewardCacheHeight = currentHeight
	println("\t\tlastRewardCacheHeight : ", *self.lastRewardCacheHeight)

	self.updateGlobalRewardRatioAccumulation(currentHeight, self.CurrentStakedLiquidity(currentHeight))

	println("\t[", currentHeight, "] cacheInternalReward End ")
}

func (self *Pool) cacheExternalReward(endHeight uint64) {
	self.stakedLiquidity.Iterate(0, 9999999, func(key uint64, value interface{}) bool {
		return false
	})

	startHeight := *self.incentives.lastRewardCacheHeight
	currentStakedLiquidity := self.CurrentStakedLiquidity(startHeight)

	self.stakedLiquidity.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		self.incentives.cacheRewardPerLiquidityUnit(startHeight, height, currentStakedLiquidity)
		currentStakedLiquidity = value.(*u256.Uint)
		startHeight = height
		return false
	})

	self.incentives.cacheRewardPerLiquidityUnit(startHeight, endHeight, currentStakedLiquidity)

	self.incentives.rewardCache.Iterate(0, 9999999, func(key uint64, value interface{}) bool {
		return false
	})
}

func (self *Pool) calculateGlobalRewardRatioAccumulation(currentHeight uint64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	oldAccHeight, oldAcc := self.CurrentGlobalRewardRatioAccumulation(currentHeight)
	blockDiff := currentHeight - oldAccHeight
	println("	blockDiff : ", blockDiff)
	println("	oldAcc : ", oldAcc.ToString())
	if blockDiff == 0 {
		return oldAcc.Clone()
	}

	acc := u256.NewUint(blockDiff)
	acc = acc.Mul(acc, q128)
	println("	currentStakedLiquidity : ", currentStakedLiquidity.ToString())
	acc = acc.Div(acc, currentStakedLiquidity)

	println("	acc : ", acc.ToString())

	return u256.Zero().Add(oldAcc, acc)
}

// returns the old global reward ratio accumulation
func (self *Pool) updateGlobalRewardRatioAccumulation(currentHeight uint64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	println("[[updateGlobalRewardRatioAccumulation]]")
	println("	currentHeight : ", currentHeight)
	// println("	lastGlobalRewardRatioAccumulationHeight : ", *self.lastGlobalRewardRatioAccumulationHeight)

	newAcc := self.calculateGlobalRewardRatioAccumulation(currentHeight, currentStakedLiquidity)

	self.globalRewardRatioAccumulation.Set(currentHeight, newAcc)
	// *self.lastGlobalRewardRatioAccumulationHeight = currentHeight
	println("[[updateGlobalRewardRatioAccumulation]] End")
	return newAcc
}

type ExternalRewardState struct {
	pool          *Pool
	deposit       *Deposit
	incentive	  *ExternalIncentive
	currentWarmup Warmup
	rewards       []*u256.Uint
	penalties     []*u256.Uint

	refactorRewards []uint64
	refactorPenalties []uint64
}

func (self *Pool) ExternalRewardOf(deposit *Deposit, incentiveId string) *ExternalRewardState {
	incentive, ok := self.incentives.GetByIncentiveId(incentiveId)
	if !ok {
		panic("incentive not found")
	}

	result := &ExternalRewardState{
		pool:          self,
		deposit:       deposit,
		incentive:     incentive,
		currentWarmup: deposit.warmups[0],
		rewards:       make([]*u256.Uint, len(deposit.warmups)),
		penalties:     make([]*u256.Uint, len(deposit.warmups)),

		refactorRewards: make([]uint64, len(deposit.warmups)),
		refactorPenalties: make([]uint64, len(deposit.warmups)),
	}

	for i := range result.rewards {
		result.rewards[i] = u256.Zero()
		result.penalties[i] = u256.Zero()

		result.refactorRewards[i] = 0
		result.refactorPenalties[i] = 0
	}

	return result
}

func (self *ExternalRewardState) Calculate(startHeight, endHeight int64) ([]uint64, []uint64) {
	self.TickCrossesToExternalReward(startHeight, endHeight)

	//println("[[[[ self.rewards ]]]] : ", self.rewards[0].ToString(), self.rewards[1].ToString(), self.rewards[2].ToString(), self.rewards[3].ToString())
	//println("[[[[ self.penalties ]]]] : ", self.penalties[0].ToString(), self.penalties[1].ToString(), self.penalties[2].ToString(), self.penalties[3].ToString())
	println("[[[[ self.refactorRewards ]]]] : ", self.refactorRewards[0], self.refactorRewards[1], self.refactorRewards[2], self.refactorRewards[3])
	println("[[[[ self.refactorPenalties ]]]] : ", self.refactorPenalties[0], self.refactorPenalties[1], self.refactorPenalties[2], self.refactorPenalties[3])

	rewards := make([]uint64, len(self.deposit.warmups))
	penalties := make([]uint64, len(self.deposit.warmups))

	for i := range self.refactorRewards {
		rewards[i] = self.refactorRewards[i]
		penalties[i] = self.refactorPenalties[i]
	}

	return rewards, penalties	
}
/*
func (self *ExternalRewardState) AccumulateReward(startHeight, endHeight uint64) {
	self.pool.incentives.rewardCache.RewardPerInterval(startHeight, endHeight, func(blockNumber uint64, poolRewardI interface{}) {
		incentiveRewardEntry := poolRewardI.(IncentiveRewardEntry)
		for _, incentiveId := range incentiveRewardEntry.ActiveIncentives {
			incentive, ok := self.pool.incentives.GetByIncentiveId(incentiveId)
			if !ok {
				panic("incentive not found")
			}
			rewardRatio := u256.NewUint(incentive.rewardPerBlock)
			rewardRatio.Mul(rewardRatio, q192)
			rewardRatio.Div(rewardRatio, incentiveRewardEntry.TotalStakedLiquidity)
			positionReward := u256.Zero().Mul(self.deposit.liquidity, rewardRatio)
			positionReward = u256.Zero().Mul(positionReward, u256.NewUint(blockNumber))
			acc, ok := self.rewards[self.currentWarmup.Index][incentiveId]
			if !ok {
				acc = u256.Zero()
			}
			acc.Add(acc, positionReward)
			self.rewards[self.currentWarmup.Index][incentiveId] = acc
		}
	})
}
*/
func (self *ExternalRewardState) ApplyWarmup() {
	for i, warmup := range self.deposit.warmups {
		for incentiveId, reward := range self.rewards[i] {
			if reward.IsZero() {
				continue
			}
			warmupReward := u256.Zero()
			warmupReward = warmupReward.Mul(reward, u256.NewUint(warmup.WarmupRatio))
			warmupReward = warmupReward.Div(warmupReward, u256.NewUint(100))

			warmupPenalty := u256.Zero().Sub(reward, warmupReward)

			warmupReward = warmupReward.Div(warmupReward, q192)
			warmupPenalty = warmupPenalty.Div(warmupPenalty, q192)

			self.rewards[i][incentiveId] = warmupReward
			self.penalties[i][incentiveId] = warmupPenalty
		}
	}
}

func (self *ExternalRewardState) TickCrossesToExternalReward(startHeight, endHeight int64) {
	for _, warmup := range self.deposit.warmups {
		self.currentWarmup = warmup

		if startHeight >= warmup.NextWarmupHeight {
			// passed the warmup
			continue
		}

		if endHeight < warmup.NextWarmupHeight {
/*
			// fully submerged in the current warmup
			currentlyInRange, tickUpperCrosses, tickLowerCrosses = ForEachEligibleInterval(
				startHeight,
				endHeight,
				currentlyInRange,
				tickUpperCrosses,
				tickLowerCrosses,
				self.AccumulateReward,
			)
*/
			rewardAcc := self.pool.CalculateRewardForPosition(uint64(startHeight), self.pool.CurrentTick(uint64(startHeight)), uint64(endHeight), self.pool.CurrentTick(uint64(endHeight)), self.deposit)

			rewardAcc = rewardAcc.Mul(rewardAcc, self.deposit.liquidity)
			rewardAcc = rewardAcc.Mul(rewardAcc, u256.NewUint(self.incentive.rewardPerBlock))
			rewardAcc = rewardAcc.Div(rewardAcc, q128)
			self.refactorRewards[self.currentWarmup.Index] = rewardAcc.Uint64()

			// done
			break
		}

		/*
		// partially included in the current warmup
		currentlyInRange, tickUpperCrosses, tickLowerCrosses = ForEachEligibleInterval(
			startHeight,
			warmup.NextWarmupHeight,
			currentlyInRange,
			tickUpperCrosses,
			tickLowerCrosses,
			self.AccumulateReward,
		)
			*/

		rewardAcc := self.pool.CalculateRewardForPosition(uint64(startHeight), self.pool.CurrentTick(uint64(startHeight)), uint64(warmup.NextWarmupHeight), self.pool.CurrentTick(uint64(warmup.NextWarmupHeight)), self.deposit)
		rewardAcc = rewardAcc.Mul(rewardAcc, self.deposit.liquidity)
		rewardAcc = rewardAcc.Mul(rewardAcc, u256.NewUint(self.incentive.rewardPerBlock))
		rewardAcc = rewardAcc.Div(rewardAcc, q128)
		self.refactorRewards[self.currentWarmup.Index] = rewardAcc.Uint64()

		startHeight = warmup.NextWarmupHeight
	}

	self.ApplyWarmup()

	self.deposit.claimHeight = uint64(endHeight)
}

type InternalRewardState struct {
	pool          *Pool
	deposit       *Deposit
	currentWarmup Warmup
	//rewards       []*u256.Uint
	//penalties     []*u256.Uint

	refactorRewards []uint64
	refactorPenalties []uint64
}

func (self *Pool) InternalRewardOf(deposit *Deposit) *InternalRewardState {
	result := &InternalRewardState{
		pool:          self,
		deposit:       deposit,
		currentWarmup: deposit.warmups[0],
		//rewards:       make([]*u256.Uint, len(deposit.warmups)),
		//penalties:     make([]*u256.Uint, len(deposit.warmups)),
		refactorRewards: make([]uint64, len(deposit.warmups)),
		refactorPenalties: make([]uint64, len(deposit.warmups)),
	}

	for i := range result.refactorRewards {
		//result.rewards[i] = u256.Zero()
		//result.penalties[i] = u256.Zero()

		result.refactorRewards[i] = 0
		result.refactorPenalties[i] = 0
	}

	return result
}

func (self *InternalRewardState) Calculate(currentTick int32, startHeight, endHeight int64) ([]uint64, []uint64) {
	self.TickCrossesToInternalReward(currentTick, startHeight, endHeight)

	//println("[[[[ self.rewards ]]]] : ", self.rewards[0].ToString(), self.rewards[1].ToString(), self.rewards[2].ToString(), self.rewards[3].ToString())
	//println("[[[[ self.penalties ]]]] : ", self.penalties[0].ToString(), self.penalties[1].ToString(), self.penalties[2].ToString(), self.penalties[3].ToString())
	println("[[[[ self.refactorRewards ]]]] : ", self.refactorRewards[0], self.refactorRewards[1], self.refactorRewards[2], self.refactorRewards[3])
	println("[[[[ self.refactorPenalties ]]]] : ", self.refactorPenalties[0], self.refactorPenalties[1], self.refactorPenalties[2], self.refactorPenalties[3])

	rewards := make([]uint64, len(self.deposit.warmups))
	penalties := make([]uint64, len(self.deposit.warmups))

	for i, reward := range self.refactorRewards {
		rewards[i] = reward
		penalties[i] = self.refactorPenalties[i]
	}

	return rewards, penalties
}

/*
func (self *InternalRewardState) AccumulateReward(startHeight, endHeight uint64) {
	self.pool.rewardCache.RewardPerInterval(startHeight, endHeight, func(blockNumber uint64, poolRewardI interface{}) {
		poolRewardRatio := poolRewardI.(*u256.Uint)
		positionReward := u256.Zero().Mul(self.deposit.liquidity, poolRewardRatio)
		positionReward = u256.Zero().Mul(positionReward, u256.NewUint(blockNumber))

		acc := self.rewards[self.currentWarmup.Index]
		acc.Add(acc, positionReward)
		self.rewards[self.currentWarmup.Index] = acc
	})
}
*/

func (self *InternalRewardState) ApplyWarmup() {
	for i, warmup := range self.deposit.warmups {
		println("self.refactorRewards[i] : ", i, self.refactorRewards[i])
		/*

		if self.rewards[i].IsZero() {
			continue
		}
		reward := u256.Zero()
		totalReward := u256.Zero().Div(self.rewards[i], q192)

		println("############ totalReward : ", i, totalReward.ToString())

		reward = reward.Mul(self.rewards[i], u256.NewUint(warmup.WarmupRatio))
		reward = reward.Div(reward, u256.NewUint(100))
		reward = reward.Div(reward, q192)

		penalty := u256.Zero().Sub(totalReward, reward)

		self.rewards[i] = reward
		self.penalties[i] = penalty
		*/
		//==========================

		refactorReward := self.refactorRewards[i]
		self.refactorRewards[i] = refactorReward * warmup.WarmupRatio / 100
		self.refactorPenalties[i] = refactorReward - self.refactorRewards[i]
	}
}

func abs(x int64) uint64 {
	if x < 0 {
		return uint64(-x)
	}
	return uint64(x)
}

func (self *InternalRewardState) TickCrossesToInternalReward(startHeight, endHeight int64) {
	for _, warmup := range self.deposit.warmups {
		self.currentWarmup = warmup

		if startHeight >= warmup.NextWarmupHeight {
			// passed the warmup
			continue
		}

		if endHeight < warmup.NextWarmupHeight {
			println("fully submerged in the current warmup", warmup.Index)
			/*
			// fully submerged in the current warmup
			currentlyInRange, tickUpperCrosses, tickLowerCrosses = ForEachEligibleInterval(
				startHeight,
				endHeight,
				currentlyInRange,
				tickUpperCrosses,
				tickLowerCrosses,
				self.AccumulateReward,
			)
			*/
			// checking if global reward ratio logic is correct

			// println("globalAcc : ", globalAcc.ToString(), ", lowerAcc : ", lowerAcc.ToString(), ", upperAcc : ", upperAcc.ToString())
			// XXX it should be calculatereward, not raw reward
			rewardAcc := self.pool.CalculateRewardForPosition(uint64(startHeight), self.pool.CurrentTick(uint64(startHeight)), uint64(endHeight), self.pool.CurrentTick(uint64(endHeight)), self.deposit)

			println("rewardAcc 3 : ", rewardAcc.ToString())
			rewardAcc = rewardAcc.Mul(rewardAcc, self.deposit.liquidity)
			println("rewardAcc 4 : ", rewardAcc.ToString())
			currentReward := uint64(1000000000) // *self.pool.tierRewardTotal
			println("currentReward : ", currentReward)
			rewardAcc = rewardAcc.Mul(rewardAcc, u256.NewUint(currentReward))
			println("rewardAcc 5 : ", rewardAcc.ToString())
			rewardAcc = rewardAcc.Div(rewardAcc, q128)
			println("############ rewardAcc : ", rewardAcc.ToString())

			self.refactorRewards[self.currentWarmup.Index] = rewardAcc.Uint64()

			// done
			break
		}

		// XXX it should be calculatereward, not raw reward
		rewardAcc := self.pool.CalculateRewardForPosition(uint64(startHeight), self.pool.CurrentTick(uint64(startHeight)), uint64(warmup.NextWarmupHeight), self.pool.CurrentTick(uint64(warmup.NextWarmupHeight)), self.deposit)

		/*
		// partially included in the current warmup
		println("partially included in the current warmup", warmup.Index)
		currentlyInRange, tickUpperCrosses, tickLowerCrosses = ForEachEligibleInterval(
			startHeight,
			warmup.NextWarmupHeight,
			currentlyInRange,
			tickUpperCrosses,
			tickLowerCrosses,
			self.AccumulateReward,
		)
					*/



		// checking if global reward ratio logic is correct
//		println("globalAcc : ", globalAcc.ToString(), ", lowerAcc : ", lowerAcc.ToString(), ", upperAcc : ", upperAcc.ToString())

		//claiming = claiming.Add(claiming, rewardAcc)

		println("rewardAcc 3 : ", rewardAcc.ToString())
		rewardAcc = rewardAcc.Mul(rewardAcc, self.deposit.liquidity)
		println("rewardAcc 4 : ", rewardAcc.ToString())
		currentReward := uint64(1000000000) // *self.pool.tierRewardTotal
		println("currentReward : ", currentReward)
		rewardAcc = rewardAcc.Mul(rewardAcc, u256.NewUint(currentReward))
		println("rewardAcc 5 : ", rewardAcc.ToString())
		rewardAcc = rewardAcc.Div(rewardAcc, q128)
		println("############ rewardAcc : ", rewardAcc.ToString())

		self.refactorRewards[self.currentWarmup.Index] = rewardAcc.Uint64()

		startHeight = warmup.NextWarmupHeight

	}

	self.ApplyWarmup()

	self.deposit.claimHeight = uint64(endHeight)
}

func (self *Pool) modifyDeposit(tokenId uint64, delta *i256.Int, currentHeight uint64) {
	// update staker side pool info
	lastStakedLiquidity := self.CurrentStakedLiquidity(currentHeight)
	deltaApplied := liquidityMathAddDelta(lastStakedLiquidity, delta)
	self.stakedLiquidity.Set(currentHeight, deltaApplied)
	self.updateRewardByLiquidityChange(*self.tierRewardTotal, currentHeight, deltaApplied)
}

func (self *Pool) startInternalUnclaimablePeriod(currentHeight uint64) {
	println("\t\t\t[", currentHeight, "] startInternalUnclaimablePeriod Start ")
	if *self.lastUnclaimableHeight == 0 {
		// We set only if it's the first time entering(0 indicates not set yet)
		// PoolTier can set lastUnclaimable other than tickCrossHook when
		// cacheInternalReward() updates currentTierReward
		*self.lastUnclaimableHeight = currentHeight
		println("\t\t\tChange lastUnclaimableHeight : ", *self.lastUnclaimableHeight)
	}
	println("\t\t\t[", currentHeight, "] startInternalUnclaimablePeriod End ")
}

func (self *Pool) endInternalUnclaimablePeriod(currentHeight uint64) {
	println("\t\t\t[", currentHeight, "] endInternalUnclaimablePeriod Start ")
	if *self.lastUnclaimableHeight == 0 {
		// This should not happen, but guarding just in case
		return
	}
	println("\t\t\tcurrentHeight : ", currentHeight, ", lastUnclaimableHeight : ", *self.lastUnclaimableHeight)
	unclaimableHeights := currentHeight - *self.lastUnclaimableHeight
	*self.lastUnclaimableHeight = 0
	*self.unclaimableAcc += unclaimableHeights * *self.tierRewardTotal
	println("\t\t\tunclaimableAcc : ", *self.unclaimableAcc, ", unclaimableHeights : ", unclaimableHeights, ", tierRewardTotal : ", *self.tierRewardTotal)
	println("\t\t\t[", currentHeight, "] endInternalUnclaimablePeriod End ")
}

func (self *Pool) UnclaimableExternalReward(incentiveId string, startHeight, endHeight uint64) uint64 {
	incentive, ok := self.incentives.GetByIncentiveId(incentiveId)
	if !ok {
		return 0
	}

	if startHeight > uint64(incentive.endHeight) || endHeight < uint64(incentive.startHeight) {
		return 0
	}

	if startHeight < uint64(incentive.startHeight) {
		startHeight = uint64(incentive.startHeight)
	}

	if endHeight > uint64(incentive.endHeight) {
		endHeight = uint64(incentive.endHeight)
	}

	rewardPerBlock := incentive.rewardPerBlock

	unclaimable := uint64(0)

	currentStakedLiquidity := self.CurrentStakedLiquidity(startHeight)

	self.stakedLiquidity.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		if currentStakedLiquidity.IsZero() {
			unclaimable += rewardPerBlock * (height - startHeight)
		}
		startHeight = height
		currentStakedLiquidity = value.(*u256.Uint)
		return false
	})

	if currentStakedLiquidity.IsZero() {
		unclaimable += rewardPerBlock * (endHeight - startHeight)
	}

	return unclaimable
}

func (self *Pool) processUnclaimableReward(poolTier *PoolTier, endHeight uint64) (uint64, map[string]uint64) {
	startHeight := *self.lastUnclaimableHeight
	internalUnClaimable := *self.unclaimableAcc
	*self.unclaimableAcc = 0
	externalUnClaimable := make(map[string]uint64)
	for _, incentiveId := range self.incentives.CurrentReward(startHeight).ActiveIncentives {
		externalUnClaimable[incentiveId] = self.UnclaimableExternalReward(incentiveId, startHeight, endHeight)
	}
	println(">>>>>>>>>>>> internalUnClaimable : ", internalUnClaimable, ", externalUnClaimable : ", externalUnClaimable)
	self.lastUnclaimableHeight = &endHeight
	return internalUnClaimable, externalUnClaimable
}

// Calculates reward for a position, *without* considering debt or warmup
func (self *Pool) CalculateRawRewardForPosition(currentHeight uint64, currentTick int32, deposit *Deposit) *u256.Uint {
	var rewardAcc *u256.Uint

	globalAcc := self.calculateGlobalRewardRatioAccumulation(currentHeight, self.CurrentStakedLiquidity(currentHeight))
	lowerAcc := self.ticks.Get(deposit.tickLower).CurrentOutsideAccumulation(currentHeight)
	upperAcc := self.ticks.Get(deposit.tickUpper).CurrentOutsideAccumulation(currentHeight)

	println("currentTick : ", currentTick)
	println("deposit.tickLower : ", deposit.tickLower)
	println("deposit.tickUpper : ", deposit.tickUpper)

	if currentTick < deposit.tickLower {
		println("currentTick < lowerTick")
		println("lowerAcc : ", lowerAcc.ToString())
		println("upperAcc : ", upperAcc.ToString())
		rewardAcc = u256.Zero().Sub(lowerAcc, upperAcc)
	} else if currentTick >= deposit.tickUpper {
		println("currentTick >= upperTick")
		println("lowerAcc : ", lowerAcc.ToString())
		println("upperAcc : ", upperAcc.ToString())
		rewardAcc = u256.Zero().Sub(upperAcc, lowerAcc)
	} else {
		println("currentTick >= lowerTick && currentTick < upperTick")
		println("globalAcc : ", globalAcc.ToString())
		println("lowerAcc : ", lowerAcc.ToString())
		println("upperAcc : ", upperAcc.ToString())
		rewardAcc = u256.Zero().Sub(globalAcc, lowerAcc)
		rewardAcc = rewardAcc.Sub(rewardAcc, upperAcc)
	}

	return rewardAcc
}

// Applying debt and claiming
func (self *Pool) CalculateRewardForPosition(startHeight uint64, startTick int32, endHeight uint64, endTick int32, deposit *Deposit) *u256.Uint {
	rewardAcc := self.CalculateRawRewardForPosition(endHeight, endTick, deposit)
	println("rewardAcc 1 : ", rewardAcc.ToString())

	debtAcc := self.CalculateRawRewardForPosition(startHeight, startTick, deposit)
	println("debtAcc : ", debtAcc.ToString())
	rewardAcc = rewardAcc.Sub(rewardAcc, debtAcc)
	println("rewardAcc 2 : ", rewardAcc.ToString())

	return rewardAcc
}
