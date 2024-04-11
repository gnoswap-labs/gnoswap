package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/common"

	"gno.land/r/demo/gnft"
	"gno.land/r/demo/gns"

	"gno.land/r/gnoswap/consts"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"

	u256 "gno.land/p/demo/gnoswap/uint256"
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
	TIMESTAMP_365DAYS = 31536000

	MUST_EXISTS_IN_TIER_1 = "gno.land/r/demo/gns:gno.land/r/demo/wugnot:3000"
)

func init() {
	// init pool tiers
	// tier 1
	poolTiers[MUST_EXISTS_IN_TIER_1] = 1 // ONLY GNOT:GNS 0.3%
}

// CreateExternalIncentive creates an external incentive for the targetPoolPath
//
// Panics if any of the following conditions are met:
// - startTimestamp is not in the future
// - externalDuration is not 90, 180, or 365 days
// - user doesn't have enough balance to provide as reward
func CreateExternalIncentive(
	targetPoolPath string,
	rewardToken string, // token path should be registered
	_rewardAmount string,
	startTimestamp int64,
	endTimestamp int64,
) {
	if common.GetLimitCaller() {
		std.AssertOriginCall()
	}

	rewardAmount := u256.MustFromDecimal(_rewardAmount)

	// must be at least +1 day midnight
	// must be midnight of the day
	checkStartTime(startTimestamp)

	externalDuration := uint64(endTimestamp - startTimestamp)
	if !(externalDuration == TIMESTAMP_90DAYS || externalDuration == TIMESTAMP_180DAYS || externalDuration == TIMESTAMP_365DAYS) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || externalDuration(%d) must be 90, 180, 365 days)", externalDuration))
	}

	fromBalanceBefore := balanceOfByRegisterCall(rewardToken, std.GetOrigCaller())

	if fromBalanceBefore < rewardAmount.Uint64() {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || user(%s) doesn't have enough amount balance(%d) to create incentive(%d)", std.GetOrigCaller(), fromBalanceBefore, rewardAmount.Uint64()))
	}

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
	if !(poolRewardBalanceAfter-poolRewardBalanceBefore == rewardAmount.Uint64()) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || pool reward balance not updated correctly(before:%d, added:%d, final:%d)", poolRewardBalanceBefore, rewardAmount.Uint64(), poolRewardBalanceAfter))
	}

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

// StakeToken stakes the lp token to the staker contract
//
// Panics if any of the following conditions are met:
// - tokenId already staked
// - tokenId has no liquidity
// - tokenId is not owned by the caller or staker
func StakeToken(tokenId uint64) (string, string, string) { // poolPath, token0Amount, token1Amount
	// check whether tokenId already staked or not
	_, exist := deposits[tokenId]
	if exist {
		panic(ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%d) already staked", tokenId))
	}

	// if caller is owner
	callerIsOwner := gnft.OwnerOf(tid(tokenId)) == std.GetOrigCaller()
	stakerIsOwner := gnft.OwnerOf(tid(tokenId)) == GetOrigPkgAddr()

	if !(callerIsOwner || stakerIsOwner) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || Neither Caller(%s) or Staker(%s) is not owner of tokenId(%d)", std.GetOrigCaller(), GetOrigPkgAddr(), tokenId))
	}

	// check tokenId has liquidity or not
	liquidity := pn.PositionGetPositionLiquidity(tokenId) // *u256.Uint
	if liquidity.Lte(u256.Zero()) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%d) has no liquidity", tokenId))
	}

	// check pool path from tokenid
	poolKey := pn.PositionGetPositionPoolKey(tokenId)

	// staked status
	deposit := deposits[tokenId]
	deposit.owner = std.GetOrigCaller() // NOT ACTUAL OWNER, MUST BE USER ALWAYS
	deposit.numberOfStakes++
	deposit.stakeTimestamp = time.Now().Unix()
	deposit.targetPoolPath = poolKey
	deposits[tokenId] = deposit

	if callerIsOwner { // if caller is owner, transfer NFT ownership to staker contract
		transferDeposit(tokenId, GetOrigPkgAddr())
	} else if stakerIsOwner { // if staker is owner, approve NFT to caller
		gnft.Approve(a2u(std.GetOrigCaller()), tid(tokenId))
	}

	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)
	return poolKey, token0Amount.ToString(), token1Amount.ToString()
}

