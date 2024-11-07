package staker

import (
	"gno.land/p/demo/ufmt"
	"std"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"

	pn "gno.land/r/gnoswap/v2/position"

	u256 "gno.land/p/gnoswap/uint256"
)

// poolPath -> gnsAmount [accu]
var poolGns map[string]uint64 = make(map[string]uint64)

// poolPath -> gnsAmount [current block]
var poolCurrentBlockGns map[string]uint64 = make(map[string]uint64)

// poolPath -> gnsAmount [how much left from last block]
var poolLastTmpGns map[string]uint64 = make(map[string]uint64)

// poolPath -> accumulatedGns ( API VAR )
var poolAccuGns map[string]uint64 = make(map[string]uint64)

// tokenId -> gnsAmount
var positionGns map[uint64]uint64 = make(map[uint64]uint64)

// tokenId -> lastGnsAmount
var positionLastGns map[uint64]uint64 = make(map[uint64]uint64)

// tokenId -> incentiveId -> lastRewardAmount
var positionLastExternal map[uint64]map[string]*u256.Uint = make(map[uint64]map[string]*u256.Uint)

// incentiveId -> lastCalculatedTimestamp
var externalLastCalculatedTimestamp map[string]int64 = make(map[string]int64)

// incentiveId -> gnsAmount
var externalGns map[string]uint64 = make(map[string]uint64)

// poolPath -> totalStakedLiquidity(inRange)
var poolTotalStakedLiquidity map[string]*u256.Uint = make(map[string]*u256.Uint)

// tokenId -> positionRatio
var positionsLiquidityRatio map[uint64]*u256.Uint = make(map[uint64]*u256.Uint)

// poolPath -> []tokenId
var poolsPositions map[string][]uint64 = make(map[string][]uint64)

// Q96
var _q96 = u256.MustFromDecimal(consts.Q96)

type externalRewards struct {
	incentiveId    string
	poolPath       string
	tokenPath      string
	tokenAmountX96 *u256.Uint
	//
	tokenAmountFull   uint64
	tokenAmountToGive uint64
}

// tokenId -> incentiveId -> externalRewards
var positionExternal map[uint64]map[string]externalRewards = make(map[uint64]map[string]externalRewards)

var (
	lastCalculatedHeight          int64
	lastCalculatedBalance         uint64
	lastLeftInternalReward        uint64                // total left
	lastLeftInternalRewardForTier [TIER_TYPE_NUM]uint64 // left for each tier
	totalRewardManager            *RewardManager
)

func init() {
	totalRewardManager = NewRewardManager()
}

func getLastCalculatedHeight() int64 {
	return lastCalculatedHeight
}

func getLastLeftInternalReward() uint64 {
	return lastLeftInternalReward
}

func setLastLeftInternalReward(amount uint64) {
	lastLeftInternalReward = amount
}

func getLastLeftInternalRewardForTier(tierIndex int) uint64 {
	return lastLeftInternalRewardForTier[tierIndex]
}

func setLastLeftInternalRewardForTier(tierIndex int, amount uint64) {
	lastLeftInternalRewardForTier[tierIndex] = amount
}

func getRewardManager() *RewardManager {
	return totalRewardManager
}

func isAbleToCalculateEmissionReward(prev int64, current int64) bool {
	if prev >= current {
		return false
	}
	return true
}

