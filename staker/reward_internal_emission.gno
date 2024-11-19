package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gns"
)

// InternalEmissionReward ...
// Internal emission reward 분배를 위한 구조체
// --- Internal Reward ---
// 1. 전체 Pool중 Internal Reward 대상 Pool을 선별
// 2. Reward 대상 Pool에 대해서, Tier별 Reward를 계산
// 3. Reward를 위해 Minted GNS를 Tier별 Pool에 분배
// 4. 전체 포지션에서 Reward 대상 포지션을 선별
// 5. Reward 대상 포지션에 대해서, Reward를 계산 (Warm-up적용)
type InternalEmissionReward struct {
	rewardPoolsMap      *RewardPoolMap
	rewardRecipientsMap *RewardRecipientsMap
	rewardTotalAmount   uint64 // total reward amount to distribute to pools
	leftAmount          uint64 // left reward amount
}

func NewInternalEmissionReward() *InternalEmissionReward {
	return &InternalEmissionReward{
		rewardPoolsMap:      NewRewardPoolMap(),
		rewardRecipientsMap: NewRewardRecipientMap(),
		rewardTotalAmount:   0,
		leftAmount:          0,
	}
}

func (r *InternalEmissionReward) SetRewardPoolsMap(rpm *RewardPoolMap) {
	r.rewardPoolsMap = rpm
}

func (r *InternalEmissionReward) SetRewardRecipientsMap(rrm *RewardRecipientsMap) {
	r.rewardRecipientsMap = rrm
}

func (r *InternalEmissionReward) SetRewardTotalAmount(ra uint64) {
	r.rewardTotalAmount = ra
}

func (r *InternalEmissionReward) SetLeftAmount(leftAmount uint64) {
	r.leftAmount = leftAmount
}

func (r *InternalEmissionReward) GetRewardPoolsMap() *RewardPoolMap {
	return r.rewardPoolsMap
}

func (r *InternalEmissionReward) GetRewardRecipientsMap() *RewardRecipientsMap {
	return r.rewardRecipientsMap
}

func (r *InternalEmissionReward) GetOrCreateRewardRecipientsMap() *RewardRecipientsMap {
	if r.rewardRecipientsMap == nil {
		r.rewardRecipientsMap = NewRewardRecipientMap()
	}
	return r.rewardRecipientsMap
}

func (r *InternalEmissionReward) GetRewardTotalAmount() uint64 {
	return r.rewardTotalAmount
}

func (r *InternalEmissionReward) GetLeftAmount() uint64 {
	return r.leftAmount
}

func (r *InternalEmissionReward) SelectRewardPools(pools map[string]InternalTier) {
	rewardPool := r.GetRewardPoolsMap()
	for poolPath, internalTier := range pools {
		switch internalTier.tier {
		case TIER1_INDEX, TIER2_INDEX, TIER3_INDEX:
			rewardPool.SetPoolTier(poolPath, internalTier.tier)
			break
		}
	}
	r.SetRewardPoolsMap(rewardPool)
}

func (r *InternalEmissionReward) HasPoolWithoutStaker(poolPath string) bool {
	poolLiquidity := r.GetRewardRecipientsMap().GetOrCreatePoolLiquidity(poolPath)
	return poolLiquidity.totalLiquidity.IsZero()
}

func (r *InternalEmissionReward) CalculateRewardForEachTier(rewardAmountForDistribution uint64) uint64 {
	rewardPoolMap := r.GetRewardPoolsMap()
	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(rewardAmountForDistribution)
	rewardPoolMap.SetRewardAmountForTier(TIER1_INDEX, tier1Amount)
	rewardPoolMap.SetRewardAmountForTier(TIER2_INDEX, tier2Amount)
	rewardPoolMap.SetRewardAmountForTier(TIER3_INDEX, tier3Amount)
	r.SetRewardPoolsMap(rewardPoolMap)
	return tier1Amount + tier2Amount + tier3Amount
}

