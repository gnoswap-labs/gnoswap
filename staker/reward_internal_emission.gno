package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v2/consts"
	"gno.land/r/gnoswap/v2/gns"
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
	pools := poolMap.GetRewardPool()

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
		poolMap.SetPoolRewardAmount(poolPath, poolAmount)
		println(" > poolPath:", poolPath)
		println(" > poolAmount:", poolMap.GetPoolRewardAmount(poolPath))

		//poolLastTmpGns[poolPath] = 0
		//println(" > CALC__INIT_TO_ZERO_poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])

		//println(" > CALC__poolPath:", poolPath)
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
			println(" > Transfer to Community pool : ", poolPath)
			println(" > Sent Amount:", poolAmount)
			println(" > Left Amount:", poolMap.GetPoolRewardAmount(poolPath))
		}
	}

	r.SetRewardPoolsMap(poolMap)
	return distributedAmountForTier1, distributedAmountForTier2, distributedAmountForTier3
}

func (r *InternalEmissionReward) DistributeRewardToStakers() uint64 {
	poolMap := r.GetRewardPoolsMap()
	pools := poolMap.GetRewardPool()
	recipientsMap := r.GetRewardRecipientsMap()
	distributedAmount := uint64(0)
	compareLiquidityRatio := u256.Zero() // TODO: for test, should be removed
	currentHeight := std.GetHeight()

	for poolPath, rewardPool := range pools {
		poolLiquidity := recipientsMap.GetOrCreatePoolLiquidity(poolPath)
		poolRewardAmount := rewardPool.GetRewardAmount()
		accuDistributedAmount := uint64(0) // accumulated distributed amount for each pool
		for tokenId, inRangePosition := range poolLiquidity.inRangeLiquidity {
			if inRangePosition.liquidity.IsZero() || (currentHeight == inRangePosition.GetStakedHeight()) {
				// TODO :
				// 이 시점에서, 이 곳에 빠지는것은 대상자 선정 코드를 다시 체크해봐야할 수 있음
				println(" > Skip : inRangePosition.liquidity.IsZero() || (currentHeight == inRangePosition.GetStakedHeight())")
				continue
			}
			liqRatioX96 := inRangePosition.GetLiquidityRatio()
			positionRewardAmountX96 := u256.Zero().Mul(u256.NewUint(poolRewardAmount), liqRatioX96)
			positionRewardAmountX := u256.Zero().Div(positionRewardAmountX96, _q96)
			positionRewardAmount := positionRewardAmountX.Uint64()
			println(" > positionRewardAmount:", positionRewardAmount)

			// TODO:
			// 1. 이전에 남은양이 있으면, 이전에 남은양을 더해서 계산
			positionRewardAmount += poolLiquidity.GetLeftAmount(tokenId)
			println(" > positionRewardAmount + leftAmount:", positionRewardAmount)

			// 2. tokenId에 대한 reward를 staker에게 지급 하기 위해 설정
			poolLiquidity.SetRewardToStakers(tokenId, positionRewardAmount)
			accuDistributedAmount += positionRewardAmount
			compareLiquidityRatio = compareLiquidityRatio.Add(compareLiquidityRatio, liqRatioX96) // TODO: for test, should be removed

			// 3. Warmup 적용
			stakedHeight := poolLiquidity.GetStakedHeight(tokenId)
			warmupAmount, warmupPenalty := computeWarmUpRewardAmount(currentHeight, stakedHeight, positionRewardAmount)
			// 4. WarmUp 적용된 Reward를 staker에게 지급
			inRangePositionReward := poolLiquidity.GetInRangeReward(tokenId)
			inRangePositionReward.SetWarmUpAmount(inRangePositionReward.GetWarmUpAmount() + warmupAmount)
			inRangePositionReward.SetWarmUpPenalty(inRangePositionReward.GetWarmUpPenalty() + warmupPenalty)

			// TODO:
			// block 높이가 stake 와 같으면, reward를 지급하지 않음 (없음)
			if warmupAmount == 0 {
				continue
			}

			if positionRewardAmount != (warmupAmount + warmupPenalty) {
				leftAmount := positionRewardAmount - (warmupAmount + warmupPenalty)
				inRangePositionReward.SetLeftAmount(leftAmount)
			} else {
				// TODO:
				// after test, should be removed
				println(" > positionRewardAmount == (warmupAmount + warmupPenalty)")
			}
			poolLiquidity.SetInRangeReward(tokenId, inRangePositionReward)

			// TODO:
			// 1. positionRewardAmount 는 position에 부여되는 Reward
			positionLastGns[tokenId] = positionGns[tokenId]
			positionGns[tokenId] += positionRewardAmount
			poolLastTmpGns[poolPath] += positionRewardAmount

			distributedAmount += positionRewardAmount

			// calculate internal amount from previous to now
			// rewardMathComputeInternalRewardAmount(tokenId)
			// TODO:
			// 1. update reward amount and penalty amount into positionsInternalWarmUpAmount
		}
		rewardPool.SetDistributedAmount(accuDistributedAmount)
		if poolRewardAmount != accuDistributedAmount {
			leftAmount := poolRewardAmount - accuDistributedAmount
			rewardPool.SetLeftAmount(leftAmount)
		}
		poolMap.SetRewardPool(poolPath, rewardPool)
		recipientsMap.SetPoolLiquidity(poolPath, poolLiquidity)
	}
	// TODO:
	// 1. For test, should be removed
	println(" > compareLiquidityRatio:", compareLiquidityRatio.Div(compareLiquidityRatio, _q96).ToString())

	return distributedAmount
}
