package staker

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	nft "gno.land/r/gnft"  // GNFT, Gnoswap NFT
	gnos "gno.land/r/gnos" // GNOS, Gnoswap Share
)

var (
	maxIncentiveStartLeadTime bigint = 600
	maxIncentiveDuration      bigint

	incentives avl.Tree // incentiveId => Incentive
	deposits   avl.Tree // tokenId => Deposit
	stakes     avl.Tree // tokenId => avl.Tree{incentiveId => Stake}
	rewards    avl.Tree // address => reward

	initialized bool = false
)

func CreateIncentive(
	startTime bigint,
	endTime bigint,
	refundee std.Address, // XXX remove
) {
	incentiveKey := IncentiveKey{
		startTime: startTime,
		endTime:   endTime,
		refundee:  refundee,
	}

	return createIncentive(incentiveKey)
}

func createIncentive(key IncentiveKey) {
	require(
		GetTimestamp() <= key.startTime,
		ufmt.Sprintf("GnoswapStaker::createIncentive: start time(%s) must be now(%s) or in the future", key.startTime, GetTimestamp()),
	)
	require(
		(key.startTime-GetTimestamp()) <= maxIncentiveStartLeadTime,
		ufmt.Sprintf("GnoswapStaker::createIncentive: start time(%s) too far into future(%s)", key.startTime, key.startTime-GetTimestamp()),
	)
	require(
		key.startTime < key.endTime,
		ufmt.Sprintf("GnoswapStaker::createIncentive: start time(%s) must be before end time(%s)", key.startTime, key.endTime),
	)
	// require(
	// 	(key.endTime-key.startTime) <= maxIncentiveDuration,
	// 	"GnoswapStaker::createIncentive: incentive duration is too long",
	// )

	incentiveId := IncentiveIdCompute(key)

	// _update := incentives[incentiveId]
	_incentive, ok := incentives.Get(incentiveId)
	var incentive Incentive
	if ok {
		incentive = _incentive.(Incentive)
	} else {
		incentive = Incentive{}
	}

	incentives.Set(incentiveId, incentive)
}

func EndIncentive(
	startTime bigint,
	endTime bigint,
	refundee std.Address,
) bigint {
	incentiveKey := IncentiveKey{
		startTime: startTime,
		endTime:   endTime,
		refundee:  refundee,
	}

	return endIncentive(incentiveKey)
}

func StakeToken(
	// rewardToken std.Address,
	// pool std.Address,
	startTime bigint,
	endTime bigint,
	refundee std.Address,
	tokenId string,
	lockDuration bigint,
) {
	// require(nft.OwnerOf(tid(tokenId)) == GetOrigCaller(), "GnoswapStaker::stakeToken: only owner can stake token")
	require(nft.OwnerOf(tid(tokenId)) == PrevRealmAddr(), "GnoswapStaker::stakeToken: only owner can stake token")
	require(lockDuration == 3 || lockDuration == 5 || lockDuration == 10 || lockDuration == 100, "GnoswapStaker::stakeToken: lock duration must be 3, 5, 10 seconds") // XXX dev
	// require(lockDuration == 604800 || lockDuration == 1209600  || lockDuration == 1814400, "GnoswapStaker::stakeToken: lock duration must be 1, 2, or 3 weeks")

	key := IncentiveKey{
		startTime: startTime,
		endTime:   endTime,
		refundee:  refundee,
	}
	stakeToken(key, tokenId, lockDuration)
}

func UnstakeToken(
	startTime bigint,
	endTime bigint,
	refundee std.Address,
	tokenId string,
) {
	key := IncentiveKey{
		startTime: startTime,
		endTime:   endTime,
		refundee:  refundee,
	}
	unstakeToken(key, tokenId)
}

