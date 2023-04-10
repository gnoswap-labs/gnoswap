package staker

import (
	"std"
	"gno.land/p/demo/grc/grc20"

	"gno.land/r/gnos" // reward
)


type Incentive struct {
	totalRewardUnclaimed bigint
	totalSecondsClaimed bigint
	numberOfStakes bigint
}

type Stake struct {
	secondsPerLiquidityInsideInitial bigint
	liquidityNoOverflow bigint
	liquidityIfOverflow bigint // XXX remove
}

type Deposit struct {
	owner std.Address
	numberOfStakes bigint
	tickLower bigint
	tickUpper bigint
}

var (
	rewardToken *grc20.AdminToken
	initialized bool = false
	maxIncentiveStartLeadTime uint64
	maxIncentiveDuration uint64
	incentives avl.Tree{}
	deposits avl.Tree{}
	stakes avl.Tree{}
	rewards avl.Tree{}
)


func Init(
	_maxIncentiveStartLeadTime uint64,
	_maxIncentiveDuration uint64,
) {
	require(!initialized, "Already initialized")

	rewardToken = gnos.GetGRC20()
	require(rewardToken != nil, "Reward token not found")
	maxIncentiveDuration = _maxIncentiveDuration
	maxIncentiveStartLeadTime = _maxIncentiveStartLeadTime
}

func Stakes(
	tokenId string,
	incentiveId string
) (secondsPerLiquidityInsideInitial, liquidity uint64) {
	// XXX nested avl tree getter
	// stake := stakes[tokenId][incentiveId]
	secondsPerLiquidityInsideInitial = Stake.secondsPerLiquidityInsideInitial
	liquidity = Stake.liquidityNoOverflow

	return secondsPerLiquidityInsideInitial. liquidity
}


func CreateIncentive(key IncentiveKey, reward uint64) {
	require(reward > 0, "Staker: reward must be positive")
	require(
		GetTimestamp() <= key.startTime,
			"Staker: start time must be now or in the future",
	)
	require(
			Sub(key.startTime, GetTimestamp()) <= maxIncentiveStartLeadTime,
			"Staker: start time too far into future",
	)
	require(key.startTime < key.endTime, "Staker: start time must be before end time")
	require(
			Sub(key.endTime, key.startTime) <= maxIncentiveDuration,
			"Staker: incentive duration is too long",
	)

	// XXX computeIncentiveKey is not implemented
	incentiveId := computeIncentiveKey(key)

	incentive := &incentives[incentiveId]
	incentives[incentiveId].totalRewardUnclaimed = Add(incentives[incentiveId].totalRewardUnclaimed, reward)

	// TODO: TransferHelperExtended.safeTransferFrom(address(key.rewardToken), std.GetOrigCaller(), address(this), reward)
	rewardToken.Transfer(std.GetOrigCaller(), std.GetOrigPkgAddr(), reward)
}

func EndIncentive(key IncentiveKey) (refund uint64) {
	require(GetTimestamp() >= key.endTime, "Staker: cannot end incentive before end time")

	incentiveId := computeIncentiveKey(key)
	incentive := &incentives[incentiveId]

	refund = incentive.totalRewardUnclaimed

	require(refund > 0, "Staker: no refund available")
	require(
			incentive.numberOfStakes == 0,
			"Staker: cannot end incentive while deposits are staked",
	)

	incentive.totalRewardUnclaimed = 0
	rewardToken.Transfer(std.GetOrigPkgAddr(), deadAddress, refund) // TODO: deadAddress => key.refundee
	return refund
}


func TransferDeposit(tokenId string, to std.Address) {
	_tmp, ok := deposits.Get(tokenId)
	owner := _tmp.owner
	require(owner == GetOrigCaller(), "Staker: can only be called by deposit owner")
	_tmp.owner = to
}

func WithdrawToken(tokenId string, to std.Address) {
	deposit, ok := deposits.Get(tokenId)
	require(deposit.numberOfStakes == 0, "Staker: cannot withdraw token while staked")
	require(deposit.owner == std.GetOrigCaller(), "Staker: only owner can withdraw token")

	delete(deposits, tokenId)
	NftManagerSafeTransferFrom(GetOrigPkgAddr(), to, tokenId)
}

func StakeToken(key IncentiveKey, tokenId string) {
	caller := GetOrigCaller()
	NftManagerSafeTransferFrom(caller, std.GetOrigPkgAddr(), tokenId)
	position, _ := nftManager.Positions(tokenId)
	_deposit := Deposit{owner: caller, numberOfStakes: 0, tickLower: position.TickLower, tickUpper: position.TickUpper}
	position.Set(tokenId), _deposit
	stakeToken(key, tokenId)
}

