package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	nft "gno.land/r/gnft"  // GNFT, Gnoswap NFT
	gnos "gno.land/r/gnos" // GNOS, Gnoswap Share
)

var (
	maxIncentiveStartLeadTime bigint = 600
	maxIncentiveDuration      bigint

	incentives map[string]Incentive        = make(map[string]Incentive)        // incentiveId => Incentive
	deposits   map[bigint]Deposit          = make(map[bigint]Deposit)          // tokenId => Deposit
	stakes     map[bigint]map[string]Stake = make(map[bigint]map[string]Stake) // tokenId => map[incentiveId => Stake]
	rewards    map[std.Address]bigint      = make(map[std.Address]bigint)      // address => reward

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

	incentive, exist := incentives[incentiveId]
	require(!exist, "incentive already exists")
	incentives[incentiveId] = incentive
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
	tokenId bigint,
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
	tokenId bigint,
) {
	key := IncentiveKey{
		startTime: startTime,
		endTime:   endTime,
		refundee:  refundee,
	}
	unstakeToken(key, tokenId)
}

func WithdrawToken(tokenId bigint, to std.Address) {
	require(to != GetOrigPkgAddr(), "GnoswapStaker::withdrawToken: cannot withdraw to staker contract")
	deposit, exist := deposits[tokenId]

	require(exist, "GnoswapStaker::withdrawToken: cannot withdraw non-existent deposit")
	require(deposit.numberOfStakes == 0, "GnoswapStaker::withdrawToken: cannot withdraw token while staked")
	// require(deposit.owner == GetOrigCaller(), "GnoswapStaker::withdrawToken: only owner can withdraw token")
	require(deposit.owner == PrevRealmAddr(), "GnoswapStaker::withdrawToken: only owner can withdraw token")
	require(deposit.timeToWithdraw < GetTimestamp(), "GnoswapStaker::withdrawToken: token cannot be withdrawn yet")

	delete(deposits, tokenId)

	// xxx grc721 should use PrevRealm()
	// approve then transfer (approve in testcase)
	nft.TransferFrom(a2u(GetOrigPkgAddr()), a2u(to), tid(tokenId))
}

func ClaimReward(
	startTime bigint,
	endTime bigint,
	refundee std.Address,
	tokenId bigint,
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
	tokenId bigint,
) (bigint, bigint) {
	incentiveKey := IncentiveKey{
		startTime: startTime,
		endTime:   endTime,
		refundee:  refundee,
	}

	return getRewardInfo(incentiveKey, tokenId)
}

func getRewardInfo(key IncentiveKey, tokenId bigint) (reward, secondsInsideX128 bigint) {
	incentiveId := IncentiveIdCompute(key)

	secondsPerLiquidityInsideInitialX128, liquidity := findStakes(tokenId, incentiveId)
	require(liquidity > 0, "GnoswapStaker::GetRewardInfo: stake does not exist")

	incentive, ok := incentives[incentiveId]
	require(ok, "GnoswapStaker::GetRewardInfo: incentive does not exist")

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
	tokenId bigint,
	incentiveId string,
) (secondsPerLiquidityInsideInitialX128, liquidity bigint) {

	stake, exist := stakes[tokenId][incentiveId]
	require(exist, "GnoswapStaker::findStakes: stake does not exist")

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

	incentive, exist := incentives[incentiveId]
	require(exist, "GnoswapStaker::endIncentive: cannot end non-existent incentive")

	// refund = incentive.totalRewardUnclaimed

	require(refund > bigint(0), "GnoswapStaker::endIncentive: no refund available")
	require(
		incentive.numberOfStakes == 0,
		"GnoswapStaker::endIncentive: cannot end incentive while deposits are staked",
	)

	// issue refund
	// incentive.totalRewardUnclaimed = 0
	// incentives[incentiveId] = incentive // xxx necessary ??

	// TransferHelperExtended.safeTransfer(std.Address(key.rewardToken), GetOrigCaller(), GetOrigPkgAddr(), refund)
	gnos.Transfer(a2u(key.refundee), uint64(refund))

	requireUnsigned(refund, "GnoswapStaker::endIncentive: refund is not unsigned")
	return refund
}