func WithdrawToken(tokenId string, to std.Address) {
	require(to != GetOrigPkgAddr(), "GnoswapStaker::withdrawToken: cannot withdraw to staker contract")
	// deposit := deposits[tokenId]
	_deposit, ok := deposits.Get(tokenId)
	var deposit Deposit
	if ok {
		deposit = _deposit.(Deposit)
	} else {
		panic("GnoswapStaker::withdrawToken: cannot withdraw non-existent deposit")
	}

	require(deposit.numberOfStakes == 0, "GnoswapStaker::withdrawToken: cannot withdraw token while staked")
	// require(deposit.owner == GetOrigCaller(), "GnoswapStaker::withdrawToken: only owner can withdraw token")
	require(deposit.owner == PrevRealmAddr(), "GnoswapStaker::withdrawToken: only owner can withdraw token")
	require(deposit.timeToWithdraw < GetTimestamp(), "GnoswapStaker::withdrawToken: token cannot be withdrawn yet")

	// delete(deposits, tokenId)
	deposits.Remove(tokenId)

	// xxx grc721 should use PrevRealm()
	// approve then transfer (approve in testcase)
	nft.TransferFrom(a2u(GetOrigPkgAddr()), a2u(to), tid(tokenId))
}

func ClaimReward(
	startTime bigint,
	endTime bigint,
	refundee std.Address,
	tokenId string,
) {
	// reward = rewards[GetOrigCaller()]
	// _reward, ok := rewards.Get(string(GetOrigCaller()))
	// if ok {
	// 	reward = _reward.(bigint)
	// } else {
	// 	reward = bigint(0)
	// }

	// toAddr := GetOrigCaller()
	toAddr := PrevRealmAddr()
	reward, _ := GetRewardInfo(startTime, endTime, refundee, tokenId)
	gnos.Mint(a2u(toAddr), uint64(reward))
}

func GetRewardInfo(
	startTime bigint,
	endTime bigint,
	refundee std.Address,
	tokenId string,
) (bigint, bigint) {
	incentiveKey := IncentiveKey{
		startTime: startTime,
		endTime:   endTime,
		refundee:  refundee,
	}

	return getRewardInfo(incentiveKey, tokenId)
}

func getRewardInfo(key IncentiveKey, tokenId string) (reward, secondsInsideX128 bigint) {
	incentiveId := IncentiveIdCompute(key)

	secondsPerLiquidityInsideInitialX128, liquidity := findStakes(tokenId, incentiveId)
	require(liquidity > 0, "GnoswapStaker::GetRewardInfo: stake does not exist")

	// deposit := deposits[tokenId]
	_incentive, ok := incentives.Get(incentiveId)
	var incentive Incentive
	if ok {
		incentive = _incentive.(Incentive)
	} else {
		panic("GnoswapStaker::GetRewardInfo: incentive does not exist")
	}

	secondsPerLiquidityInsideX128 := (bigint(GetTimestamp() + bigint(20))) * Q128
	reward, secondsInsideX128 = RewardMathComputeRewardAmount(
		// incentive.totalRewardUnclaimed,
		// incentive.totalSecondsClaimedX128,
		key.startTime,
		key.endTime,
		liquidity,
		secondsPerLiquidityInsideInitialX128,
		secondsPerLiquidityInsideX128,
		GetTimestamp(),
	)

	requireUnsigned(reward, "GnoswapStaker::GetRewardInfo: reward is not unsigned")
	requireUnsigned(secondsInsideX128, "GnoswapStaker::GetRewardInfo: secondsInsideX128 is not unsigned")
	return reward, secondsInsideX128
}

func findStakes(
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
			panic("GnoswapStaker::findStakes: incentiveId not found")
		}

	} else {
		panic("GnoswapStaker::findStakes: tokenId not found")
	}

	secondsPerLiquidityInsideInitialX128 = stake.secondsPerLiquidityInsideInitialX128
	liquidity = stake.liquidityNoOverflow
	if liquidity == MAX_UINT96 {
		liquidity = stake.liquidityIfOverflow
	}

	requireUnsigned(secondsPerLiquidityInsideInitialX128, "GnoswapStaker::findStakes: secondsPerLiquidityInsideInitialX128 is not unsigned")
	requireUnsigned(liquidity, "GnoswapStaker::findStakes: liquidity is not unsigned")
	return secondsPerLiquidityInsideInitialX128, liquidity
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

	// refund = incentive.totalRewardUnclaimed

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

	// updateIncentive.totalRewardUnclaimed = 0

	// incentives[incentiveId] = _updateIncentive
	incentives.Set(incentiveId, updateIncentive)

	// TransferHelperExtended.safeTransfer(std.Address(key.rewardToken), GetOrigCaller(), GetOrigPkgAddr(), refund)
	gnos.Transfer(a2u(key.refundee), uint64(refund))

	requireUnsigned(refund, "GnoswapStaker::endIncentive: refund is not unsigned")
	return refund
}

