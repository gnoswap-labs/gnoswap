package staker

import (
	"std"
	"time"

	"gno.land/p/demo/common"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/gnft"
	"gno.land/r/demo/gns"

	"gno.land/r/demo/consts"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"

	u256 "gno.land/p/big/uint256"
)

var (
	poolIncentives map[string][]string  = make(map[string][]string)  // poolPath => []incentiveId
	incentives     map[string]Incentive = make(map[string]Incentive) // incentiveId => Incentive

	deposits  map[uint64]Deposit = make(map[uint64]Deposit) // tokenId => Deposit
	poolTiers map[string]uint64  = make(map[string]uint64)  // poolPath -> tier
)

const (
	TIMESTAMP_90DAYS  = 7776000
	TIMESTAMP_180DAYS = 15552000
	TIMESTAMP_360DAYS = 31104000
)

func init() {
	// init pool tiers
	// tier 1
	poolTiers["gno.land/r/demo/gns:gno.land/r/demo/wugnot:500"] = 1 // r3v4_xxx: INITIALIZE TIER 1 POOL
}

func CreateExternalIncentive(
	targetPoolPath string,
	rewardToken string, // token path should be registered
	_rewardAmount string,
	startTimestamp int64,
	endTimestamp int64,
) {
	rewardAmount, err := u256.FromDecimal(_rewardAmount)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || u256.FromDecimal(_rewardAmount: %s) failed", _rewardAmount))
	}

	require(time.Now().Unix() <= startTimestamp, ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || startTimestamp must be in the future__time.Now().Unix(%d) <= startTimestamp(%d)", time.Now().Unix(), startTimestamp))

	externalDuration := uint64(endTimestamp - startTimestamp)
	if !(externalDuration == TIMESTAMP_90DAYS || externalDuration == TIMESTAMP_180DAYS || externalDuration == TIMESTAMP_360DAYS) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || externalDuration(%d) must be 90, 180, 360 days)", externalDuration))
	}

	fromBalanceBefore := balanceOfByRegisterCall(rewardToken, std.GetOrigCaller())
	require(fromBalanceBefore >= rewardAmount.Uint64(), ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || not enough rewardAmount(%d) to create incentive(%d)", fromBalanceBefore, rewardAmount.Uint64()))

	poolRewardBalanceBefore := balanceOfByRegisterCall(rewardToken, GetOrigPkgAddr())

	incentiveId := incentiveIdCompute(std.GetOrigCaller(), targetPoolPath, rewardToken)

	// if same incentiveId exists => increase rewardTokenAmount
	for _, v := range poolIncentives[targetPoolPath] {
		if v == incentiveId {
			transferFromByRegisterCall(rewardToken, std.GetOrigCaller(), GetOrigPkgAddr(), rewardAmount.Uint64())
			incentives[v].rewardAmount = new(u256.Uint).Add(incentives[v].rewardAmount, rewardAmount)
			return
		}
	}

	transferFromByRegisterCall(rewardToken, std.GetOrigCaller(), GetOrigPkgAddr(), rewardAmount.Uint64())

	poolRewardBalanceAfter := balanceOfByRegisterCall(rewardToken, GetOrigPkgAddr())
	require(
		poolRewardBalanceAfter-poolRewardBalanceBefore == rewardAmount.Uint64(),
		ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || pool reward balance not updated correctly(before:%d, added:%d, final:%d)",
			poolRewardBalanceBefore, rewardAmount.Uint64(), poolRewardBalanceAfter))

	incentives[incentiveId] = Incentive{
		targetPoolPath: targetPoolPath,
		rewardToken:    rewardToken,
		rewardAmount:   rewardAmount,
		startTimestamp: startTimestamp,
		endTimestamp:   endTimestamp,
		refundee:       std.GetOrigCaller(),
	}

	poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath], incentiveId)
}

func StakeToken(tokenId uint64) (string, string, string) { // poolPath, token0Amount, token1Amount
	// check whether tokenId already staked or not
	_, exist := deposits[tokenId]
	require(!exist, ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%d) already staked", tokenId))

	// check tokenId owner
	require(
		gnft.OwnerOf(tid(tokenId)) == std.GetOrigCaller(),
		ufmt.Sprintf(
			"[STAKER] staker.gno__StakeToken() || only owner can stake their token tokenId(%d), owner(%s) == std.GetOrigCaller(%s)",
			tokenId, gnft.OwnerOf(tid(tokenId)), std.GetOrigCaller(),
		),
	)

	// check tokenId has liquidity or not
	liquidity := pn.PositionGetPositionLiquidity(tokenId) // *u256.Uint
	require(liquidity.Gt(u256.Zero()), ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%d) has no liquidity", tokenId))

	// check pool path from tokenid
	poolKey := pn.PositionGetPositionPoolKey(tokenId)

	// staked status
	deposit := deposits[tokenId]
	deposit.numberOfStakes++
	deposit.stakeTimestamp = time.Now().Unix()
	deposit.targetPoolPath = poolKey
	deposits[tokenId] = deposit

	// transfer NFT ownership to staker contract
	transferDeposit(tokenId, GetOrigPkgAddr())

	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)
	return poolKey, token0Amount.ToString(), token1Amount.ToString()
}

