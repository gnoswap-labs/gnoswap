package staker

import (
	"std"
	"time"

	"gno.land/r/gnoswap/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/demo/big/uint256"

	pos "gno.land/r/demo/position"
)

type userClaimedReward map[std.Address]map[uint64]map[string]*u256.Uint // address -> lpTokenId -> rewardTokenPath -> rewardTokenAmount
var userClaimedRewards = make(userClaimedReward)

func userClaimedRewardAmount(address std.Address, tokenId uint64, rewardTokenPath string, rewardAmount *u256.Uint, claimeRequest bool) *u256.Uint {
	userClaimed, ok := userClaimedRewards[address] // if user(address) ever claimed reward
	if !ok {
		userClaimedRewards[address] = make(map[uint64]map[string]*u256.Uint)
	}

	claimedPosition, ok := userClaimedRewards[address][tokenId] // if user(address) ever claimed reward from tokenId
	if !ok {
		userClaimedRewards[address][tokenId] = make(map[string]*u256.Uint)
	}

	claimedReward, ok := userClaimedRewards[address][tokenId][rewardTokenPath] // if user(address) ever claimed rewardTokenPath
	if !ok {
		if claimeRequest { // if user is claiming rewardTokenPath
			userClaimedRewards[address][tokenId][rewardTokenPath] = rewardAmount // add rewardTokenPath to userClaimedRewards
			return rewardAmount
		} else { // if user is not claiming rewardTokenPath
			return rewardAmount
		}
	}

	// user ever claimed rewardTokenPath
	var claimableAmount *u256.Uint
	if claimeRequest { // if user is claiming rewardTokenPath
		claimableAmount = new(u256.Uint).Sub(rewardAmount, claimedReward)
		userClaimedRewards[address][tokenId][rewardTokenPath] = new(u256.Uint).Add(userClaimedRewards[address][tokenId][rewardTokenPath], claimableAmount)
		return claimableAmount
	} else { // if user is not claiming rewardTokenPath
		claimableAmount = new(u256.Uint).Sub(rewardAmount, claimedReward)
		return claimableAmount
	}
}

func rewardMathComputeInternalRewardAmount(tokenId uint64, deposit Deposit) *u256.Uint {
	_q96 := u256.MustFromDecimal(consts.Q96)

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
	poolRewardPerBlockX96 := new(u256.Uint).Mul(u256.NewUint(uint64(blockReward)), poolRatioX96)

	// calculate my reward amount based on my liquidity ratio
	// this reward is 31days or more staking reward
	liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)
	myBlockRewardX96 := new(u256.Uint).Mul(poolRewardPerBlockX96, liqRatioX96)
	myBlockRewardX96 = new(u256.Uint).Div(myBlockRewardX96, _q96)

	// calculate my actual reward amount based on staking duration
	// !IMPORTANT
	// r3v4_xxx: assume block calcution will happen every 1 block
	// unlikely external, internal reward program is supposed to be started at the same time as gnoswap launch and never end
	// so there is no need to consider start/end time of reward program
	// start time is staked time, end time is current time
	startTime := deposit.stakeTimestamp
	endTime := time.Now().Unix()
	stakedDuration := endTime - startTime

	numBlockStaked := uint64(stakedDuration / consts.BLOCK_GENERATION_INTERVAL)
	myWholeRewardX96 := new(u256.Uint).Mul(myBlockRewardX96, u256.NewUint(numBlockStaked))

	rewardRatio := getRewardRatio(stakedDuration)
	finalRewardBig := new(u256.Uint).Mul(myWholeRewardX96, u256.NewUint(rewardRatio))

	finalReward := new(u256.Uint).Div(finalRewardBig, _q96)
	finalReward = new(u256.Uint).Div(finalReward, u256.NewUint(200))
	// divide by (100 ^ 2)
	// #1: to convert `listTierRatio()` return value to percentage
	// #2: to convert `getRewardRatio()` return value to percentage

	return finalReward
}

