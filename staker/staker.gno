package staker

import (
	"std"
	"gno.land/p/demo/avl"

	rt "gno.land/r/reward" 	// GSR, Gnoswap Staking Reward
	nft "gno.land/r/foo721" // GNFT, Gnoswap NFT 
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

	// incentives map[string]Incentive = make(map[string]Incentive)
	// deposits map[string]Deposit = make(map[string]Deposit)
	// stakes map[string]map[string]Stake = make(map[string]map[string]Stake)

	// IncentiveKey with rewardsToken
	// rewards map[interface{}]map[std.Address]bigint = make(map[interface{}]map[std.Address]bigint)

	// IncentiveKey without rewardsToken
	// rewards map[std.Address]bigint = make(map[std.Address]bigint)

	incentives avl.Tree	// incentiveId => Incentive
	deposits avl.Tree		// tokenId => Deposit
	stakes avl.Tree			// tokenId => avl.Tree{incentiveId => Stake}
	rewards avl.Tree 		// address => reward
		
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
	// stake := stakes[tokenId][incentiveId]
	_stakes1, ok := stakes.Get(tokenId)
	var stake1 avl.Tree
	var stake Stake
	if ok {
		stake1 = _stakes1.(avl.Tree)
		_stake, _ok := stake1.Get(incentiveId)
		if _ok {
			stake = _stake.(Stake)
		} else {
			panic("GnoswapStaker::Stakes: incentiveId not found")
		}

	} else {
		panic("GnoswapStaker::Stakes: tokenId not found")
	}


	secondsPerLiquidityInsideInitialX128 = stake.secondsPerLiquidityInsideInitialX128
	liquidity = stake.liquidityNoOverflow
	if (liquidity == MAX_UINT96) {
		liquidity = stake.liquidityIfOverflow
	}

	requireUnsigned(secondsPerLiquidityInsideInitialX128, "GnoswapStaker::Stakes: secondsPerLiquidityInsideInitialX128 is not unsigned")
	requireUnsigned(liquidity, "GnoswapStaker::Stakes: liquidity is not unsigned")
	return secondsPerLiquidityInsideInitialX128, liquidity
}


func CreateIncentive(
	// rewardToken std.Address,
	// pool std.Address,
	startTime bigint,
	endTime bigint,
	refundee std.Address,
	reward bigint,
) {
	incentiveKey := IncentiveKey{
		startTime: startTime,
		endTime: endTime,
		refundee: refundee,
	}
	
	return createIncentive(incentiveKey, reward)
}

func createIncentive(key IncentiveKey, reward bigint) {
	require(reward > 0, "GnoswapStaker::createIncentive: reward must be positive")

	require(
		GetTimestamp() <= key.startTime,
		"GnoswapStaker::createIncentive: start time must be now or in the future",
	)
	require(
		(key.startTime - GetTimestamp()) <= maxIncentiveStartLeadTime,
		"GnoswapStaker::createIncentive: start time too far into future",
	)
	require(key.startTime < key.endTime, "GnoswapStaker::createIncentive: start time must be before end time")
	require(
		(key.endTime - key.startTime) <= maxIncentiveDuration,
		"GnoswapStaker::createIncentive: incentive duration is too long",
	)
	
	incentiveId := IncentiveIdCompute(key)

	// _update := incentives[incentiveId]
	_incentive, ok := incentives.Get(incentiveId)
	var incentive Incentive
	if ok {
		incentive = _incentive.(Incentive)
	} else {
		incentive = Incentive{}
	}

	incentive.totalRewardUnclaimed += reward
	// incentives[incentiveId] = _update
	incentives.Set(incentiveId, incentive)

	// XXX
	// TransferHelperExtended.safeTransferFrom(std.Address(key.rewardToken), GetOrigCaller(), GetOrigPkgAddr(), reward)
	rt.Transfer(a2u(GetOrigPkgAddr()), uint64(reward))
}


func EndIncentive(
	// rewardToken std.Address,
	// pool std.Address,
	startTime bigint,
	endTime bigint,
	refundee std.Address,
) (bigint) {
	incentiveKey := IncentiveKey{
		startTime: startTime,
		endTime: endTime,
		refundee: refundee,
	}

	return endIncentive(incentiveKey)
}

