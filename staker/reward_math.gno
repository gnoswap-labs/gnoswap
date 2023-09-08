package staker

import (
	s "gno.land/r/position"

	"gno.land/p/demo/ufmt"
)

func rewardMathComputeInternalRewardAmount(tokenId bigint, deposit Deposit) bigint {
	// r3v4_xxx: calculate amount of `GNOS` to be minted by every block
	// 1. get block creation time (5s for now)
	// 2. calculate amount of `GNOS` to be minted by every block (10_000 for now)
	// 3. above `GNOS amount`` is supposed to be minted to a separate wallet specified by onbloc
	// 4. this logic is supposed to be included in GNOS token contract, not staker contract
	blockReward := bigint(10_000)

	// get pool tier and ratio
	poolPath := s.PositionGetPositionPoolKey(tokenId)
	poolTier, poolRatioX10 := getPoolTierAndRatio(poolPath)

	// get pool reward per block
	poolRatioX96 := bigint(poolRatioX10) * Q96 / 10
	poolRewardPerBlockX96 := (blockReward * Q96) * poolRatioX96

	// calculate my liquidity ratio
	myLiquidityRatioX96 := getMyLiquidityRatio(poolPath, tokenId)

	// calculate my actual reward amount based on staking duration
	// !IMPORTANT
	// r3v4_xx: assume block calcution will happen every 1 block
	// unlikely external, internal reward program is supposed to be started at the same time as gnoswap launch and never end
	// so there is no need to consider start/end time of reward program
	// start time is staked time, end time is current time
	startTime := deposit.stakeTimestamp
	endTime := GetTimestamp()
	stakedDuration := endTime - startTime
	rewardRatio := getRewardRatio(stakedDuration)

	// get all ratio for this pool
	wholeRatioX96 := getAllRatio(poolPath)

	finalRewardX96 := (myLiquidityRatioX96 * rewardRatio / 10) * Q96 / wholeRatioX96 * Q96 * poolRewardPerBlockX96
	finalReward := finalRewardX96 / Q96 / Q96 / Q96 / Q96

	return finalReward
}

func rewardMathComputeExternalRewardAmount(tokenId bigint, deposit Deposit, incentive Incentive) bigint {
	// 1 month reward amount
	incentiveDuration := incentive.endTimestamp - incentive.startTimestamp
	monthlyReward := bigint(0)

	switch {
	case incentiveDuration == TIMESTAMP_30DAYS:
		monthlyReward = incentive.rewardAmount
	case incentiveDuration > TIMESTAMP_30DAYS:
		// 1 second reward == total reward amount / reward duration
		monthlyReward = incentive.rewardAmount / incentiveDuration * TIMESTAMP_30DAYS
	default:
		panic(ufmt.Sprintf("[STAKER] reward_math.gno || incentiveDuration(%s) at least 30 days", incentiveDuration))
	}

	// calculate reward amount per block

	// 1 month = 2592000 seconds
	// (for now) block creation time = 5 seconds
	// 518400(2592000/5) blocks ~= 1 month
	// 1 month reward / 518400 = reward per block
	blockRewardX96 := (monthlyReward / 518400) * Q96
	println("OBL BLOCK:", blockRewardX96/Q96)

	// calculate my liquidity ratio
	poolPath := deposit.targetPoolPath
	myLiquidityRatioX96 := getMyLiquidityRatio(poolPath, tokenId)

	// calculate my actual reward amount based on staking duration
	// !IMPORTANT
	// r3v4_xx: assume block calcution will happen every 1 block

	// stake start time ( largest value between incentive start time and deposit stake time )
	// stake end time ( smallest value between incentive end time and current time)
	startTime := max(incentive.startTimestamp, deposit.stakeTimestamp)
	endTime := min(incentive.endTimestamp, GetTimestamp())
	stakedDuration := endTime - startTime
	rewardRatio := getRewardRatio(stakedDuration)

	// get all ratio for this pool
	wholeRatioX96 := getAllRatio(poolPath)

	finalRewardX96 := (myLiquidityRatioX96 * rewardRatio / 10) * Q96 / wholeRatioX96 * Q96 * blockRewardX96
	finalReward := finalRewardX96 / Q96 / Q96 / Q96

	return finalReward
}

func getPoolTotalStakedLiquidity(poolPath string) bigint {
	poolStakedLiquidity := bigint(0)
	for tokenId, deposit := range deposits { //tokenId => Deposit
		if deposit.targetPoolPath == poolPath {
			tokenLiquidity := s.PositionGetPositionLiquidity(tokenId)
			poolStakedLiquidity += tokenLiquidity
		}
	}

	return poolStakedLiquidity
}

