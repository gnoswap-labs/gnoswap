package staker

import (
	s "gno.land/r/position"

	"gno.land/p/demo/ufmt"
)

func rewardMathComputeInternalRewardAmount(tokenId bigint, deposit Deposit) bigint {
	// r3v4_xxx: calculate amount of `GNOS` to be minted by every block
	// 1. get block creation time (5s for now)
	// 2. calculate amount of `GNOS` to be minted by every block (10_000_000 for now)
	// 3. above `GNOS amount`` is supposed to be minted to a separate wallet specified by onbloc
	// 4. this logic is supposed to be included in GNOS token contract, not staker contract
	blockReward := bigint(10_000_000)

	// unlikely external, internal reward program is supposed to be started at the same time as gnoswap launch and never end
	// so no need to consider start/end time of reward program
	// start time is staked time, end time is current time
	startTime := deposit.stakeTimestamp
	endTime := GetTimestamp()
	stakeDuration := endTime - startTime

	// get pool tier and ratio
	poolPath := s.PositionGetPositionPoolKey(tokenId)
	poolTier, poolRatio := getPoolTierAndRatio(poolPath)

	// get pool reward per block
	intPoolRatio := int(poolRatio * 10)
	poolRatioX96 := bigint(intPoolRatio) * Q96
	poolRewardPerBlockX96 := (blockReward * Q96) * poolRatioX96 / 10

	// calculate my reward amount based on my liquidity ratio
	// this reward is 31days or more staking reward
	liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)
	myWholeRewardX96 := poolRewardPerBlockX96 * liqRatioX96

	// calculate my actual reward amount based on staking duration
	rewardRatio := getStakingTier(stakeDuration)
	intRewardRatio := int(rewardRatio * 10)
	rewardRatioX96 := bigint(intRewardRatio) * Q96
	myActualReward := myWholeRewardX96 * (rewardRatioX96 / 10) / Q96 / Q96 / Q96 / Q96 / Q96
	return myActualReward
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
	blockReward := monthlyReward / 5184000

	// stake start time ( largest value between incentive start time and deposit stake time )
	// stake end time ( smallest value between incentive end time and current time)
	startTime := max(incentive.startTimestamp, deposit.stakeTimestamp)
	endTime := min(incentive.endTimestamp, GetTimestamp())
	// staking duration
	stakeDuration := endTime - startTime

	// reward per block in X96
	blockRewardX96 := blockReward * Q96

	// calculate my reward amount based on my liquidity ratio
	// this reward is 31days or more staking reward
	liqRatioX96 := getMyLiquidityRatio(incentive.targetPoolPath, tokenId)
	myWholeRewardX96 := blockRewardX96 * liqRatioX96

	// calculate my actual reward amount based on staking duration
	rewardRatio := getStakingTier(stakeDuration)
	intRewardRatio := int(rewardRatio * 10)
	rewardRatioX96 := bigint(intRewardRatio) * Q96
	myActualReward := myWholeRewardX96 * (rewardRatioX96 / 10) / Q96 / Q96 / Q96 / Q96

	return myActualReward
}

func getMyLiquidityRatio(poolPath string, tokenId bigint) bigint {
	poolStakedLiquidity := bigint(0)
	// get all staked liquidity
	for k, deposit := range deposits {
		if deposit.targetPoolPath == poolPath {
			tokenLiquidity := s.PositionGetPositionLiquidity(k)
			poolStakedLiquidity += tokenLiquidity
		}
	}

	// my(current tokenId) liquidity
	myLiquidity := s.PositionGetPositionLiquidity(tokenId)

	// my liquidity ratio
	liqRatioX96 := (myLiquidity * Q96 / poolStakedLiquidity * Q96)

	return liqRatioX96
}