func (r *InternalEmissionReward) CalculateRewardForTierEachPool(leftAmountForTier1 uint64, leftAmountForTier2 uint64, leftAmountForTier3 uint64) {
	var eachTier1Amount, eachTier2Amount, eachTier3Amount uint64
	rewardPoolMap := r.GetRewardPoolsMap()
	tier1Amount := rewardPoolMap.GetRewardAmountForTier(TIER1_INDEX)
	tier2Amount := rewardPoolMap.GetRewardAmountForTier(TIER2_INDEX)
	tier3Amount := rewardPoolMap.GetRewardAmountForTier(TIER3_INDEX)

	totalRewardForTier1 := tier1Amount + leftAmountForTier1
	totalRewardForTier2 := tier2Amount + leftAmountForTier2
	totalRewardForTier3 := tier3Amount + leftAmountForTier3

	rewardPoolMap.SetRewardAmountForTier(TIER1_INDEX, totalRewardForTier1)
	rewardPoolMap.SetRewardAmountForTier(TIER2_INDEX, totalRewardForTier2)
	rewardPoolMap.SetRewardAmountForTier(TIER3_INDEX, totalRewardForTier3)

	tier1Num, tier2Num, tier3Num := getNumPoolTiers()

	if tier1Num > 0 {
		eachTier1Amount = totalRewardForTier1 / tier1Num
		rewardPoolMap.SetRewardAmountForTierEachPool(TIER1_INDEX, eachTier1Amount)
	}
	if tier2Num > 0 {
		eachTier2Amount = totalRewardForTier2 / tier2Num
		rewardPoolMap.SetRewardAmountForTierEachPool(TIER2_INDEX, eachTier2Amount)
	}
	if tier3Num > 0 {
		eachTier3Amount = totalRewardForTier3 / tier3Num
		rewardPoolMap.SetRewardAmountForTierEachPool(TIER3_INDEX, eachTier3Amount)
	}

	r.SetRewardPoolsMap(rewardPoolMap)
}

// CalculateRewardEachTiers calculates reward amount for each tiers
// TODO:
// 1. 지난번 Tier별 남은 수량을 Tier별 계산하는 함수에 input parameter로 추가
// 2. Tier별 지급 수량에 지난번 남은 수량을 추가해서 셋
func (r *InternalEmissionReward) CalculateRewardEachTiers(leftAmountForTier1 uint64, leftAmountForTier2 uint64, leftAmountForTier3 uint64) {
	var eachTier1Amount, eachTier2Amount, eachTier3Amount uint64
	rewardAmountForDistribution := r.GetRewardTotalAmount()
	rewardPoolMap := r.GetRewardPoolsMap()
	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(rewardAmountForDistribution)
	tier1Num, tier2Num, tier3Num := getNumPoolTiers()
	// TODO:
	// leftAmountByTierDistribution = rewardAmountForDistribution -(tier1Amount + tier2Amount + tier3Amount)

	rewardPoolMap.SetRewardAmountForTier(TIER1_INDEX, tier1Amount+leftAmountForTier1)
	rewardPoolMap.SetRewardAmountForTier(TIER2_INDEX, tier2Amount+leftAmountForTier2)
	rewardPoolMap.SetRewardAmountForTier(TIER3_INDEX, tier3Amount+leftAmountForTier3)

	if tier1Num > 0 {
		eachTier1Amount = rewardPoolMap.GetRewardAmountForTier(TIER1_INDEX) / tier1Num
		rewardPoolMap.SetRewardAmountForTierEachPool(TIER1_INDEX, eachTier1Amount)
	}

	if tier2Num > 0 {
		eachTier2Amount = rewardPoolMap.GetRewardAmountForTier(TIER2_INDEX) / tier2Num
		rewardPoolMap.SetRewardAmountForTierEachPool(TIER2_INDEX, eachTier2Amount)
	}

	if tier3Num > 0 {
		eachTier3Amount = rewardPoolMap.GetRewardAmountForTier(TIER3_INDEX) / tier3Num
		rewardPoolMap.SetRewardAmountForTierEachPool(TIER3_INDEX, eachTier3Amount)
	}
	r.SetRewardPoolsMap(rewardPoolMap)
}