func stakeToken(key IncentiveKey, tokenId bigint, lockDuration bigint) {
	require(GetTimestamp() >= key.startTime, ufmt.Sprintf("GnoswapStaker::stakeToken: incentive not started(now:%s, start:%s)", GetTimestamp(), key.startTime))
	require(GetTimestamp() < key.endTime, "GnoswapStaker::stakeToken: incentive ended")

	incentiveId := IncentiveIdCompute(key)
	// require(incentives[incentiveId].totalRewardUnclaimed > 0, "GnoswapStaker::stakeToken: non-existent incentive")

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

	deposit := deposits[tokenId]
	deposit.numberOfStakes++
	deposit.lockDuration = lockDuration
	deposits[tokenId] = deposit

	incentive := incentives[incentiveId]
	incentive.numberOfStakes++
	incentives[incentiveId] = incentive

	// _, secondsPerLiquidityInsideX128, _ := pool.snapshotCumulativesInside(tickLower, tickUpper)
	// XXX how many seconds did liquidity was inside initial ( don't add GetTimestamp() )
	secondsPerLiquidityInsideX128 := bigint(1) * Q128

	var stake Stake
	if liquidity >= MAX_UINT96 {
		stake.secondsPerLiquidityInsideInitialX128 = secondsPerLiquidityInsideX128
		stake.liquidityNoOverflow = MAX_UINT96
		stake.liquidityIfOverflow = liquidity

		if _, exist := stakes[tokenId]; !exist {
			stakes[tokenId] = map[string]Stake{}
			stakes[tokenId][incentiveId] = stake
		} else if _, exist := stakes[tokenId][incentiveId]; !exist {
			stakes[tokenId][incentiveId] = stake
		}
	} else {
		stake.secondsPerLiquidityInsideInitialX128 = secondsPerLiquidityInsideX128
		stake.liquidityNoOverflow = liquidity

		if _, exist := stakes[tokenId]; !exist {
			stakes[tokenId] = map[string]Stake{}
			stakes[tokenId][incentiveId] = stake
		} else if _, exist := stakes[tokenId][incentiveId]; !exist {
			stakes[tokenId][incentiveId] = stake
		}

	}

	// Transfer NFT
	transferDeposit(tokenId, GetOrigPkgAddr())
}

func unstakeToken(key IncentiveKey, tokenId bigint) {
	// anyone can call unstakeToken if the block time is after the end time of the incentive
	// require(GetTimestamp() >= key.endTime, "GnoswapStaker::UnstakeToken: incentive not ended")

	incentiveId := IncentiveIdCompute(key)
	secondsPerLiquidityInsideInitialX128, liquidity := findStakes(tokenId, incentiveId)

	require(liquidity != 0, "GnoswapStaker::UnstakeToken: stake does not exist")

	deposit, exist := deposits[tokenId]
	require(exist, "GnoswapStaker::UnstakeToken: cannot unstake non-existent deposit")

	deposit.numberOfStakes--

	incentive := incentives[incentiveId]
	require(exist, "GnoswapStaker::UnstakeToken: cannot unstake non-existent incetnvie")

	incentive.numberOfStakes--
	incentives[incentiveId] = incentive

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

	rewards[deposit.owner] += reward

	stake := stakes[tokenId][incentiveId]

	stake.secondsPerLiquidityInsideInitialX128 = bigint(0)
	stake.liquidityNoOverflow = bigint(0)

	if liquidity >= MAX_UINT96 {
		stake.liquidityIfOverflow = bigint(0)
	}

	stakes[tokenId][incentiveId] = stake

	// update timeToWithdraw
	deposit.timeToWithdraw = GetTimestamp() + deposit.lockDuration

	// xxx necessary ??
	deposits[tokenId] = deposit
}

func transferDeposit(tokenId bigint, to std.Address) {
	require(to != zeroAddress, "GnoswapStaker::transferDeposit: cannot transfer to zero address")

	owner := nft.OwnerOf(tid(tokenId))
	require(PrevRealmAddr() == owner, "GnoswapStaker::transferDeposit: can only be called by deposit owner")

	deposits[tokenId].owner = owner

	deposit := deposits[tokenId]
	deposit.owner = owner
	deposits[tokenId] = deposit

	// transfer actual NFT
	nft.TransferFrom(a2u(owner), a2u(to), tid(tokenId)) // nft transfer ok
}