// CollectReward collects staked reward from tokenId
//
// Panics if any of the following conditions are met:
// - token is not staked
// - caller is not owner of lp token
func CollectReward(tokenId uint64) string { // poolPath
	deposit, exist := deposits[tokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CollectReward() || tokenId(%d) not staked", tokenId))
	}

	if std.PrevRealm().Addr() != deposit.owner {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CollectReward() || only owner(%s) can collect reward from tokenId(%d), std.PrevRealm().Addr()(%s)", deposit.owner, tokenId, std.PrevRealm().Addr()))
	}

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

	return poolPath
}

// UnstakeToken unstakes the lp token from the staker and collects all reward from tokenId
//
// Panics if any of the following conditions are met:
// - token is not staked
func UnstakeToken(tokenId uint64) (string, string, string) { // poolPath, token0Amount, token1Amount
	// Claim All Rewards
	CollectReward(tokenId)

	// unstaked status
	deposit, exist := deposits[tokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] staker.gno__UnstakeToken() || tokenId(%d) not staked", tokenId))
	}
	delete(deposits, tokenId)

	// transfer NFT ownership to origin owner
	gnft.TransferFrom(a2u(GetOrigPkgAddr()), a2u(deposit.owner), tid(tokenId))

	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)
	return poolPath, token0Amount.ToString(), token1Amount.ToString()
}

// EndExternalIncentive ends the external incentive
// Only refundee or admin can end incentive
//
// Panics if any of the following conditions are met:
// - incentive expiration time is not over
// - reward token amount is not enough to refund
func EndExternalIncentive(_refundee, targetPoolPath, rewardToken string) {
	refundee := std.Address(_refundee)

	incentiveId := incentiveIdCompute(refundee, targetPoolPath, rewardToken)

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || cannot end non existent incentive(%s)", incentiveId))
	}

	if time.Now().Unix() < incentive.endTimestamp {
		panic(ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || cannot end incentive before endTimestamp(%d), current(%d)", incentive.endTimestamp, time.Now().Unix()))
	}

	// when incentive end time is over
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

		if poolLeftExternalRewardAmount < refund.Uint64() {
			panic(ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || pool doesn't have enough token(%s) amount(%d) to refund(%d)", incentive.rewardToken, poolLeftExternalRewardAmount, refund))
		}

		transferByRegisterCall(incentive.rewardToken, incentive.refundee, refund.Uint64())

		delete(incentives, incentiveId)
		for i, v := range poolIncentives[targetPoolPath] {
			if v == incentiveId {
				poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath][:i], poolIncentives[targetPoolPath][i+1:]...)
			}
		}
	default:
		panic("[STAKER] staker.gno__EndExternalIncentive() || only refundee or admin can end incentive")
	}
}

func checkStartTime(startTimestamp int64) {
	// must be at least +1 day midnight
	tomorrowMidnight := time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour).Unix()
	if startTimestamp < tomorrowMidnight {
		panic(ufmt.Sprintf("[STAKER] staker.gno__checkStartTime() || startTimestamp(%d) must be at least +1 day midnight(%d)", startTimestamp, tomorrowMidnight))
	}

	// must be midnight of the day
	startTime := time.Unix(startTimestamp, 0)
	hour, minute, second := startTime.Hour(), startTime.Minute(), startTime.Second()

	isMidnight := hour == 0 && minute == 0 && second == 0
	if !isMidnight {
		panic(ufmt.Sprintf("[STAKER] staker.gno__checkStartTime() || startTime(%s) must be midnight of the day", startTime.String()))
	}
}

func transferDeposit(tokenId uint64, to std.Address) {
	owner := gnft.OwnerOf(tid(tokenId))
	if std.GetOrigCaller() == to {
		panic(ufmt.Sprintf("[STAKER] staker.gno__transferDeposit() || only owner(%s) can transfer tokenId(%d), std.GetOrigCaller()(%s)", owner, tokenId, std.GetOrigCaller()))
	}

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

	if token0Balance == nil {
		token0Balance = u256.Zero()
	}
	if token1Balance == nil {
		token1Balance = u256.Zero()
	}

	return token0Balance, token1Balance
}
