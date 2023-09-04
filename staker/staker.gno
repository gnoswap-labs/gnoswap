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
		ufmt.Sprintf("[STAKER] staker.gno__createIncentive() || cannot start incentive in the past__GetTimestamp()(%s) <= key.startTime(%s)", GetTimestamp(), key.startTime),
	)
	require(
		(key.startTime-GetTimestamp()) <= maxIncentiveStartLeadTime,
		ufmt.Sprintf("[STAKER] staker.gno__createIncentive() || cannot start incentive too far in the future__key.startTime-GetTimeStamp()(%s) <= maxIncentiveStartLeadTime(%s)", key.startTime-GetTimestamp(), maxIncentiveStartLeadTime),
	)
	require(
		key.startTime < key.endTime,
		ufmt.Sprintf("[STAKER] staker.gno__createIncentive() || cannot start incentive before endtime__key.startTime(%s) < key.endTime(%s)", key.startTime, key.endTime),
	)
	// require(
	// 	(key.endTime-key.startTime) <= maxIncentiveDuration,
	// 	"[STAKER] staker.gno__createIncentive() || incentive duration is too long",
	// )

	incentiveId := incentiveIdCompute(key)

	incentive, exist := incentives[incentiveId]
	require(!exist, ufmt.Sprintf("[STAKER] staker.gno__createIncentive() || incentive(%s) already exists", incentiveId))
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
	require(nft.OwnerOf(tid(tokenId)) == PrevRealmAddr(), ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || only owner can stake token__nft.OwnerOf(tid(tokenId))(%s) == PrevRealmAddr()(%s)", nft.OwnerOf(tid(tokenId)), PrevRealmAddr()))
	require(lockDuration == 3 || lockDuration == 5 || lockDuration == 10 || lockDuration == 100, ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || lock duration(%s) must be 3, 5, 10  or 100 seconds", lockDuration))

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
	require(to != GetOrigPkgAddr(), ufmt.Sprintf("[STAKER] staker.gno__WithdrawToken() || cannot withdraw to staker contract__to(%s) != GetOrigPkgAddr()(%s)", to, GetOrigPkgAddr()))

	deposit, exist := deposits[tokenId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__WithdrawToken() || cannot withdraw non-existent(tokenId:%s) deposit", tokenId))
	require(deposit.numberOfStakes == 0, ufmt.Sprintf("[STAKER] staker.gno__WithdrawToken() || cannot withdraw token while staked__deposit.numberOfStakes(%s) == 0", deposit.numberOfStakes))
	require(deposit.owner == PrevRealmAddr(), ufmt.Sprintf("[STAKER] staker.gno__WithdrawToken() || only owner can withdraw token__deposit.owner(%s) == PrevRealmAddr()(%s)", deposit.owner, PrevRealmAddr()))
	require(deposit.timeToWithdraw < GetTimestamp(), ufmt.Sprintf("[STAKER] staker.gno__WithdrawToken() || token cannot be withdrawn yet__deposit.timeToWithdraw(%s) < GetTimestamp()(%s)", deposit.timeToWithdraw, GetTimestamp()))

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
	incentiveId := incentiveIdCompute(key)

	secondsPerLiquidityInsideInitialX128, liquidity := findStakes(tokenId, incentiveId)
	require(liquidity > 0, ufmt.Sprintf("[STAKER] staker.gno__getRewardInfo() || stake(tokenId:%s, incentiveId:%s) does not exist", tokenId, incentiveId))

	incentive, ok := incentives[incentiveId]
	require(ok, ufmt.Sprintf("[STAKER] staker.gno__getRewardInfo() || incentive(%s) does not exist", incentiveId))

	secondsPerLiquidityInsideX128 := (bigint(GetTimestamp() + bigint(20))) * Q128
	reward, secondsInsideX128 = rewardMathComputeRewardAmount(
		// incentive.totalRewardUnclaimed,
		// incentive.totalSecondsClaimedX128,
		key.startTime,
		key.endTime,
		liquidity,
		secondsPerLiquidityInsideInitialX128,
		secondsPerLiquidityInsideX128,
		GetTimestamp(),
	)

	requireUnsigned(reward, ufmt.Sprintf("[STAKER] staker.gno__getRewardInfo() || reward(%s) must be positive", reward))
	requireUnsigned(secondsInsideX128, ufmt.Sprintf("[STAKER] staker.gno__getRewardInfo() || secondsInsideX128(%s) must be positive", secondsInsideX128))
	return reward, secondsInsideX128
}

func findStakes(
	tokenId bigint,
	incentiveId string,
) (secondsPerLiquidityInsideInitialX128, liquidity bigint) {

	stake, exist := stakes[tokenId][incentiveId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__findStakes() || stake(tokenId:%s, incentiveId:%s) does not exist", tokenId, incentiveId))

	secondsPerLiquidityInsideInitialX128 = stake.secondsPerLiquidityInsideInitialX128
	liquidity = stake.liquidityNoOverflow
	if liquidity == MAX_UINT96 {
		liquidity = stake.liquidityIfOverflow
	}

	requireUnsigned(secondsPerLiquidityInsideInitialX128, ufmt.Sprintf("[STAKER] staker.gno__findStakes() || secondsPerLiquidityInsideInitialX128(%s) must be positive", secondsPerLiquidityInsideInitialX128))
	requireUnsigned(liquidity, ufmt.Sprintf("[STAKER] staker.gno__findStakes() || liquidity(%s) must be positive", liquidity))
	return secondsPerLiquidityInsideInitialX128, liquidity
}

func endIncentive(key IncentiveKey) (refund bigint) {
	require(GetTimestamp() >= key.endTime, ufmt.Sprintf("[STAKER] staker.gno__endIncentive() || cannot end incentive before end time__GetTimestamp()(%s) >= key.endTime(%s)", GetTimestamp(), key.endTime))

	incentiveId := incentiveIdCompute(key)

	incentive, exist := incentives[incentiveId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__endIncentive() || cannot end non-existent incentive(%s)", incentiveId))

	// refund = incentive.totalRewardUnclaimed

	require(refund > bigint(0), ufmt.Sprintf("[STAKER] staker.gno__endIncentive() || no refund available", refund))
	require(
		incentive.numberOfStakes == 0,
		ufmt.Sprintf("[STAKER] staker.gno__endIncentive() || cannot end incentive while deposits are staked__incentive.numberOfStakes(%s) == 0", incentive.numberOfStakes),
	)

	// issue refund
	// incentive.totalRewardUnclaimed = 0
	// incentives[incentiveId] = incentive // xxx necessary ??

	// TransferHelperExtended.safeTransfer(std.Address(key.rewardToken), GetOrigCaller(), GetOrigPkgAddr(), refund)
	gnos.Transfer(a2u(key.refundee), uint64(refund))

	requireUnsigned(refund, ufmt.Sprintf("[STAKER] staker.gno__endIncentive() || refund(%s) must be positive", refund))
	return refund
}

func stakeToken(key IncentiveKey, tokenId bigint, lockDuration bigint) {
	require(GetTimestamp() >= key.startTime, ufmt.Sprintf("[STAKER] staker.gno__stakeToken() || incentive not started__GetTimestamp()(%s) >= key.startTime(%s)", GetTimestamp(), key.startTime))
	require(GetTimestamp() < key.endTime, ufmt.Sprintf("[STAKER] staker.gno__stakeToken() || incentive ended__GetTimestamp()(%s) < key.endTime(%s)", GetTimestamp(), key.endTime))

	incentiveId := incentiveIdCompute(key)
	// require(incentives[incentiveId].totalRewardUnclaimed > 0, "[STAKER] staker.gno__stakeToken() || non-existent incentive")

	if len(stakes) > 0 && stakes[tokenId] != nil && stakes[tokenId][incentiveId].liquidityNoOverflow != 0 {
		panic(ufmt.Sprintf("[STAKER] staker.gno__stakeToken() || token(tokenId:%s, incentiveId:%s) already staked", tokenId, incentiveId))
	}

	// pool, tickLower, tickUpper, liquidity := nftPositionInfoGetPositionInfo(
	// 	factory,
	// 	nonfungiblePositionManager,
	// 	tokenId,
	// )
	// require(pool == key.pool, "[STAKER] staker.gno__stakeToken() || token pool is not the incentive pool")

	tickLower, tickUpper, liquidity := nftPositionInfoGetPositionInfo(tokenId)
	require(liquidity > 0, ufmt.Sprintf("[STAKER] staker.gno__stakeToken() || cannot stake token with 0 liquidity__liquidity(%s) > 0", liquidity))

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
	// require(GetTimestamp() >= key.endTime, ufmt.Sprintf("[STAKER] staker.gno__unstakeToken() || incentive not ended"))

	incentiveId := incentiveIdCompute(key)
	secondsPerLiquidityInsideInitialX128, liquidity := findStakes(tokenId, incentiveId)

	require(liquidity != 0, ufmt.Sprintf("[STAKER] staker.gno__unstakeToken() || stake(tokenId:%s, incentiveId:%s) does not exist", tokenId, incentiveId))

	deposit, exist := deposits[tokenId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__unstakeToken() || cannot unstake non-existent deposit(%s)", tokenId))
	deposit.numberOfStakes--

	incentive, exist := incentives[incentiveId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__unstakeToken() || cannot unstake non-existent incetnvie(%s)", incentiveId))
	incentive.numberOfStakes--
	incentives[incentiveId] = incentive

	// _, secondsPerLiquidityInsideX128, _ := key.pool.snapshotCumulativesInside(deposit.tickLower, deposit.tickUpper)
	secondsPerLiquidityInsideX128 := bigint(20) * Q128 // TMP XXX
	reward, secondsInsideX128 := rewardMathComputeRewardAmount(
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
	deposits[tokenId] = deposit
}

func transferDeposit(tokenId bigint, to std.Address) {
	require(to != ZERO_ADDRESS, ufmt.Sprintf("[STAKER] staker.gno__transferDeposit() || cannot transfer to zero address(%s)", to))

	owner := nft.OwnerOf(tid(tokenId))
	require(PrevRealmAddr() == owner, ufmt.Sprintf("[STAKER] staker.gno__transferDeposit() || can only be called by deposit owner__PrevRealmAddr()(%s) == owner(%s)", PrevRealmAddr(), owner))

	deposits[tokenId].owner = owner
	// deposit := deposits[tokenId]
	// deposit.owner = owner
	// deposits[tokenId] = deposit

	// transfer actual NFT
	nft.TransferFrom(a2u(owner), a2u(to), tid(tokenId)) // nft transfer ok
}
