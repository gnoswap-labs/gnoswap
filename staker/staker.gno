package staker

import (
	"std"
	"gno.land/p/demo/grc/grc20"

	position "gno.land/r/position"

	rt "gno.land/r/reward" // reward Token
	nft "gno.land/r/foo721" // nonfungibleToken
)


type Incentive struct {
	totalRewardUnclaimed bigint
	totalSecondsClaimedX128 bigint
	numberOfStakes bigint
}

type Stake struct {
	secondsPerLiquidityInsideInitialX128 bigint
	liquidityNoOverflow bigint
	liquidityIfOverflow bigint
}

type Deposit struct {
	owner std.Address
	numberOfStakes bigint
	tickLower bigint
	tickUpper bigint
}


var (
	factory std.Address
	// nonfungiblePositionManager interface{}
	maxIncentiveStartLeadTime bigint
	maxIncentiveDuration bigint

	incentives map[string]Incentive = make(map[string]Incentive)
	deposits map[string]Deposit = make(map[string]Deposit)
	stakes map[string]map[string]Stake = make(map[string]map[string]Stake)
	
	// IncentiveKey with rewardsToken
	// rewards map[interface{}]map[std.Address]bigint = make(map[interface{}]map[std.Address]bigint)

	// IncentiveKey without rewardsToken
	rewards map[std.Address]bigint = make(map[std.Address]bigint)
	
	// rewardToken *grc20.AdminToken
	initialized bool = false
)


func Init(
	// _factory std.Address, 
	// _nonfungiblePositionManager interface{},
	_maxIncentiveStartLeadTime bigint,
	_maxIncentiveDuration bigint,
) {
	// factory = _factory
	// nonfungiblePositionManager = _nonfungiblePositionManager
	
	// manual init needs
	require(!initialized, "Already initialized")
	maxIncentiveStartLeadTime = _maxIncentiveStartLeadTime
	maxIncentiveDuration = _maxIncentiveDuration
	initialized = true
}


func Stakes(
	tokenId string,
	incentiveId string,
) (secondsPerLiquidityInsideInitialX128, liquidity bigint) {
	stake := stakes[tokenId][incentiveId]
	secondsPerLiquidityInsideInitialX128 = stake.secondsPerLiquidityInsideInitialX128
	liquidity = stake.liquidityNoOverflow
	if (liquidity == MAX_UINT96) {
		liquidity = stake.liquidityIfOverflow
	}

	requireUnsigned(secondsPerLiquidityInsideInitialX128, "GnoswapStaker::Stakes: secondsPerLiquidityInsideInitialX128 is not unsigned")
	requireUnsigned(liquidity, "GnoswapStaker::Stakes: liquidity is not unsigned")
	return secondsPerLiquidityInsideInitialX128, liquidity
}


func CreateIncentive(key IncentiveKey, reward bigint) {
	require(reward > 0, "GnoswapStaker::CreateIncnetive: reward must be positive")

	require(
		GetTimestamp() <= key.startTime,
		"GnoswapStaker::CreateIncnetive: start time must be now or in the future",
	)
	require(
		(key.startTime - GetTimestamp()) <= maxIncentiveStartLeadTime,
		"GnoswapStaker::CreateIncnetive: start time too far into future",
	)
	require(key.startTime < key.endTime, "GnoswapStaker::CreateIncnetive: start time must be before end time")
	require(
		(key.endTime - key.startTime) <= maxIncentiveDuration,
		"GnoswapStaker::CreateIncnetive: incentive duration is too long",
	)
	
	incentiveId := IncentiveIdCompute(key)

	_update := incentives[incentiveId]
	_update.totalRewardUnclaimed += reward
	incentives[incentiveId] = _update

	// XXX
	// TransferHelperExtended.safeTransferFrom(std.Address(key.rewardToken), GetOrigCaller(), GetOrigPkgAddr(), reward)
	rt.Transfer(a2u(GetOrigPkgAddr()), uint64(reward))
}


func EndIncentive(key IncentiveKey) (refund bigint) {
	require(GetTimestamp() >= key.endTime, "GnoswapStaker::endIncentive: cannot end incentive before end time")

	incentiveId := IncentiveIdCompute(key)
	incentive := incentives[incentiveId]

	refund = incentive.totalRewardUnclaimed

	require(refund > bigint(0), "GnoswapStaker::endIncentive: no refund available")
	require(
			incentive.numberOfStakes == 0,
			"GnoswapStaker::endIncentive: cannot end incentive while deposits are staked",
	)

	// issue refund
	_updateIncentive := incentives[incentiveId]
	_updateIncentive.totalRewardUnclaimed = 0
	incentives[incentiveId] = _updateIncentive
	
	// XXX
	// TransferHelperExtended.safeTransfer(std.Address(key.rewardToken), GetOrigCaller(), GetOrigPkgAddr(), refund)
	_orig := GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	rt.Transfer(a2u(key.refundee), uint64(refund))
	std.TestSetOrigCaller(_orig)

	requireUnsigned(refund, "GnoswapStaker::endIncentive: refund is not unsigned")
	return refund
}