func endIncentive(key IncentiveKey) (refund bigint) {
	require(GetTimestamp() >= key.endTime, "GnoswapStaker::endIncentive: cannot end incentive before end time")

	incentiveId := IncentiveIdCompute(key)
	// incentive := incentives[incentiveId]
	_incentive, ok := incentives.Get(incentiveId)
	var incentive Incentive
	if ok {
		incentive = _incentive.(Incentive)
	} else {
		panic("GnoswapStaker::endIncentive: cannot end non-existent incentive")
	}

	refund = incentive.totalRewardUnclaimed

	require(refund > bigint(0), "GnoswapStaker::endIncentive: no refund available")
	require(
			incentive.numberOfStakes == 0,
			"GnoswapStaker::endIncentive: cannot end incentive while deposits are staked",
	)

	// issue refund
	// _updateIncentive := incentives[incentiveId]
	_updateIncentive, ok := incentives.Get(incentiveId)
	var updateIncentive Incentive
	if ok {
		updateIncentive = _updateIncentive.(Incentive)
	} else {
		panic("GnoswapStaker::endIncentive: cannot update non-existent incentive")
	}

	updateIncentive.totalRewardUnclaimed = 0

	// incentives[incentiveId] = _updateIncentive
	incentives.Set(incentiveId, updateIncentive)
	
	// XXX
	// TransferHelperExtended.safeTransfer(std.Address(key.rewardToken), GetOrigCaller(), GetOrigPkgAddr(), refund)
	_orig := GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	rt.Transfer(a2u(key.refundee), uint64(refund))
	std.TestSetOrigCaller(_orig)

	requireUnsigned(refund, "GnoswapStaker::endIncentive: refund is not unsigned")
	return refund
}


func transferDeposit(tokenId string, to std.Address) {
	require(to != zeroAddress, "GnoswapStaker::transferDeposit: cannot transfer to zero address")

	owner := nft.OwnerOf(tid(tokenId))
	require(owner == GetOrigCaller(), "GnoswapStaker::transferDeposit: can only be called by deposit owner")

	// deposits[tokenId].owner = owner
	_deposit, ok := deposits.Get(tokenId)
	var deposit Deposit
	if ok {
		deposit = _deposit.(Deposit)
	} else {
		deposit = Deposit{}
	}
	deposit.owner = owner
	deposits.Set(tokenId, deposit)

	// _update := deposits[tokenId]
	// _update.owner = owner
	// deposits[tokenId] = _update
	_update, ok := deposits.Get(tokenId)
	var update Deposit
	if ok {
		update = _update.(Deposit)
	} else {
		panic("GnoswapStaker::transferDeposit: cannot transfer non-existent deposit")
	}
	update.owner = owner
	deposits.Set(tokenId, update)

	// transfer actual NFT
	nto := nft.TransferFrom(a2u(owner), a2u(to), tid(tokenId)) // Nft Transfer Ok
	if !nto {
		panic("NFT TransferFrom Failed #1")
	}
}

func WithdrawToken(tokenId string, to std.Address) {
	require(to != GetOrigPkgAddr(), "GnoswapStaker::withdrawToken: cannot withdraw to staker")
	// deposit := deposits[tokenId]
	_deposit, ok := deposits.Get(tokenId)
	var deposit Deposit
	if ok {
		deposit = _deposit.(Deposit)
	} else {
		panic("GnoswapStaker::withdrawToken: cannot withdraw non-existent deposit")
	}

	require(deposit.numberOfStakes == 0, "GnoswapStaker::withdrawToken: cannot withdraw token while staked")
	require(deposit.owner == GetOrigCaller(), "GnoswapStaker::withdrawToken: only owner can withdraw token")

	// delete(deposits, tokenId)
	deposits.Remove(tokenId)

	// nonfungiblePositionManager.safeTransferFrom(GetOrigPkgAddr(), to, tokenId)
	// XXX GetRealmCaller()
	_orig := std.GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	nto := nft.TransferFrom(a2u(GetOrigPkgAddr()), a2u(to), tid(tokenId))
	if !nto {
		panic("NFT TransferFrom Failed #2")
	}
	std.TestSetOrigCaller(_orig)
}

func StakeToken(
	// rewardToken std.Address,
	// pool std.Address,
	startTime bigint,
	endTime bigint,
	refundee std.Address,
	tokenId string,
) {
	require(nft.OwnerOf(tid(tokenId)) == GetOrigCaller(), "GnoswapStaker::stakeToken: only owner can stake token")

	key := IncentiveKey{
		startTime: startTime,
		endTime: endTime,
		refundee: refundee,
	}
	stakeToken(key, tokenId)
}