func rewardMathComputeExternalRewardAmount(tokenId uint64, deposit Deposit, incentive Incentive) *u256.Uint {
	_q96 := u256.MustFromDecimal(consts.Q96)

	// 1 month reward amount
	incentiveDuration := incentive.endTimestamp - incentive.startTimestamp
	monthlyReward := u256.Zero()

	switch {
	case incentiveDuration == TIMESTAMP_90DAYS:
		monthlyReward = new(u256.Uint).Div(incentive.rewardAmount, u256.NewUint(3))
	case incentiveDuration > TIMESTAMP_90DAYS:
		// 1 second reward == total reward amount / reward duration
		_rewardPerSecond := new(u256.Uint).Div(incentive.rewardAmount, u256.NewUint(uint64(incentiveDuration)))
		// 30 days ≈ 2592000 seconds
		monthlyReward = new(u256.Uint).Mul(_rewardPerSecond, u256.NewUint(2592000))
	default:
		panic(ufmt.Sprintf("[STAKER] reward_math.gno || incentiveDuration(%d) should be at least 90 days", incentiveDuration))
	}

	// calculate reward amount per block
	// 1 month = 2592000 seconds
	// (for now) block creation time = 5 seconds
	// 518400(2592000/5) blocks ~= 1 month
	// 1 month reward / 518400 = reward per block
	blockRewardInit := new(u256.Uint).Div(monthlyReward, u256.NewUint(518400))
	// because of `~ 10 days` staking duration, certain block's ExternalRewardAmount won't be distribute 100% as reward)
	blockRewardLeft := new(u256.Uint).Div(blockRewardInit, u256.NewUint(10)) // obl.BalanceOf(INTERNAL_REWARD_ACCOUNT) - blockRewardInit
	blockReward := new(u256.Uint).Add(blockRewardInit, blockRewardLeft)
	blockRewardX96 := new(u256.Uint).Mul(blockReward, _q96)

	// calculate my reward amount based on my liquidity ratio
	// this reward is 31days or more staking reward
	liqRatioX96 := getMyLiquidityRatio(incentive.targetPoolPath, tokenId)

	myBlockRewardX96 := new(u256.Uint).Mul(blockRewardX96, liqRatioX96)
	myBlockRewardX96 = new(u256.Uint).Div(myBlockRewardX96, _q96)

	// calculate my actual reward amount based on staking duration
	// !IMPORTANT
	// r3v4_xxx: assume block calcution will happen every 1 block
	// stake start time ( largest value between incentive start time and deposit stake time )
	// stake end time ( smallest value between incentive end time and current time)
	startTime := max(incentive.startTimestamp, deposit.stakeTimestamp)
	endTime := min(incentive.endTimestamp, time.Now().Unix())
	stakedDuration := endTime - startTime

	numBlockStaked := uint64(stakedDuration / consts.BLOCK_GENERATION_INTERVAL)
	myWholeRewardX96 := new(u256.Uint).Mul(myBlockRewardX96, u256.NewUint(numBlockStaked))

	rewardRatio := getRewardRatio(stakedDuration)
	finalRewardBig := new(u256.Uint).Mul(myWholeRewardX96, u256.NewUint(rewardRatio))

	finalReward := new(u256.Uint).Div(finalRewardBig, _q96)
	finalReward = new(u256.Uint).Div(finalReward, u256.NewUint(100))
	// divide by 100
	// to convert `getRewardRatio()` return value to percentage

	return finalReward
}

func getPoolTotalStakedLiquidity(poolPath string) *u256.Uint {
	poolStakedLiquidity := u256.Zero()
	// get all staked liquidity
	for tokenId, deposit := range deposits { // key is tokenId // used in this range loop only
		if deposit.targetPoolPath == poolPath {
			tokenLiquidity := pos.PositionGetPositionLiquidity(tokenId)
			poolStakedLiquidity = new(u256.Uint).Add(poolStakedLiquidity, tokenLiquidity)
		}
	}

	return poolStakedLiquidity
}