// DistributeRewardToEachPools distributes reward to each pools
// NOTE: This function should be called after CalculateRewardEachTiers
// And after distribute reward, left amount should be checked
// Remaining quantities may exist at different tiers.
//
// Parameters:
//   - prevAddr (string): previous address
//   - prevPkgPath (string): previous package path
//
// Returns:
//   - distributedAmountForTier1 (uint64): distributed amount
//   - distributedAmountForTier2 (uint64): distributed amount
//   - distributedAmountForTier3 (uint64): distributed amount
func (r *InternalEmissionReward) DistributeRewardToEachPools(prevAddr string, prevPkgPath string) (uint64, uint64, uint64) {
	var distributedAmountForTier1 uint64 = uint64(0)
	var distributedAmountForTier2 uint64 = uint64(0)
	var distributedAmountForTier3 uint64 = uint64(0)

	poolMap := r.GetRewardPoolsMap()
	pools := poolMap.GetRewardPools()

	// 1. distributed reward to each pool
	for poolPath, rewardPool := range pools {
		poolAmount := uint64(0)
		switch rewardPool.tier {
		case 1:
			poolAmount = poolMap.GetRewardAmountForTierEachPool(TIER1_INDEX)
			distributedAmountForTier1 += poolAmount
		case 2:
			poolAmount = poolMap.GetRewardAmountForTierEachPool(TIER2_INDEX)
			distributedAmountForTier2 += poolAmount
		case 3:
			poolAmount = poolMap.GetRewardAmountForTierEachPool(TIER3_INDEX)
			distributedAmountForTier3 += poolAmount
		default:
			// TODO:
			// 1. panic should be removed
			panic(ufmt.Sprintf("[STAKER] reward_internal_emission.gno__DistributeRewardToEachPools() || invalid tier(%d)", rewardPool.tier))
		}
		rewardPool.SetRewardAmount(poolAmount)
		poolMap.SetRewardPool(poolPath, rewardPool)
		// TODO:
		// after refactoring is complete, should be removed
		poolGns[poolPath] += poolAmount
		poolAccuGns[poolPath] += poolAmount
		// current block minted gns + left from last block distributed gns
		poolCurrentBlockGns[poolPath] = poolAmount
		//poolCurrentBlockGns[poolPath] += poolLastTmpGns[poolPath]
		//poolLastTmpGns[poolPath] = 0

		if r.HasPoolWithoutStaker(poolPath) {
			// TODO:
			// 1. send poolAmount to community pool
			gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), poolAmount)
			std.Emit(
				"CommunityPoolEmptyEmission",
				"prevAddr", prevAddr,
				"prevRealm", prevPkgPath,
				"internal_poolPath", poolPath,
				"internal_amount", ufmt.Sprintf("%d", poolAmount),
			)
			// TODO:
			// should be removed after implementation
			poolGns[poolPath] = 0
			poolCurrentBlockGns[poolPath] = 0
			lastCalculatedBalance -= poolAmount
			NewRewardAmount := poolMap.GetPoolRewardAmount(poolPath) - poolAmount
			poolMap.SetPoolRewardAmount(poolPath, NewRewardAmount)
		}
	}

	r.SetRewardPoolsMap(poolMap)
	return distributedAmountForTier1, distributedAmountForTier2, distributedAmountForTier3
}