func UnstakeToken(
	// rewardToken std.Address,
	// pool std.Address,
	startTime bigint,
	endTime bigint,
	refundee std.Address,
	tokenId string,
) {
	key := IncentiveKey{
		startTime: startTime,
		endTime: endTime,
		refundee: refundee,
	}
	unstakeToken(key, tokenId)
}

func unstakeToken(key IncentiveKey, tokenId string) {
	// deposit := deposits[tokenId]
	_deposit, ok := deposits.Get(tokenId)
	var deposit Deposit
	if ok {
		deposit = _deposit.(Deposit)
	} else {
		deposit = Deposit{}
	}

	// anyone can call unstakeToken if the block time is after the end time of the incentive
	require(GetTimestamp() >= key.endTime, "GnoswapStaker::UnstakeToken: incentive not ended")

	incentiveId := IncentiveIdCompute(key)
	secondsPerLiquidityInsideInitialX128, liquidity := Stakes(tokenId, incentiveId)

	require(liquidity != 0, "GnoswapStaker::UnstakeToken: stake does not exist")

	// save for later
	// incentive := incentives[incentiveId]
	_incentive, ok := incentives.Get(incentiveId)
	var incentive Incentive
	if ok {
		incentive = _incentive.(Incentive)
	} else {
		panic("GnoswapStaker::UnstakeToken: cannot unstake from non-existent incentive")
	}

	// _updateDeposit := deposits[tokenId]
	_updateDeposit, ok := deposits.Get(tokenId)
	var updateDeposit Deposit
	if ok {
		updateDeposit = _updateDeposit.(Deposit)
	} else {
		panic("GnoswapStaker::UnstakeToken: cannot update non-existent deposit #1")
	}

	updateDeposit.numberOfStakes--
	// deposits[tokenId] = _updateDeposit
	deposits.Set(tokenId, updateDeposit)
	

	// _updateIncentive := incentives[incentiveId]
	_updateIncentive, ok := incentives.Get(incentiveId)
	var updateIncentive Incentive
	if ok {
		updateIncentive = _updateIncentive.(Incentive)
	} else {
		panic("GnoswapStaker::UnstakeToken: cannot update non-existent deposit #2")
	}

	updateIncentive.numberOfStakes--
	// incentives[incentiveId] = _updateIncentive
	incentives.Set(incentiveId, updateIncentive)

	// _, secondsPerLiquidityInsideX128, _ := key.pool.snapshotCumulativeInside(deposit.tickLower, deposit.tickUpper)
	secondsPerLiquidityInsideX128 := bigint(20) * Q128 // TMP XXX
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

	// _updateIncentive = incentives[incentiveId]
	_updateIncentive2, ok2 := incentives.Get(incentiveId)
	var updateIncentive2 Incentive
	if ok2 {
		updateIncentive2 = _updateIncentive2.(Incentive)
	} else {
		panic("GnoswapStaker::UnstakeToken: cannot update non-existent deposit #3")
	}

	updateIncentive2.totalSecondsClaimedX128 += secondsInsideX128

	if (reward > updateIncentive2.totalRewardUnclaimed) {
		panic("GnoswapStaker::UnstakeToken: reward > incentive.totalRewardUnclaimed__too much reward")
	}
	updateIncentive2.totalRewardUnclaimed -= reward

	// incentives[incentiveId] = _updateIncentive
	incentives.Set(incentiveId, updateIncentive2)

	// rewards[deposit.owner] += reward
	_rewards2, ok := rewards.Get(string(deposit.owner))
	var rewards2 bigint
	if ok {
		rewards2 = _rewards2.(bigint)
	} else {
		rewards2 = bigint(0)
	}
	rewards2 += reward
	rewards.Set(string(deposit.owner), rewards2)


	// _updateStake := stakes[tokenId][incentiveId]
	_stakes1, ok := stakes.Get(tokenId)
	var stake1 avl.Tree
	var updateStake Stake
	if ok {
		stake1 = _stakes1.(avl.Tree)
		_stake, _ok := stake1.Get(incentiveId)
		if _ok {
			updateStake = _stake.(Stake)
		} else {
			panic("GnoswapStaker::UnstakeToken: incentiveId not found")
		}

	} else {
		panic("GnoswapStaker::UnstakeToken: tokenId not found")
	}
	
	updateStake.secondsPerLiquidityInsideInitialX128 = bigint(0)
	updateStake.liquidityNoOverflow = bigint(0)

	if (liquidity >= MAX_UINT96) {
		updateStake.liquidityIfOverflow = bigint(0)
	}

	// stakes[tokenId][incentiveId] = updateStake
	_stakesUp, ok := stakes.Get(tokenId)
	var _stake1 avl.Tree
	if ok {
		_stake1 = _stakesUp.(avl.Tree)
		_stake1.Set(incentiveId, updateStake)
		stakes.Set(tokenId, _stake1)
	} else {
		panic("GnoswapStaker::UnstakeToken: tokenId not found")
	}
	
}