func CollectReward(tokenId uint64) {
	deposit, exist := deposits[tokenId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__CollectReward() || tokenId(%d) not staked", tokenId))

	require(std.PrevRealm().Addr() == deposit.owner, ufmt.Sprintf("[STAKER] staker.gno__CollectReward() || only owner(%s) can collect reward from tokenId(%d), std.PrevRealm().Addr()(%s)", deposit.owner, tokenId, std.PrevRealm().Addr()))

	// poolPath to collect reward
	poolPath := pn.PositionGetPositionPoolKey(tokenId)

	// get all external reward list for this pool
	for _, incentiveId := range poolIncentives[poolPath] {
		incentive := incentives[incentiveId]
		externalReward := rewardMathComputeExternalRewardAmount(tokenId, deposit, incentive) // external reward
		externalReward = userClaimedRewardAmount(deposit.owner, tokenId, incentive.rewardToken, externalReward, true)

		if externalReward.Gt(u256.Zero()) {
			// protocol fee
			toUser := handleRewardFee(incentive.rewardToken, externalReward, false)

			// then transfer rest
			transferByRegisterCall(incentive.rewardToken, deposit.owner, toUser.Uint64())
		}

		incentive.rewardAmount = new(u256.Uint).Sub(incentive.rewardAmount, externalReward)
		incentives[incentiveId] = incentive
	}

	// default `Internal` reward
	internalGNS := rewardMathComputeInternalRewardAmount(tokenId, deposit)
	internalGNS = userClaimedRewardAmount(deposit.owner, tokenId, consts.GNS_PATH, internalGNS, true)

	if internalGNS.Gt(u256.Zero()) {
		// protocol fee
		toUser := handleRewardFee(consts.GNS_PATH, internalGNS, true)

		// then transfer rest
		gns.TransferFrom(a2u(consts.INTERNAL_REWARD_ACCOUNT), a2u(deposit.owner), toUser.Uint64())
	}
}

func UnstakeToken(tokenId uint64) (string, string, string) {
	// Claim All Rewards
	CollectReward(tokenId)

	// unstaked status
	deposit, exist := deposits[tokenId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__UnstakeToken() || tokenId(%d) not staked", tokenId))
	delete(deposits, tokenId)

	// transfer NFT ownership to origin owner
	gnft.TransferFrom(a2u(GetOrigPkgAddr()), a2u(deposit.owner), tid(tokenId))

	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)
	return poolPath, token0Amount.ToString(), token1Amount.ToString()
}

func EndExternalIncentive(refundee std.Address, targetPoolPath, rewardToken string) {
	incentiveId := incentiveIdCompute(refundee, targetPoolPath, rewardToken)
	incentive, exist := incentives[incentiveId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || cannot end non existent incentive(%s)", incentiveId))
	require(time.Now().Unix() >= incentive.endTimestamp, ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || cannot end incentive before endTimestamp(%d), current(%d)", incentive.endTimestamp, time.Now().Unix()))

	// when incentive is ended
	// 1. admin can end incentive without refund
	// 2. refundee can end incentive with refund
	switch std.GetOrigCaller() {
	case consts.GNOSWAP_ADMIN:
		// admin can end incentive without refund
		delete(incentives, incentiveId)
		for i, v := range poolIncentives[targetPoolPath] {
			if v == incentiveId {
				poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath][:i], poolIncentives[targetPoolPath][i+1:]...)
			}
		}
	case incentive.refundee:
		// refundee can end incentive with refund
		refund := incentive.rewardAmount

		poolLeftExternalRewardAmount := balanceOfByRegisterCall(incentive.rewardToken, GetOrigPkgAddr())
		require(poolLeftExternalRewardAmount >= refund.Uint64(), ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || not enough poolLeftExternalRewardAmount(%s_%d) to refund(%d)", incentive.rewardToken, poolLeftExternalRewardAmount, refund))
		transferByRegisterCall(incentive.rewardToken, incentive.refundee, refund.Uint64())

		delete(incentives, incentiveId)
		for i, v := range poolIncentives[targetPoolPath] {
			if v == incentiveId {
				poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath][:i], poolIncentives[targetPoolPath][i+1:]...)
			}
		}
	default:
		require(false, ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || only refundee or admin can end incentive"))
	}
}

func transferDeposit(tokenId uint64, to std.Address) {
	owner := gnft.OwnerOf(tid(tokenId))
	require(owner == std.GetOrigCaller(), ufmt.Sprintf("[STAKER] staker.gno__transferDeposit() || only owner(%s) can transfer tokenId(%d), std.GetOrigCaller()(%s)", owner, tokenId, std.GetOrigCaller()))

	deposits[tokenId].owner = owner

	// transfer NFT ownership
	gnft.TransferFrom(a2u(owner), a2u(to), tid(tokenId))
}

func getTokenPairBalanceFromPosition(tokenId uint64) (*u256.Uint, *u256.Uint) {
	poolKey := pn.PositionGetPositionPoolKey(tokenId)

	pool := pl.GetPoolFromPoolPath(poolKey)
	currentX96 := pool.PoolGetSlot0SqrtPriceX96()
	lowerX96 := common.TickMathGetSqrtRatioAtTick(pn.PositionGetPositionTickLower(tokenId))
	upperX96 := common.TickMathGetSqrtRatioAtTick(pn.PositionGetPositionTickUpper(tokenId))

	token0Balance, token1Balance := common.GetAmountsForLiquidity(
		currentX96,
		lowerX96,
		upperX96,
		pn.PositionGetPositionLiquidity(tokenId),
	)

	return token0Balance, token1Balance
}