func (r *InternalEmissionReward) distributeRewardToStakers(poolPath string, poolRewardAmount uint64) uint64 {
	recipientsMap := r.GetRewardRecipientsMap()
	poolLiquidity := recipientsMap.GetPoolLiquidity(poolPath)
	if poolLiquidity == nil {
		return 0
	}
	inRangeLiquidityMap := poolLiquidity.GetInRangeLiquidityMap()
	currentHeight := std.GetHeight()
	distributedAmount := uint64(0)

	for tokenId, inRangePosition := range inRangeLiquidityMap {
		if inRangePosition.GetLiquidity().IsZero() || (currentHeight == inRangePosition.GetStakedHeight()) {
			// TODO : 이 시점에서, 이 곳에 빠지는것은 대상자 선정 코드를 다시 체크해봐야할 수 있음
			println(" > Skip : inRangePosition.liquidity.IsZero() || (currentHeight == inRangePosition.GetStakedHeight())")
			continue
		}
		stakedHeight := poolLiquidity.GetStakedHeight(tokenId)
		if stakedHeight == 0 {
			// TODO: stakedHeight가 0인 경우는 있어선 안됨
			println(" > [Error][distributeReardToStakers] stakedHeight == 0")
			continue
		}

		liqRatioX96 := inRangePosition.GetLiquidityRatio()
		positionRewardAmount := computeRewardByRatio(poolRewardAmount, liqRatioX96)
		if poolLiquidity.GetOrCreateInRangePositionReward(tokenId).HasPrevLeftAmount() {
			positionRewardAmount += poolLiquidity.GetInRangePositionReward(tokenId).GetLeftAmount()
		}
		// Calculate Warmup Reward
		warmupAmount, warmupPenalty := computeInternalWarmUpRewardAmount(currentHeight, stakedHeight+1, positionRewardAmount)
		// TODO:
		// 1. after refactoring is completed, should be removed
		internalWarmUpAmount, exist := positionsInternalWarmUpAmount[tokenId]
		if !exist {
			positionsInternalWarmUpAmount[tokenId] = warmUpAmount{}
		}
		internalWarmUpAmount.full30 += warmUpReward.give30 + warmUpReward.left30
		internalWarmUpAmount.give30 += warmUpReward.give30
		internalWarmUpAmount.left30 += warmUpReward.left30
		internalWarmUpAmount.full50 += warmUpReward.give50 + warmUpReward.left50
		internalWarmUpAmount.give50 += warmUpReward.give50
		internalWarmUpAmount.left50 += warmUpReward.left50
		internalWarmUpAmount.full70 += warmUpReward.give70 + warmUpReward.left70
		internalWarmUpAmount.give70 += warmUpReward.give70
		internalWarmUpAmount.left70 += warmUpReward.left70
		internalWarmUpAmount.full100 += warmUpReward.full100
		positionsInternalWarmUpAmount[tokenId] = internalWarmUpAmount
		warmUpReward = warmUpAmount{}

		// Update Reward Information
		inRangePositionReward := poolLiquidity.GetInRangePositionReward(tokenId)
		inRangePositionReward.SetWarmUpAmount(warmupAmount)
		inRangePositionReward.SetWarmUpPenalty(warmupPenalty)
		inRangePositionReward.AddWarmUpRewardAmount(warmupAmount)
		inRangePositionReward.AddWarmUpPenaltyAmount(warmupPenalty)

		if positionRewardAmount != (warmupAmount + warmupPenalty) {
			leftAmount := positionRewardAmount - (warmupAmount + warmupPenalty)
			inRangePositionReward.SetLeftAmount(leftAmount)
		}
		distributedAmount += positionRewardAmount

		poolLiquidity.SetInRangePositionReward(tokenId, inRangePositionReward)
		// TODO:
		// 1. positionRewardAmount 는 position에 부여되는 Reward
		positionLastGns[tokenId] = positionGns[tokenId]
		positionGns[tokenId] += positionRewardAmount
		poolLastTmpGns[poolPath] += positionRewardAmount
	}

	recipientsMap.SetPoolLiquidity(poolPath, poolLiquidity)
	r.SetRewardRecipientsMap(recipientsMap)

	return distributedAmount
}

func (r *InternalEmissionReward) DistributeRewardToStakers() {
	poolMap := r.GetRewardPoolsMap()
	pools := poolMap.GetRewardPools()

	for poolPath, rewardPool := range pools {
		poolRewardAmount := rewardPool.GetRewardAmount()
		poolRewardAmount += rewardPool.GetLeftAmount()
		distributedAmount := r.distributeRewardToStakers(poolPath, poolRewardAmount)
		rewardPool.SetDistributedAmount(distributedAmount)
		// update left amount and distributed amount
		poolLeftAmount := poolRewardAmount - distributedAmount
		rewardPool.SetLeftAmount(poolLeftAmount)
		poolMap.SetRewardPool(poolPath, rewardPool)

		// TODO:
		// after refactor is completed, should be removed
		poolLastTmpGns[poolPath] = poolLeftAmount
	}
	r.SetRewardPoolsMap(poolMap)
}