// NOTE:
// RewardRecipients Condition
// 1. 리워드 대상 풀에 Mint와 Stake를 해야 한다.
// 2. inRange 포지션만 해당 된다.
// -> 대상자 선별시, 해당 내용이 반영되어야 함
func CalcPoolPositionRefactor(distributableAmount uint64) bool {
	currentHeight := std.GetHeight()
	prevHeight := getLastCalculatedHeight()
	if !isAbleToCalculateEmissionReward(prevHeight, currentHeight) {
		return false
	}

	prevAddr, prevPkgPath := getPrev()
	// --- Internal Reward ---
	rewardManager := getRewardManager()
	internalEmissionReward := rewardManager.GetInternalReward() // TODO: GetInternalEmissionReward
	// 지급할 양 계산
	// TODO:
	// 1. Last에 남은 리워드는 반드시 적재해둘것
	internalRewardAmount := distributableAmount + getLastLeftInternalReward()
	internalEmissionReward.SetRewardTotalAmount(internalRewardAmount)
	// 지급 대상 계산
	rewardRecipients := NewRewardRecipientMap()
	depositList := getDeposits()
	rewardRecipients.GenerateRewardRecipients(depositList)
	// TODO :
	// poolsPositions은 정리후, 삭제
	poolsPositions = rewardRecipients.CalculateLiquidityRatioAndGetTokenIdMap()
	internalEmissionReward.SetRewardRecipientsMap(rewardRecipients)

	// Select Internal Reward Pools
	poolList := getPoolTiers()
	internalEmissionReward.SelectRewardPools(poolList)
	// Calculate Internal Reward for each Tiers
	internalEmissionReward.CalculateRewardEachTiers(
		getLastLeftInternalRewardForTier(TIER1_INDEX),
		getLastLeftInternalRewardForTier(TIER2_INDEX),
		getLastLeftInternalRewardForTier(TIER3_INDEX),
	)
	// Distribute Internal Reward to Pools
	distributedTier1, distributedTier2, distributedTier3 :=
		internalEmissionReward.DistributeRewardToEachPools(prevAddr, prevPkgPath)
	rewardTier1 := internalEmissionReward.GetRewardPoolsMap().GetRewardAmountForTier(TIER1_INDEX)
	rewardTier2 := internalEmissionReward.GetRewardPoolsMap().GetRewardAmountForTier(TIER2_INDEX)
	rewardTier3 := internalEmissionReward.GetRewardPoolsMap().GetRewardAmountForTier(TIER3_INDEX)
	// Save left reward for each tier
	setLastLeftInternalRewardForTier(TIER1_INDEX, rewardTier1-distributedTier1)
	setLastLeftInternalRewardForTier(TIER2_INDEX, rewardTier2-distributedTier2)
	setLastLeftInternalRewardForTier(TIER3_INDEX, rewardTier3-distributedTier3)
	rewardPoolMap := internalEmissionReward.GetRewardPoolsMap()
	rewardPoolMap.SetLeftAmountForTier(TIER1_INDEX, rewardTier1-distributedTier1)
	rewardPoolMap.SetLeftAmountForTier(TIER2_INDEX, rewardTier2-distributedTier2)
	rewardPoolMap.SetLeftAmountForTier(TIER3_INDEX, rewardTier3-distributedTier3)
	internalEmissionReward.SetRewardPoolsMap(rewardPoolMap)

	// Distribute Internal Reward to Staker (Warm-up)
	distributedAmountToStaker := internalEmissionReward.DistributeRewardToStakers()
	// Check Left Reward
	if internalEmissionReward.GetRewardTotalAmount() != distributedAmountToStaker {
		totalDistributableAmount := internalEmissionReward.GetRewardTotalAmount()
		leftAmountAfterDistribution := totalDistributableAmount - distributableAmount
		// TODO:
		// 1. Last에 남은 리워드는 반드시 적재해둘것
		internalEmissionReward.SetLeftAmount(leftAmountAfterDistribution)
		setLastLeftInternalReward(leftAmountAfterDistribution)
	}

	// Internal Reward update
	rewardManager.SetInternalReward(internalEmissionReward)

	// --- External Reward ---
	// 7. 전체 Pool중 External Reward 대상 Pool을 선별
	// 8. External Reward 대상 Pool에 대해서, Reward대상자를 선별
	// 9. External Reward 대상자에게 Reward를 분배
	rewardManager.SetExternalReward(NewExternalIncentiveReward())
	external := NewExternalCalculator(currentHeight)
	external.calculate(incentives) // XXX: no returning any value?

	return true
}

