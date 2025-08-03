package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// Q96
var _q96 = u256.MustFromDecimal("79228162514264337593543950336")

func isAbleToCalculateEmissionReward(prev int64, current int64) bool {
	if prev >= current {
		return false
	}
	return true
}

// Reward is a struct for storing reward for a position.
// Internal reward is the GNS reward, external reward is the reward for other incentives.
// Penalties are the amount that is deducted from the reward due to the position's warmup.
type Reward struct {
	Internal        int64
	InternalPenalty int64
	External        map[string]int64 // Incentive ID -> TokenAmount
	ExternalPenalty map[string]int64 // Incentive ID -> TokenAmount
}

// calculate total position rewards and penalties
func calcPositionReward(currentHeight int64, positionId uint64) Reward {
	rewards := calculatePositionReward(CalcPositionRewardParam{
		CurrentHeight: currentHeight,
		Deposits:      deposits,
		Pools:         pools,
		PoolTier:      poolTier,
		PositionId:    positionId,
	})

	internal := int64(0)
	for _, reward := range rewards {
		internal += reward.Internal
	}

	internalPenalty := int64(0)
	for _, reward := range rewards {
		internalPenalty += reward.InternalPenalty
	}

	externalReward := make(map[string]int64)
	for _, reward := range rewards {
		if reward.External != nil {
			for incentive, reward := range reward.External {
				externalReward[incentive] += reward
			}
		}
	}

	externalPenalty := make(map[string]int64)
	for _, reward := range rewards {
		if reward.ExternalPenalty != nil {
			for incentive, penalty := range reward.ExternalPenalty {
				externalPenalty[incentive] += penalty
			}
		}
	}

	return Reward{
		Internal:        internal,
		InternalPenalty: internalPenalty,
		External:        externalReward,
		ExternalPenalty: externalPenalty,
	}
}

// CalcPositionRewardParam is a struct for calculating position reward
type CalcPositionRewardParam struct {
	// Environmental variables
	CurrentHeight int64
	Deposits      *Deposits
	Pools         *Pools
	PoolTier      *PoolTier

	// Position variables
	PositionId uint64
}

func calculatePositionReward(param CalcPositionRewardParam) []Reward {
	// Cache per-pool rewards in the internal incentive(tiers)
	// PoolTier calculates the correct emission allocation for each pool and calls cacheInternalReward
	param.PoolTier.cacheReward(param.CurrentHeight, param.Pools)

	deposit := param.Deposits.get(param.PositionId)
	poolPath := deposit.targetPoolPath

	pool, ok := param.Pools.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, param.CurrentHeight)
		param.Pools.set(poolPath, pool)
	}

	// No need to manually update accumulation - already done by PoolTier.cacheReward()
	// Update external incentives accumulations
	currentStakedLiquidity := pool.CurrentStakedLiquidity(param.CurrentHeight)
	allIncentives := pool.incentives.GetAllInHeights(deposit.lastCollectHeight, param.CurrentHeight)
	for _, incentive := range allIncentives {
		incentive.updateAccumulation(param.CurrentHeight, currentStakedLiquidity)
	}

	// Calculate position-specific reward accumulation using tick-based method
	positionRewardAcc := pool.CalculateRewardForPosition(
		deposit.lastCollectHeight,
		pool.CurrentTick(deposit.lastCollectHeight),
		param.CurrentHeight,
		pool.CurrentTick(param.CurrentHeight),
		deposit,
	)

	// Initializes reward/penalty arrays for rewards and penalties for each warmup
	internalRewards := make([]int64, len(deposit.warmups))
	internalPenalties := make([]int64, len(deposit.warmups))
	externalRewards := make([]map[string]int64, len(deposit.warmups))
	externalPenalties := make([]map[string]int64, len(deposit.warmups))

	// Calculate internal rewards using accumulation differences with proper warmup calculation
	if param.PoolTier.CurrentTier(poolPath) != 0 {
		// For internal rewards, use position-specific accumulation with enhanced X128 precision
		// Use MulDiv to minimize precision loss: (positionRewardAcc * deposit.liquidity) / Q128
		totalInternalReward := u256.MulDiv(positionRewardAcc, deposit.liquidity, u256.MustFromDecimal("340282366920938463463374607431768211456"))

		baseInternalReward := int64(totalInternalReward.Uint64())

		// Calculate warmup-weighted reward
		internalRewards, internalPenalties = calculateWarmupWeightedReward(
			deposit,
			baseInternalReward,
			deposit.lastCollectHeight,
			param.CurrentHeight,
		)
	}

	// Calculate external rewards using accumulation differences
	for i := range externalRewards {
		externalRewards[i] = make(map[string]int64)
		externalPenalties[i] = make(map[string]int64)
	}

	for incentiveId, incentive := range allIncentives {
		// Check if position is in range for external rewards using common function
		currentTick := pool.CurrentTick(param.CurrentHeight)
		isInRange := isPositionInRange(currentTick, deposit.tickLower, deposit.tickUpper)

		var baseExternalReward int64
		if !isInRange {
			// Position is out-of-range, no external reward
			baseExternalReward = 0
		} else {
			// Calculate reward based on accumulation difference with enhanced X128 precision
			lastAcc := deposit.lastExternalAccumulations[incentiveId]
			if lastAcc == nil {
				lastAcc = u256.Zero()
			}

			accDiff := u256.Zero().Sub(incentive.rewardAccumulation, lastAcc)
			// Use MulDiv to minimize precision loss: (accDiff * deposit.liquidity) / Q128
			externalReward := u256.MulDiv(accDiff, deposit.liquidity, u256.MustFromDecimal("340282366920938463463374607431768211456"))

			baseExternalReward = int64(externalReward.Uint64())
		}

		// Apply warmup to external rewards using the same logic as internal rewards
		rewards, penalties := calculateWarmupWeightedReward(
			deposit,
			baseExternalReward,
			deposit.lastCollectHeight,
			param.CurrentHeight,
		)

		for i := range rewards {
			externalRewards[i][incentiveId] = rewards[i]
			externalPenalties[i][incentiveId] = penalties[i]
		}
	}

	rewards := make([]Reward, len(internalRewards))
	for i := range internalRewards {
		rewards[i] = Reward{
			Internal:        internalRewards[i],
			InternalPenalty: internalPenalties[i],
			External:        externalRewards[i],
			ExternalPenalty: externalPenalties[i],
		}
	}

	return rewards
}