func getMyLiquidityRatio(poolPath string, tokenId uint64) *u256.Uint {
	_q96 := u256.MustFromDecimal(consts.Q96)

	poolStakedLiquidity := getPoolTotalStakedLiquidity(poolPath)

	// my(current tokenId) liquidity
	myLiquidity := pos.PositionGetPositionLiquidity(tokenId)

	// my liquidity ratio
	myLiquidityX96 := new(u256.Uint).Mul(myLiquidity, _q96)
	myLiquidityX96 = new(u256.Uint).Mul(myLiquidityX96, u256.NewUint(100)) // mul `100` to bypass #179 being 0

	poolStakedLiquidityX96 := new(u256.Uint).Mul(poolStakedLiquidity, _q96)

	myLiquidityRatio := new(u256.Uint).Div(myLiquidityX96, poolStakedLiquidityX96) // this value needs to be divided by 100
	myLiquidityRatio = new(u256.Uint).Mul(myLiquidityRatio, _q96)                  // so first mul consts.Q96
	myLiquidityRatioX96 := new(u256.Uint).Div(myLiquidityRatio, u256.NewUint(100)) // then divided by 100

	return myLiquidityRatioX96
}

// get current pool tier and reward ratio
func getPoolTierAndRatio(poolPath string) (uint64, *u256.Uint) {
	_q96 := u256.MustFromDecimal(consts.Q96)

	poolPath = poolKeyDivide(poolPath)

	// current pool's tier
	tier, ok := poolTiers[poolPath]
	if !ok {
		return 0, u256.Zero()
	}

	// that tiers ratio
	ratio := getTierRatio(tier)
	ratioX96 := new(u256.Uint).Mul(u256.NewUint(ratio), _q96) // first consts.Q96

	// finally current pools ratio
	numTier1, numTier2, numTier3 := getNumPoolTiers()

	var weight *u256.Uint
	switch tier {
	case 1:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier1))
	case 2:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier2))
	case 3:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier3))
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

func getTierRatio(tier uint64) uint64 {
	if tier < 1 || tier > 3 {
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__getTierRatio() || tier(%d) must be 1 ~ 3", tier))
	}

	ratio1, ratio2, ratio3 := listTierRatio()
	switch tier {
	case 1:
		return ratio1 // default 50
	case 2:
		return ratio2 // default 30
	case 3:
		return ratio3 // default 20
	default:
		panic("[STAKER] reward_math.gno__getTierRatio() || invalid ratio")
	}
}

// return all ratio for each tier
func listTierRatio() (uint64, uint64, uint64) {
	// basic
	// tier1 50%
	// tier2 30%
	// tier3 20%

	// since `float` type has determinisim issue, we use `int` instead
	// so instead of return 50%, we return 50
	// we'll divide by 100 later

	numTier1, numTier2, numTier3 := getNumPoolTiers()
	if numTier1 <= 0 {
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__listTierRatio() || at least 1 numTier1 need(%d), [numTier2:(%d), numTier3:(%d)]", numTier1, numTier2, numTier3))
	}

	if numTier2 == 0 && numTier3 == 0 { // only tier 1 exists
		return 100, 0, 0
	} else if numTier2 == 0 && numTier3 >= 1 { // tier 1 and 3 exists ( tier2 ratio goes to tier1 )
		return 80, 0, 20
	} else if numTier2 >= 1 && numTier3 == 0 { // tier 1 and 2 exists ( tier3 ratio goes to tier1 )
		return 70, 30, 0
	} else if numTier2 >= 1 && numTier3 >= 1 { // all tiers exists
		return 50, 30, 20
	} else {
		panic("[STAKER] reward_math.gno__listTierRatio() || invalid tier ratio")
	}
}