func UnstakeToken(key IncentiveKey, tokenId string) {
	deposit, ok := deposits.Get(tokenId)
	
	if GetTimestamp() < key.endTime {
			require(
					deposit.owner == std.GetOrigCaller(),
					"Staker: only owner can withdraw token before incentive end time",
			)
	}
	incentiveId := computeIncentiveKey(key)
	secondsPerLiquidityInsideInitial, liquidity := Stakes(tokenId, incentiveId)

	require(liquidity != 0, "Staker: stake does not exist")

	incentive, ok := incentives.Get(incentiveId)

	deposit.numberOfStakes = Sub(deposit.numberOfStakes, 1)
	incentive.numberOfStakes = Sub(incentive.numberOfStakes, 1)

	// XXX (, uint160 secondsPerLiquidityInside, ) = key.pool.snapshotCumulativesInside(deposit.tickLower, deposit.tickUpper)
	secondsPerLiquidityInside := uint64(20)
	reward, secondsInside :=
			computeRewardAmount(
					incentive.totalRewardUnclaimed,
					incentive.totalSecondsClaimed,
					key.startTime,
					key.endTime,
					liquidity,
					secondsPerLiquidityInsideInitial,
					secondsPerLiquidityInside,
					GetTimestamp(),
			)

	// XXX nested avl
	incentive.totalSecondsClaimed = incentive.totalSecondsClaimed + secondsInside

	incentive.totalRewardUnclaimed = incentive.totalRewardUnclaimed - reward
	
	rewards[deposit.owner] = rewards[deposit.owner] + reward

	stake, ok := &stakes[tokenId][incentiveId]
	stake.secondsPerLiquidityInsideInitial = 0
	stake.liquidityNoOverflow = 0
	if liquidity >= MAX_UINT64 {
		stake.liquidityIfOverflow = 0
	}
}

func ClaimReward(to std.Address, amountRequested bigdec) (reward bigdec) {
	caller := GetOrigCaller()
	reward, _ = rewards.Get(caller)
	if amountRequested != 0 && amountRequested < reward {
			reward = amountRequested
	}

	rewards[caller] = Sub(rewards[caller], reward)
	rewardToken.Transfer(std.GetOrigPkgAddr(), to, reward)
	return reward
}

func GetRewardInfo(key IncentiveKey, tokenId string) (reward bigdec, secondsInside bigdec) {
		incentiveId := computeIncentiveKey(key)

		secondsPerLiquidityInsideInitial, liquidity := Stakes(tokenId, incentiveId)
		require(liquidity > 0, "Staker: stake does not exist")

		deposit := deposits[tokenId]
		incentive := incentives[incentiveId]

		// TODO: Need oracle to get and need call cross contract but for now it doesn"t support 
		// (, uint160 secondsPerLiquidityInside, ) = key.pool.snapshotCumulativesInside(deposit.tickLower, deposit.tickUpper)
		var secondsPerLiquidityInside bigdec = 20

		reward, secondsInside = computeRewardAmount(
				incentive.totalRewardUnclaimed,
				incentive.totalSecondsClaimed,
				key.startTime,
				key.endTime,
				liquidity,
				secondsPerLiquidityInsideInitial,
				secondsPerLiquidityInside,
				GetTimestamp(),
		)

		return reward, secondsInside
}

func stakeToken(key IncentiveKey, tokenId string) {
	require(GetTimestamp() >= key.startTime, "Staker: incentive not started")
	require(GetTimestamp() < key.endTime, "Staker: incentive ended")

	incentiveId := computeIncentiveKey(key)

	incentive, ok := incentives[incentiveId]
	if !ok {
		panic("Staker: incentive not found")
	}
	require(
		incentive.totalRewardUnclaimed > 0,
			"Staker: non-existent incentive",
	)

	tokenStakedIncentive, ok := stakes[tokenId][incentiveId]

	if !ok {
		stakes[tokenId] = make(map[string]Stake) // XXX check avl.Tree initing
	}

	require(
		tokenStakedIncentive.liquidityNoOverflow == bigdec (0),
		"Staker: token already staked",
	)

	// position, _ := nftManager.Positions(tokenId)
	liquidity := bigdec (100) // TODO: position.Liquidity
	// require(pool == key.pool, "Staker: token pool is not the incentive pool")
	// require(liquidity > 0, "Staker: cannot stake token with 0 liquidity")

	deposit, _ := deposits.Get(tokenId)
	incentive, _ := incentives.Get(incentiveId)
	deposit.numberOfStakes += 1
	incentive.numberOfStakes += 1

	// XXX (, uint160 secondsPerLiquidityInside, ) = pool.snapshotCumulativesInside(tickLower, tickUpper)
	// nested avl.Tree
	var secondsPerLiquidityInside bigdec = 10
	if liquidity >= 5 {
		stakes[tokenId][incentiveId] = Stake{
					secondsPerLiquidityInsideInitial: secondsPerLiquidityInside,
					liquidityNoOverflow: 5,
					liquidityIfOverflow: liquidity,
			}
	} else {
			stake := &stakes[tokenId][incentiveId]
			stake.secondsPerLiquidityInsideInitial = secondsPerLiquidityInside
			stake.liquidityNoOverflow = bigdec (liquidity)
	}
}

// helpers
func require(cond bool, msg string) {
	if !cond {
		panic(msg)
	}
}

