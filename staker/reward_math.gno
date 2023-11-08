package staker

import (
	"gno.land/p/demo/ufmt"

	pos "gno.land/r/position"
)

func rewardMathComputeInternalRewardAmount(tokenId uint64, deposit Deposit) uint64 {
	// r3v4_xxx: calculate amount of `GNS` to be minted by every block
	// 1. get block creation time (5s for now)
	// 2. calculate amount of `GNS` to be minted by every block (10_000 for now)
	// 3. above `GNS amount`` is supposed to be minted to a separate wallet specified by onbloc
	// 4. this logic is supposed to be included in GNS token contract, not staker contract
	blockRewardInit := 10_000
	// because of `~ 10 days` staking duration, certain block GNS amount won't be distribute 100% as reward)
	blockRewardLeft := blockRewardInit / 10 // gns.BalanceOf(INTERNAL_REWARD_ACCOUNT) - blockRewardInit
	blockReward := blockRewardInit + blockRewardLeft

	// get pool tier and ratio
	poolPath := pos.PositionGetPositionPoolKey(tokenId)
	_, poolRatioX96 := getPoolTierAndRatio(poolPath)

	// get pool reward per block
	poolRewardPerBlockX96 := (bigint(blockReward) * Q96) * poolRatioX96

	// calculate my reward amount based on my liquidity ratio
	// this reward is 31days or more staking reward
	liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)
	myWholeRewardX96 := poolRewardPerBlockX96 * liqRatioX96

	// calculate my actual reward amount based on staking duration
	// !IMPORTANT
	// r3v4_xxx: assume block calcution will happen every 1 block
	// unlikely external, internal reward program is supposed to be started at the same time as gnoswap launch and never end
	// so there is no need to consider start/end time of reward program
	// start time is staked time, end time is current time
	startTime := deposit.stakeTimestamp
	endTime := GetTimestamp()
	stakedDuration := endTime - startTime
	rewardRatio := getRewardRatio(stakedDuration)

	finalRewardQ := myWholeRewardX96 * bigint(rewardRatio)
	finalReward := finalRewardQ / Q96 / Q96 / Q96 / Q96 / Q96 / 100 / 100
	// why do we need to divide by (Q96 ^ 5)
	// #1 ~ 2: used by getPoolTierAndRatio()
	// #3    : used by poolRewardPerBlockX96
	// #4 ~ 5: used by getMyLiquidityRatio()

	// why do we need to divide by (100 ^ 2)
	// #1: to convert `listTierRatio()` return value to percentage
	// #2: to convert `getRewardRatio()` return value to percentage

	return uint64(finalReward)
}

func rewardMathComputeExternalRewardAmount(tokenId uint64, deposit Deposit, incentive Incentive) uint64 {
	// 1 month reward amount
	incentiveDuration := incentive.endTimestamp - incentive.startTimestamp
	monthlyReward := uint64(0)

	switch {
	case incentiveDuration == TIMESTAMP_30DAYS:
		monthlyReward = incentive.rewardAmount
	case incentiveDuration > TIMESTAMP_30DAYS:
		// 1 second reward == total reward amount / reward duration
		monthlyReward = incentive.rewardAmount / uint64(incentiveDuration) * uint64(TIMESTAMP_30DAYS)
	default:
		panic(ufmt.Sprintf("[STAKER] reward_math.gno || incentiveDuration(%d) at least 30 days", incentiveDuration))
	}

	// calculate reward amount per block
	// 1 month = 2592000 seconds
	// (for now) block creation time = 5 seconds
	// 518400(2592000/5) blocks ~= 1 month
	// 1 month reward / 518400 = reward per block
	blockRewardInit := monthlyReward / 518400
	// because of `~ 10 days` staking duration, certain block ONBLOC amount won't be distribute 100% as reward)
	blockRewardLeft := blockRewardInit / 10 // obl.BalanceOf(INTERNAL_REWARD_ACCOUNT) - blockRewardInit
	blockReward := blockRewardInit + blockRewardLeft
	blockRewardX96 := bigint(blockReward) * Q96

	// calculate my reward amount based on my liquidity ratio
	// this reward is 31days or more staking reward
	liqRatioX96 := getMyLiquidityRatio(incentive.targetPoolPath, tokenId)
	myWholeRewardX96 := blockRewardX96 * liqRatioX96

	// calculate my actual reward amount based on staking duration
	// !IMPORTANT
	// r3v4_xxx: assume block calcution will happen every 1 block
	// stake start time ( largest value between incentive start time and deposit stake time )
	// stake end time ( smallest value between incentive end time and current time)
	startTime := max(incentive.startTimestamp, deposit.stakeTimestamp)
	endTime := min(incentive.endTimestamp, GetTimestamp())
	stakedDuration := endTime - startTime
	rewardRatio := getRewardRatio(stakedDuration)

	finalRewardQ := myWholeRewardX96 * bigint(rewardRatio)
	finalReward := finalRewardQ / Q96 / Q96 / Q96 / 100
	// why do we need to divide by (96 ^ 3)
	// #1    : used by blockRewardX96
	// #2 ~ 3: used by func getMyLiquidityRatio()

	// why do we need to divide by 100
	// to convert `getRewardRatio()` return value to percentage

	return uint64(finalReward)
}