// calculates internal unclaimable reward for the pool
func processUnClaimableReward(poolPath string, endHeight int64) int64 {
	pool, ok := pools.Get(poolPath)
	if !ok {
		return 0
	}
	return pool.processUnclaimableReward(poolTier, endHeight)
}

// calculateWarmupWeightedReward calculates reward considering warmup tier changes over time
func calculateWarmupWeightedReward(deposit *Deposit, baseReward int64, startHeight int64, endHeight int64) ([]int64, []int64) {
	totalBlocks := endHeight - startHeight
	if totalBlocks <= 0 {
		return []int64{}, []int64{}
	}

	// Find breakpoints where warmup tier changes
	breakpoints := findWarmupBreakpoints(deposit, startHeight, endHeight)

	userRewards := make([]int64, len(deposit.warmups))
	penalties := make([]int64, len(deposit.warmups))

	// Calculate reward for each period between breakpoints
	for i := 0; i < len(breakpoints)-1; i++ {
		periodStart := breakpoints[i]
		periodEnd := breakpoints[i+1]
		periodBlocks := periodEnd - periodStart

		if periodBlocks <= 0 {
			continue
		}

		// Find warmup ratio for this period (use middle of period)
		midHeight := periodStart + periodBlocks/2
		warmupIndex := deposit.FindWarmup(midHeight)
		warmupRatio := deposit.warmups[warmupIndex].WarmupRatio

		// Calculate period reward and apply warmup
		periodUserReward, periodPenalty := calculatePeriodReward(
			baseReward,
			totalBlocks,
			periodBlocks,
			warmupRatio,
		)

		userRewards[i] = periodUserReward
		penalties[i] = periodPenalty
	}

	return userRewards, penalties
}

// findWarmupBreakpoints finds all height points where warmup tier changes
func findWarmupBreakpoints(deposit *Deposit, startHeight int64, endHeight int64) []int64 {
	breakpoints := []int64{startHeight}

	// Add warmup tier change points within the period
	for _, warmup := range deposit.warmups {
		if warmup.NextWarmupHeight > startHeight && warmup.NextWarmupHeight <= endHeight {
			breakpoints = append(breakpoints, warmup.NextWarmupHeight)
		}
	}

	breakpoints = append(breakpoints, endHeight)
	return breakpoints
}

// calculatePeriodReward calculates reward for a specific period with given warmup ratio
func calculatePeriodReward(baseReward int64, totalBlocks int64, periodBlocks int64, warmupRatio uint64) (int64, int64) {
	// Calculate period reward proportional to blocks
	periodReward := baseReward * periodBlocks / totalBlocks

	// Apply warmup ratio
	periodUserReward := periodReward * int64(warmupRatio) / 100
	periodPenalty := periodReward - periodUserReward

	return periodUserReward, periodPenalty
}