func getMyLiquidityRatio(poolPath string, tokenId bigint) bigint {
	poolStakedLiquidity := getPoolTotalStakedLiquidity(poolPath)

	// my(current tokenId) liquidity
	myLiquidity := s.PositionGetPositionLiquidity(tokenId)

	// my liquidity ratio
	liqRatioX96 := (myLiquidity * Q96 / poolStakedLiquidity * Q96) / Q96

	return liqRatioX96
}

func getAllRatio(poolPath string) bigint {
	poolStakedLiquidity := getPoolTotalStakedLiquidity(poolPath)

	totalRewardRatioX96 := bigint(0)
	for tokenId, deposit := range deposits {
		if deposit.targetPoolPath == poolPath {
			liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)

			// how many seconds staked
			stakedDuration := getStakedDuration(deposit)
			rewardRatio := getRewardRatio(stakedDuration)
			totalRewardRatioX96 += (liqRatioX96 * rewardRatio / 10)
		}
	}

	return totalRewardRatioX96
}

// get current pool tier and reward ratio
func getPoolTierAndRatio(poolPath string) (bigint, bigint) {
	poolPath = poolKeyDivide(poolPath)

	// current pool's tier
	tier, ok := poolTiers[poolPath]
	if !ok {
		return 0, 0
	}

	// that tiers ratio
	ratio := getTierRatio(tier)

	// finally current pools ratio
	numTier1, numTier2, numTier3 := getNumPoolTiers()

	var weight float64
	switch tier {
	case 1:
		weight = ratio / float64(numTier1)
	case 2:
		weight = ratio / float64(numTier2)
	case 3:
		weight = ratio / float64(numTier3)
	default:
		panic(ufmt.Sprintf("UNKNOWN TIER %s", tier))
	}

	return tier, bigint(int(weight * 10))
}

// get number of pools for each tier
func getNumPoolTiers() (uint64, uint64, uint64) {
	var tier1, tier2, tier3 uint64

	for _, v := range poolTiers {
		switch v {
		case 1:
			tier1++
		case 2:
			tier2++
		case 3:
			tier3++
		default:
			continue
		}
	}

	return tier1, tier2, tier3
}

// get staked duration
func getStakedDuration(deposit Deposit) bigint {
	startTime := deposit.stakeTimestamp
	endTime := GetTimestamp()
	stakedDuration := endTime - startTime

	return stakedDuration
}

// get reward ratio from staking tier
func getRewardRatio(timestamp bigint) bigint {
	var weight float64
	switch {
	case timestamp >= 2592001: // 30d 1s ~
		weight = 1.5
		break
	case timestamp >= 864001: // 10d 1s ~ 30d
		weight = 1
		break
	case timestamp >= 432001: // 5d 1s ~ 10d
		weight = 0.7
		break
	case timestamp >= 6: // 5s[at least block creation time] ~ 5d
		weight = 0.5
		break
	default: // below block creation time
		weight = 0.0
		break
	}

	// this is weight
	return bigint(int(weight * 10))
}

// return all ratio for each tier
func listTierRatio() (float64, float64, float64) {
	// basic
	// tier1 50%
	// tier2 30%
	// tier3 20%

	numTier1, numTier2, numTier3 := getNumPoolTiers()
	require(numTier1 > 0, ufmt.Sprintf("[STAKER] staker.gno__getTierRatio() || numTier1(%s) > 0 (numTier2:(%s), numTier3:(%s))", numTier1, numTier2, numTier3))

	if numTier2 == 0 && numTier3 == 0 { // only tier 1 exists
		return 1.0, 0.0, 0.0
	} else if numTier2 == 0 && numTier3 >= 1 { // tier 1 and 3 exists ( tier2 ratio goes to tier1 )
		return 0.8, 0.0, 0.2
	} else if numTier2 >= 1 && numTier3 == 0 { // tier 1 and 2 exists ( tier3 ratio goes to tier1 )
		return 0.7, 0.3, 0.0
	} else if numTier2 >= 1 && numTier3 >= 1 { // all tiers exists
		return 0.5, 0.3, 0.2
	} else {
		panic("[STAKER] staker.gno__getTierRatio() || invalid tier ratio")
	}
}

func getTierRatio(tier bigint) float64 {
	require(tier >= 1 && tier <= 3, ufmt.Sprintf("[STAKER] staker.gno__getTierRatio() || tier(%s) >= 1 && tier(%s) <= 3", tier, tier))

	ratio1, ratio2, ratio3 := listTierRatio()
	switch tier {
	case 1:
		return ratio1
	case 2:
		return ratio2
	case 3:
		return ratio3
	default:
		panic("[STAKER] staker.gno__getTierRatio() || invalid ratio")
	}
}