func getPoolTotalStakedLiquidity(poolPath string) bigint {
	poolStakedLiquidity := bigint(0)
	// get all staked liquidity
	for tokenId, deposit := range deposits { // key is tokenId // used in this range loop only
		if deposit.targetPoolPath == poolPath {
			tokenLiquidity := pos.PositionGetPositionLiquidity(tokenId)
			poolStakedLiquidity += tokenLiquidity
		}
	}

	return poolStakedLiquidity
}

func getMyLiquidityRatio(poolPath string, tokenId uint64) bigint {
	poolStakedLiquidity := getPoolTotalStakedLiquidity(poolPath)

	// my(current tokenId) liquidity
	myLiquidity := pos.PositionGetPositionLiquidity(tokenId)

	// my liquidity ratio
	liqRatioX96 := (myLiquidity * Q96 / poolStakedLiquidity * Q96) // 2 times Q96 because of Q96 / Q96

	return liqRatioX96
}

// get current pool tier and reward ratio
func getPoolTierAndRatio(poolPath string) (uint8, bigint) {
	poolPath = poolKeyDivide(poolPath)

	// current pool's tier
	tier, ok := poolTiers[poolPath]
	if !ok {
		return 0, 0
	}

	// that tiers ratio
	ratio := getTierRatio(tier)
	ratioX96 := bigint(uint64(ratio)) * Q96 // first Q96

	// finally current pools ratio
	numTier1, numTier2, numTier3 := getNumPoolTiers()

	var weight bigint
	switch tier {
	case 1:
		weight = ratioX96 / bigint(numTier1) * Q96 // second Q96
	case 2:
		weight = ratioX96 / bigint(numTier2) * Q96
	case 3:
		weight = ratioX96 / bigint(numTier3) * Q96
	default:
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__getPoolTierAndRatio() || invalid tier(%d)", tier))
	}

	return tier, weight
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
			panic(ufmt.Sprintf("[STAKER] reward_math.gno__getNumPoolTiers() || invalid tier(%d)", v))
		}
	}

	return tier1, tier2, tier3
}

// get staking tier
func getRewardRatio(timestamp int64) uint64 {
	// since `float` type has determinisim issue, we use `int` instead
	// so instead of return 50%, we return 50
	// we'll divide by 100 later

	var ratio uint64
	switch {
	case timestamp >= 2592001: // 30d 1s ~
		ratio = 100
		break
	case timestamp >= 864001: // 10d 1s ~ 30d
		ratio = 70
		break
	case timestamp >= 432001: // 5d 1s ~ 10d
		ratio = 50
		break
	case timestamp >= 5: // 5s ~ 5d (5s is block creation time)
		ratio = 30
		break
	default: // ~ 4s
		ratio = 0
		break
	}

	return ratio
}

func getTierRatio(tier uint8) uint8 {
	require(tier >= 1 && tier <= 3, ufmt.Sprintf("[STAKER] staker.gno__getTierRatio() || tier(%d) >= 1 && tier(%d) <= 3", tier, tier))

	ratio1, ratio2, ratio3 := listTierRatio()
	switch tier {
	case 1:
		return ratio1 // default 50
	case 2:
		return ratio2 // default 30
	case 3:
		return ratio3 // default 20
	default:
		panic("[STAKER] staker.gno__getTierRatio() || invalid ratio")
	}
}

// return all ratio for each tier
func listTierRatio() (uint8, uint8, uint8) {
	// basic
	// tier1 50%
	// tier2 30%
	// tier3 20%

	// since `float` type has determinisim issue, we use `int` instead
	// so instead of return 50%, we return 50
	// we'll divide by 100 later

	numTier1, numTier2, numTier3 := getNumPoolTiers()
	require(numTier1 > 0, ufmt.Sprintf("[STAKER] staker.gno__listTierRatio() || numTier1(%d) > 0 (numTier2:(%d), numTier3:(%d))", numTier1, numTier2, numTier3))

	if numTier2 == 0 && numTier3 == 0 { // only tier 1 exists
		return 100, 0, 0
	} else if numTier2 == 0 && numTier3 >= 1 { // tier 1 and 3 exists ( tier2 ratio goes to tier1 )
		return 80, 0, 20
	} else if numTier2 >= 1 && numTier3 == 0 { // tier 1 and 2 exists ( tier3 ratio goes to tier1 )
		return 70, 30, 0
	} else if numTier2 >= 1 && numTier3 >= 1 { // all tiers exists
		return 50, 30, 20
	} else {
		panic("[STAKER] staker.gno__listTierRatio() || invalid tier ratio")
	}
}