func ClaimReward(to std.Address, amountRequested bigint) (reward bigint) {
	requireUnsigned(amountRequested, "GnoswapStaker::ClaimReward: amountRequested is not unsigned")

	// reward = rewards[GetOrigCaller()]
	_reward, ok := rewards.Get(string(GetOrigCaller()))
	if ok {
		reward = _reward.(bigint)
	} else {
		reward = bigint(0)
	}

	if (amountRequested != 0 && amountRequested < reward) {
		reward = amountRequested
	}

	// TransferHelperExtended.safeTransfer(rewardToken, GetOrigPkgAddr(), to, reward)
	// XXX GetRealmCaller()
	_orig := GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	rto := rt.Transfer(a2u(to), uint64(reward))
	if !rto {
		panic("GnoswapStaker::ClaimReward: transfer failed")
	}
	std.TestSetOrigCaller(_orig)

	// rewards[GetOrigCaller()] -= reward
	_reward2, ok := rewards.Get(string(GetOrigCaller()))
	var reward2 bigint
	if ok {
		reward2 = _reward2.(bigint)
		reward2 -= reward
		rewards.Set(string(GetOrigCaller()), reward2)
	} else {
		reward2 = bigint(0)
	}
	
	requireUnsigned(reward, "GnoswapStaker::ClaimReward: reward is not unsigned")
}