func TransferDeposit(tokenId string, to std.Address) {
	require(to != zeroAddress, "GnoswapStaker::transferDeposit: cannot transfer to zero address")

	owner := nft.OwnerOf(tid(tokenId))
	require(owner == GetOrigCaller(), "GnoswapStaker::transferDeposit: can only be called by deposit owner")

	deposits[tokenId].owner = owner

	_update := deposits[tokenId]
	_update.owner = owner
	deposits[tokenId] = _update

	// transfer actual NFT
	ok := nft.TransferFrom(a2u(owner), a2u(to), tid(tokenId))
	if !ok {
		panic("NFT TransferFrom Failed #1")
	}
}

func WithdrawToken(tokenId string, to std.Address) {
	require(to != GetOrigPkgAddr(), "GnoswapStaker::withdrawToken: cannot withdraw to staker")
	deposit := deposits[tokenId]

	require(deposit.numberOfStakes == 0, "GnoswapStaker::withdrawToken: cannot withdraw token while staked")
	require(deposit.owner == GetOrigCaller(), "GnoswapStaker::withdrawToken: only owner can withdraw token")

	delete(deposits, tokenId)

	// nonfungiblePositionManager.safeTransferFrom(GetOrigPkgAddr(), to, tokenId)
	// XXX GetRealmCaller()
	_orig := std.GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	ok := nft.TransferFrom(a2u(GetOrigPkgAddr()), a2u(to), tid(tokenId))
	if !ok {
		panic("NFT TransferFrom Failed #2")
	}
	std.TestSetOrigCaller(_orig)
}

func StakeToken(key IncentiveKey, tokenId string) {
	require(nft.OwnerOf(tid(tokenId)) == GetOrigCaller(), "GnoswapStaker::stakeToken: only owner can stake token")
	stakeToken(key, tokenId)
}

func UnstakeToken(key IncentiveKey, tokenId string) {
	deposit := deposits[tokenId]

	// anyone can call unstakeToken if the block time is after the end time of the incentive
	require(GetTimestamp() >= key.endTime, "GnoswapStaker::unstakeToken: incentive not ended")

	incentiveId := IncentiveIdCompute(key)
	secondsPerLiquidityInsideInitialX128, liquidity := Stakes(tokenId, incentiveId)

	require(liquidity != 0, "GnoswapStaker::unstakeToken: stake does not exist")
	
	incentive := incentives[incentiveId]

	_updateDeposit := deposits[tokenId]
	_updateDeposit.numberOfStakes--
	deposits[tokenId] = _updateDeposit
	
	_updateIncentive := incentives[incentiveId]
	_updateIncentive.numberOfStakes--
	incentives[incentiveId] = _updateIncentive
	
	// TMP

	// _, secondsPerLiquidityInsideX128, _ := key.pool.snapshotCumulativeInside(deposit.tickLower, deposit.tickUpper)
	// XXX
	secondsPerLiquidityInsideX128 := bigint(20) * Q128
	reward, secondsInsideX128 := RewardMathComputeRewardAmount(
		incentive.totalRewardUnclaimed,
		incentive.totalSecondsClaimedX128,
		key.startTime,
		key.endTime,
		liquidity,
		secondsPerLiquidityInsideInitialX128,
		secondsPerLiquidityInsideX128,
		GetTimestamp(),
	)

	_updateIncentive = incentives[incentiveId]
	_updateIncentive.totalSecondsClaimedX128 += secondsInsideX128

	if (reward > _updateIncentive.totalRewardUnclaimed) {
		panic("GnoswapStaker::unstakeToken: reward > incentive.totalRewardUnclaimed__too much reward")
	}
	_updateIncentive.totalRewardUnclaimed -= reward
	incentives[incentiveId] = _updateIncentive

	rewards[deposit.owner] += reward
	
	_updateStake := stakes[tokenId][incentiveId]
	_updateStake.secondsPerLiquidityInsideInitialX128 = bigint(0)
	_updateStake.liquidityNoOverflow = bigint(0)

	if (liquidity >= MAX_UINT96) {
		_updateStake.liquidityIfOverflow = bigint(0)
	}
	stakes[tokenId][incentiveId] = _updateStake
}