// XXX: need to improve nested iteration
// CalcPoolPosition calculates and updates the position of pools and rewards for stakers.
//
// It performs the following operations:
//
//  1. Calculates newly minted GNS tokens and distributes them among pool tiers.
//  2. Updates pool GNS balances and accumulated GNS for each pool.
//  3. Calculates and updates internal rewards for each staker's position.
//  4. Calculates and updates external rewards from incentives for each staker's postion.
//
// This function is meant to be called periodically to keep the pool postions
// and reward calculations up-to-date.
//
// It uses the current block height and its timestamp to determine the calculation period.
func CalcPoolPosition() {
	height := std.GetHeight()

	if height <= lastCalculatedHeight {

		return
	}

	prevAddr, prevRealm := getPrev()

	// calculate each pool's total staked liquidity
	poolTotalStakedLiquidity = make(map[string]*u256.Uint) // clear
	for tokenId, deposit := range deposits {
		poolPath := deposit.targetPoolPath
		if _, exist := poolTotalStakedLiquidity[poolPath]; !exist {
			poolTotalStakedLiquidity[poolPath] = u256.Zero()
		}

		isInRange := pn.PositionIsInRange(tokenId)
		if isInRange == false {
			continue
		}

		positionLiquidity := pn.PositionGetPositionLiquidity(tokenId)
		poolTotalStakedLiquidity[poolPath] = poolTotalStakedLiquidity[poolPath].Add(poolTotalStakedLiquidity[poolPath], positionLiquidity)
	}

	// calculate each position's liquidity ratio
	// + also which pool has which positions
	positionsLiquidityRatio = make(map[uint64]*u256.Uint) // clear
	poolsPositions = make(map[string][]uint64)            // clear

	for tokenId, deposit := range deposits {
		poolPath := deposit.targetPoolPath
		isInRange := pn.PositionIsInRange(tokenId)
		if isInRange == false {
			positionsLiquidityRatio[tokenId] = u256.Zero()
		} else {
			poolTotalStakedLiquidity := poolTotalStakedLiquidity[poolPath]
			positionLiquidity := pn.PositionGetPositionLiquidity(tokenId)

			positionLiquidityX96x := new(u256.Uint).Mul(positionLiquidity, _q96)
			positionLiquidityX96x = positionLiquidityX96x.Mul(positionLiquidityX96x, u256.NewUint(1_000_000_000))

			poolTotalStakedLiquidityX96 := new(u256.Uint).Mul(poolTotalStakedLiquidity, _q96)

			positionLiquidityRatio := new(u256.Uint).Div(positionLiquidityX96x, poolTotalStakedLiquidityX96)         // this value needs to be divided by 1_000_000_000
			positionLiquidityRatio = positionLiquidityRatio.Mul(positionLiquidityRatio, _q96)                        // so first mul consts.Q96
			positionLiquidityRatio = positionLiquidityRatio.Div(positionLiquidityRatio, u256.NewUint(1_000_000_000)) // then divided by 1_000_000_000

			positionsLiquidityRatio[tokenId] = positionLiquidityRatio

			// poolsPositions
			poolsPositions[poolPath] = append(poolsPositions[poolPath], tokenId)
		}
	}

	// calculate external gns amounts
	totalExternalGns := externalGnsAmount()

	totalExternalGns += externalDepositGnsAmount()

	// calculate pool
	stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)

	stakerGnsBalance -= totalExternalGns

	mintedGnsAmount := stakerGnsBalance - lastCalculatedBalance

	lastCalculatedBalance = stakerGnsBalance

	duration := height - lastCalculatedHeight

	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(mintedGnsAmount)
	tier1Num, tier2Num, tier3Num := getNumPoolTiers()

	var eachTier1Amount, eachTier2Amount, eachTier3Amount uint64
	if tier1Num > 0 {
		eachTier1Amount = tier1Amount / tier1Num
	}

	if tier2Num > 0 {
		eachTier2Amount = tier2Amount / tier2Num
	}

	if tier3Num > 0 {
		eachTier3Amount = tier3Amount / tier3Num
	}

	// 인터널 에미션 대상 풀 수만큼 반복
	for poolPath, internal := range poolTiers {

		tier := internal.tier

		tierAmount := uint64(0)
		if tier == 1 {
			tierAmount = eachTier1Amount
		} else if tier == 2 {
			tierAmount = eachTier2Amount
		} else if tier == 3 {
			tierAmount = eachTier3Amount
		}

		poolGns[poolPath] += tierAmount
		poolAccuGns[poolPath] += tierAmount

		// current block minted gns + left from last block distributed gns
		poolCurrentBlockGns[poolPath] = tierAmount

		poolCurrentBlockGns[poolPath] += poolLastTmpGns[poolPath]

		poolLastTmpGns[poolPath] = 0

		totalStakedLiquidity, exist := poolTotalStakedLiquidity[poolPath]

		if exist == false || totalStakedLiquidity.IsZero() {

			send := min(poolGns[poolPath], stakerGnsBalance-totalExternalGns)

			gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), send)
			std.Emit(
				"CommunityPoolEmptyEmission",
				"prevAddr", prevAddr,
				"prevRealm", prevRealm,
				"internal_poolPath", poolPath,
				"internal_amount", ufmt.Sprintf("%d", send),
			)

			poolGns[poolPath] = 0
			poolCurrentBlockGns[poolPath] = 0

			// gns send happens, so update last calculated balance
			_stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)
			lastCalculatedBalance = _stakerGnsBalance - totalExternalGns

		}
	}

	// 전체 포지션 반복
	for tokenId, deposit := range deposits { // 찐 대상만
		poolPath := deposit.targetPoolPath
		poolCurrentBlockAmount := poolCurrentBlockGns[poolPath]

		// ------------------------------------ INTERNAL
		if poolCurrentBlockAmount > 0 {
			// calculate position gns rewards
			liqRatioX96, exist := positionsLiquidityRatio[tokenId]

			if exist == false || liqRatioX96.IsZero() {

				continue
			}

			positionAmountX96 := u256.Zero().Mul(u256.NewUint(poolCurrentBlockAmount), liqRatioX96)
			positionAmountX := u256.Zero().Div(positionAmountX96, _q96)
			positionAmount := positionAmountX.Uint64()

			// XXX: REMOVE AFTER QA

			positionLastGns[tokenId] = positionGns[tokenId]
			positionGns[tokenId] += positionAmount
			poolLastTmpGns[poolPath] += positionAmount

			// calculate internal amount from previous to now
			rewardMathComputeInternalRewardAmount(tokenId)
		}

	}

	// update flag

	lastCalculatedHeight = height

	lastCalculatedBalance = gnsBalance(consts.STAKER_ADDR) - totalExternalGns // latest balance

	// 인터널 에미션 대상 풀 수만큼 반복
	for poolPath, _ := range poolTiers {
		amount := poolLastTmpGns[poolPath]

		if amount > 0 {
			if poolCurrentBlockGns[poolPath] >= amount {
				poolLastTmpGns[poolPath] = poolCurrentBlockGns[poolPath] - amount
			} else {
				poolCurrentBlockGns[poolPath] = 0
			}
		}
	}

	// clear(poolCurrentBlockGns) // gno doesn't support `clear` keyword yet
	poolCurrentBlockGns = make(map[string]uint64)

	// ------------------------------------ EXTERNAL
	external := NewExternalCalculator(height)
	external.calculate(incentives) // XXX: no returning any value?
}

func externalGnsAmount() uint64 {
	amount := uint64(0)
	for _, v := range externalGns {
		amount += v
	}
	return amount
}

func externalDepositGnsAmount() uint64 {
	amount := uint64(0)

	for _, incentive := range incentives {
		amount += incentive.depositGnsAmount
	}

	return amount
}