func stakeToken(key IncentiveKey, tokenId string, lockDuration bigint) {
	require(GetTimestamp() >= key.startTime, ufmt.Sprintf("GnoswapStaker::stakeToken: incentive not started(now:%s, start:%s)", GetTimestamp(), key.startTime))
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
	// require(incentive.totalRewardUnclaimed > 0, "GnoswapStaker::stakeToken: non-existent incentive")

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
		deposit.lockDuration = lockDuration
		deposits.Set(tokenId, deposit)
	} else {
		deposit = Deposit{}
		deposit.numberOfStakes++
		deposit.lockDuration = lockDuration
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
		// require(incentive.totalRewardUnclaimed > 0, "GnoswapStaker::stakeToken: cannot update non-existent incentive")
	}

	// _, secondsPerLiquidityInsideX128, _ := pool.snapshotCumulativesInside(tickLower, tickUpper)
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
	if liquidity >= MAX_UINT96 {
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
	// require(GetTimestamp() >= key.endTime, "GnoswapStaker::UnstakeToken: incentive not ended")

	incentiveId := IncentiveIdCompute(key)
	secondsPerLiquidityInsideInitialX128, liquidity := findStakes(tokenId, incentiveId)

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

	// _, secondsPerLiquidityInsideX128, _ := key.pool.snapshotCumulativesInside(deposit.tickLower, deposit.tickUpper)
	secondsPerLiquidityInsideX128 := bigint(20) * Q128 // TMP XXX
	reward, secondsInsideX128 := RewardMathComputeRewardAmount(
		// incentive.totalRewardUnclaimed,
		// incentive.totalSecondsClaimedX128,
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

	// updateIncentive2.totalSecondsClaimedX128 += secondsInsideX128

	// if (reward > updateIncentive2.totalRewardUnclaimed) {
	// 	panic("GnoswapStaker::UnstakeToken: reward > incentive.totalRewardUnclaimed__too much reward")
	// }
	// updateIncentive2.totalRewardUnclaimed -= reward

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
		panic("GnoswapStaker::UnstakeToken: tokenId not found #1")
	}

	updateStake.secondsPerLiquidityInsideInitialX128 = bigint(0)
	updateStake.liquidityNoOverflow = bigint(0)

	if liquidity >= MAX_UINT96 {
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
		panic("GnoswapStaker::UnstakeToken: tokenId not found #2")
	}

	// update timeToWithdraw
	_timeToWithdraw, ok := deposits.Get(tokenId)
	var timeUpdateDeposit Deposit
	if ok {
		timeUpdateDeposit = _timeToWithdraw.(Deposit)
		timeUpdateDeposit.timeToWithdraw = GetTimestamp() + timeUpdateDeposit.lockDuration
		deposits.Set(tokenId, timeUpdateDeposit)
	} else {
		panic("GnoswapStaker::UnstakeToken: tokenId not found #3")
	}
}

func transferDeposit(tokenId string, to std.Address) {
	require(to != zeroAddress, "GnoswapStaker::transferDeposit: cannot transfer to zero address")

	owner := nft.OwnerOf(tid(tokenId))
	require(PrevRealmAddr() == owner, "GnoswapStaker::transferDeposit: can only be called by deposit owner")

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
	nft.TransferFrom(a2u(owner), a2u(to), tid(tokenId)) // nft transfer ok
}