func getRewardInfo(key IncentiveKey, tokenId string) (reward, secondsInsideX128 bigint) {
	incentiveId := IncentiveIdCompute(key)
	
	secondsPerLiquidityInsideInitialX128, liquidity := Stakes(tokenId, incentiveId)
	require(liquidity > 0, "GnoswapStaker::getRewardInfo: stake does not exist")
	
	// deposit := deposits[tokenId]

	// incentive := incentives[incentiveId]
	_incentive, ok := incentives.Get(incentiveId)
	var incentive Incentive
	if ok {
		incentive = _incentive.(Incentive)
	} else {
		panic("GnoswapStaker::getRewardInfo: incentive does not exist")
	}
	
	// (_, secondsPerLiquidityInsideX128, _) := key.pool.snapshotCumulativeInside(deposit.tickLower, deposit.tickUpper)
	// XXX how many seconds did liquidity was inside
	secondsPerLiquidityInsideX128 := (bigint(GetTimestamp() + bigint(20))) * Q128
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
	
	// require(incentives[incentiveId].totalRewardUnclaimed > 0, "GnoswapStaker::stakeToken: non-existent incentive")
	_incentive, ok := incentives.Get(incentiveId)
	var incentive Incentive
	if ok {
		incentive = _incentive.(Incentive)
	} else {
		incentive = Incentive{}
	}
	require(incentive.totalRewardUnclaimed > 0, "GnoswapStaker::stakeToken: non-existent incentive")

	
	// if len(stakes) > 0 && stakes[tokenId] != nil && stakes[tokenId][incentiveId].liquidityNoOverflow != 0 {
	// 	panic("GnoswapStaker::stakeToken: token already staked")
	// }
	nest1, ok1 := stakes.Get(tokenId)
	if ok1 {
		nest11 := nest1.(avl.Tree)
		nest2, ok2 := nest11.Get(incentiveId)

		if ok2 {
			nest22 := nest2.(Stake)

			if nest22.liquidityNoOverflow != 0 { 
				panic("GnoswapStaker::stakeToken: token already staked") 
			}
		}
	}
	
	// pool, tickLower, tickUpper, liquidity := NFTPositionInfoGetPositionInfo(
	// 	factory,
	// 	nonfungiblePositionManager,
	// 	tokenId,
	// )
	// require(pool == key.pool, "GnoswapStaker::stakeToken: token pool is not the incentive pool")

	tickLower, tickUpper, liquidity := NFTPositionInfoGetPositionInfo(tokenId)
	require(liquidity > 0, "GnoswapStaker::stakeToken: cannot stake token with 0 liquidity")

	// _updateDeposits := deposits[tokenId]
	// _updateDeposits.numberOfStakes++
	// deposits[tokenId] = _updateDeposits
	_deposit, ok := deposits.Get(tokenId)
	var deposit Deposit
	if ok {
		deposit = _deposit.(Deposit)
		deposit.numberOfStakes++
		deposits.Set(tokenId, deposit)
	} else {
		deposit = Deposit{}
		deposit.numberOfStakes++
		deposits.Set(tokenId, deposit)
	}

	// _updateIncentives := incentives[incentiveId]
	// _updateIncentives.numberOfStakes++
	// incentives[incentiveId] = _updateIncentives
	_incentive, ok = incentives.Get(incentiveId)
	if ok {
		incentive = _incentive.(Incentive)
		incentive.numberOfStakes++
		incentives.Set(incentiveId, incentive)
	} else {
		require(incentive.totalRewardUnclaimed > 0, "GnoswapStaker::stakeToken: cannot update non-existent incentive")
	}
	
	// _, secondsPerLiquidityInsideX128, _ := pool.snapshotCumulativeInside(tickLower, tickUpper)
	// XXX how many seconds did liquidity was inside initial ( don't add GetTimestamp() )
	secondsPerLiquidityInsideX128 := bigint(1) * Q128

	// var stake Stake
	// if (liquidity >= MAX_UINT96) {
	// 	stake.secondsPerLiquidityInsideInitialX128 = secondsPerLiquidityInsideX128
	// 	stake.liquidityNoOverflow = MAX_UINT96
	// 	stake.liquidityIfOverflow = liquidity

	// 	if _, ok := stakes[tokenId]; !ok {
	// 		stakes[tokenId] = map[string]Stake{}
	// 		stakes[tokenId][incentiveId] = stake
	// 	} else if _, ok := stakes[tokenId][incentiveId]; !ok {
	// 		stakes[tokenId][incentiveId] = stake
	// 	}
	// } else {
	// 	stake.secondsPerLiquidityInsideInitialX128 = secondsPerLiquidityInsideX128
	// 	stake.liquidityNoOverflow = liquidity

	// 	if _, ok := stakes[tokenId]; !ok {
	// 		stakes[tokenId] = map[string]Stake{}
	// 		stakes[tokenId][incentiveId] = stake
	// 	} else if _, ok := stakes[tokenId][incentiveId]; !ok {
	// 		stakes[tokenId][incentiveId] = stake
	// 	}
	// }

	var stake Stake
	if (liquidity >= MAX_UINT96) {
		stake.secondsPerLiquidityInsideInitialX128 = secondsPerLiquidityInsideX128
		stake.liquidityNoOverflow = MAX_UINT96
		stake.liquidityIfOverflow = liquidity

		_tmp1, _ok1 := stakes.Get(tokenId)
		var tmp1 avl.Tree
		if !_ok1 {
			tmp1 = avl.Tree{}
			tmp1.Set(incentiveId, stake)
			stakes.Set(tokenId, tmp1)
		} else {
			tmp1 = _tmp1.(avl.Tree)
			tmp1.Set(incentiveId, stake)
			stakes.Set(tokenId, tmp1)
		}
	} else {
		stake.secondsPerLiquidityInsideInitialX128 = secondsPerLiquidityInsideX128
		stake.liquidityNoOverflow = liquidity

		_tmp1, _ok1 := stakes.Get(tokenId)
		var tmp1 avl.Tree
		if !_ok1 {
			tmp1 = avl.Tree{}
			tmp1.Set(incentiveId, stake)
			stakes.Set(tokenId, tmp1)
		} else {
			tmp1 = _tmp1.(avl.Tree)
			tmp1.Set(incentiveId, stake)
			stakes.Set(tokenId, tmp1)
		}
	}

	// Transfer NFT
	transferDeposit(tokenId, GetOrigPkgAddr())
}