func claimReward(to std.Address, amountRequested bigint) (reward bigint) {
	requireUnsigned(amountRequested, "GnoswapStaker::claimReward: amountRequested is not unsigned")

	reward = rewards[GetOrigCaller()]
	if (amountRequested != 0 && amountRequested < reward) {
		reward = amountRequested
	}

	// TransferHelperExtended.safeTransfer(rewardToken, GetOrigPkgAddr(), to, reward)
	// XXX GetRealmCaller()
	_orig := std.GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	ok := rt.Transfer(a2u(to), uint64(reward))
	if !ok {
		panic("GnoswapStaker::claimReward: transfer failed")
	}
	std.TestSetOrigCaller(_orig)
	rewards[GetOrigCaller()] -= reward
	
	requireUnsigned(reward, "GnoswapStaker::claimReward: reward is not unsigned")
}

func getRewardInfo(key IncentiveKey, tokenId string) (reward, secondsInsideX128 bigint) {
	incentiveId := IncentiveIdCompute(key)
	
	secondsPerLiquidityInsideInitialX128, liquidity := Stakes(tokenId, incentiveId)
	require(liquidity > 0, "GnoswapStaker::getRewardInfo: stake does not exist")
	
	deposit := deposits[tokenId]
	incentive := incentives[incentiveId]
	
	// (_, secondsPerLiquidityInsideX128, _) := key.pool.snapshotCumulativeInside(deposit.tickLower, deposit.tickUpper)
	// XXX how many seconds did liquidity was inside initial
	secondsPerLiquidityInsideX128 := bigint(20) * Q128
	reward, secondsInsideX128 = RewardMathComputeRewardAmount(
		incentive.totalRewardUnclaimed,
		incentive.totalSecondsClaimedX128,
		key.startTime,
		key.endTime,
		liquidity,
		secondsPerLiquidityInsideInitialX128,
		secondsPerLiquidityInsideX128,
		GetTimestamp(),
	)

	requireUnsigned(reward, "GnoswapStaker::getRewardInfo: reward is not unsigned")
	requireUnsigned(secondsInsideX128, "GnoswapStaker::getRewardInfo: secondsInsideX128 is not unsigned")
	return reward, secondsInsideX128
}

func stakeToken(key IncentiveKey, tokenId string) {
	require(GetTimestamp() >= key.startTime, "GnoswapStaker::stakeToken: incentive not started")
	require(GetTimestamp() < key.endTime, "GnoswapStaker::stakeToken: incentive ended")
	
	incentiveId := IncentiveIdCompute(key)
	
	require(
		incentives[incentiveId].totalRewardUnclaimed > 0,
		"GnoswapStaker::stakeToken: non-existent incentive",
	)
	
	if len(stakes) > 0 && stakes[tokenId] != nil && stakes[tokenId][incentiveId].liquidityNoOverflow != 0 {
		panic("GnoswapStaker::stakeToken: token already staked")
	}

	// pool, tickLower, tickUpper, liquidity := NFTPositionInfoGetPositionInfo(
	// 	factory,
	// 	nonfungiblePositionManager,
	// 	tokenId,
	// )
	// require(pool == key.pool, "GnoswapStaker::stakeToken: token pool is not the incentive pool")

	tickLower, tickUpper, liquidity := NFTPositionInfoGetPositionInfo(tokenId)
	require(liquidity > 0, "GnoswapStaker::stakeToken: cannot stake token with 0 liquidity")

	_updateDeposits := deposits[tokenId]
	_updateDeposits.numberOfStakes++
	deposits[tokenId] = _updateDeposits

	_updateIncentives := incentives[incentiveId]
	_updateIncentives.numberOfStakes++
	incentives[incentiveId] = _updateIncentives
	
	// _, secondsPerLiquidityInsideX128, _ := pool.snapshotCumulativeInside(tickLower, tickUpper)
	// XXX how many seconds did liquidity was inside initial
	secondsPerLiquidityInsideX128 := bigint(1) * Q128

	var stake Stake
	if (liquidity >= MAX_UINT96) {
		stake.secondsPerLiquidityInsideInitialX128 = secondsPerLiquidityInsideX128
		stake.liquidityNoOverflow = MAX_UINT96
		stake.liquidityIfOverflow = liquidity

		if _, ok := stakes[tokenId]; !ok {
			stakes[tokenId] = map[string]Stake{}
			stakes[tokenId][incentiveId] = stake
		} else if _, ok := stakes[tokenId][incentiveId]; !ok {
			stakes[tokenId][incentiveId] = stake
		}
	} else {
		stake.secondsPerLiquidityInsideInitialX128 = secondsPerLiquidityInsideX128
		stake.liquidityNoOverflow = liquidity

		if _, ok := stakes[tokenId]; !ok {
			stakes[tokenId] = map[string]Stake{}
			stakes[tokenId][incentiveId] = stake
		} else if _, ok := stakes[tokenId][incentiveId]; !ok {
			stakes[tokenId][incentiveId] = stake
		}
	}

	// Transfer NFT
	TransferDeposit(tokenId, GetOrigPkgAddr())
}