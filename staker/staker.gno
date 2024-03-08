package staker

import (
	"std"
	"time"

	"gno.land/p/demo/common"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"

	"gno.land/r/demo/gnft"
	"gno.land/r/demo/gns"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"
)

var (
	poolIncentives map[string][]string  = make(map[string][]string)  // poolPath => []incentiveId
	incentives     map[string]Incentive = make(map[string]Incentive) // incentiveId => Incentive

	deposits  map[uint64]Deposit = make(map[uint64]Deposit) // tokenId => Deposit
	poolTiers map[string]uint8   = make(map[string]uint8)   // poolPath -> tier
)

func init() {
	// init pool tiers
	// tier 1
	poolTiers["gno.land/r/demo/gns:gno.land/r/demo/wugnot:500"] = 1 // r3v4_xxx:
	// poolTiers["gno.land/r/demo/bar:gno.land/r/demo/baz:100"] = 1 // dev

	// tier 2
	// poolTiers["GNS/USDT_500"] = 2
	// poolTiers["ATOM/GNS_500"] = 2

	// tier 3
	// poolTiers["ATOM/GNOT_500"] = 3
	// poolTiers["ATOM/USDT_500"] = 3
	// poolTiers["ATOM/WETH_500"] = 3
}

func CreateExternalIncentive(
	targetPoolPath string,
	rewardToken string, // token path should be registered
	rewardAmount bigint,
	startTimestamp int64,
	endTimestamp int64,
) {
	require(time.Now().Unix() <= startTimestamp, ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || startTimestamp must be in the future__time.Now().Unix(%d) <= startTimestamp(%d)", time.Now().Unix(), startTimestamp))

	externalDuration := uint64(endTimestamp - startTimestamp)
	if !(externalDuration == TIMESTAMP_90DAYS || externalDuration == TIMESTAMP_180DAYS || externalDuration == TIMESTAMP_360DAYS) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || externalDuration(%d) must be 90, 180, 360 days)", externalDuration))
	}

	fromBalanceBefore := balanceOfByRegisterCall(rewardToken, std.GetOrigCaller())
	require(fromBalanceBefore >= uint64(rewardAmount), ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || not enough rewardAmount(%d) to create incentive(%d)", fromBalanceBefore, rewardAmount))

	poolRewardBalanceBefore := balanceOfByRegisterCall(rewardToken, GetOrigPkgAddr())

	incentiveId := incentiveIdCompute(std.GetOrigCaller(), targetPoolPath, rewardToken)

	// if same incentiveId exists => increase rewardTokenAmount
	for _, v := range poolIncentives[targetPoolPath] {
		if v == incentiveId {
			transferFromByRegisterCall(rewardToken, std.GetOrigCaller(), GetOrigPkgAddr(), uint64(rewardAmount))
			incentives[v].rewardAmount += rewardAmount
			return
		}
	}

	transferFromByRegisterCall(rewardToken, std.GetOrigCaller(), GetOrigPkgAddr(), uint64(rewardAmount))

	poolRewardBalanceAfter := balanceOfByRegisterCall(rewardToken, GetOrigPkgAddr())
	require(poolRewardBalanceAfter-poolRewardBalanceBefore == uint64(rewardAmount), ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || pool reward balance not updated correctly(before:%d, added:%d, final:%d)", poolRewardBalanceBefore, rewardAmount, poolRewardBalanceAfter))

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

func StakeToken(tokenId uint64) (string, bigint, bigint) { // poolPath, token0Amount, token1Amount
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
	liquidity := pn.PositionGetPositionLiquidity(tokenId)
	require(liquidity > 0, ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%d) has no liquidity", tokenId))

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
	return poolKey, token0Amount, token1Amount
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
		externalReward = userClaimedRewardAmount(deposit.owner, tokenId, incentive.rewardToken, bigint(externalReward), true)

		if externalReward > 0 {
			// protocol fee
			toUser := handleRewardFee(incentive.rewardToken, externalReward, false)

			// then transfer rest
			transferByRegisterCall(incentive.rewardToken, deposit.owner, uint64(toUser))
		}

		incentive.rewardAmount -= externalReward
		incentives[incentiveId] = incentive
	}

	// default `Internal` reward
	internalGNS := rewardMathComputeInternalRewardAmount(tokenId, deposit)
	internalGNS = userClaimedRewardAmount(deposit.owner, tokenId, consts.GNS_PATH, bigint(internalGNS), true)

	if internalGNS > 0 {
		// protocol fee
		toUser := handleRewardFee(consts.GNS_PATH, internalGNS, true)

		// then transfer rest
		gns.TransferFrom(a2u(consts.INTERNAL_REWARD_ACCOUNT), a2u(deposit.owner), uint64(toUser))
	}

}

func UnstakeToken(tokenId uint64) (string, bigint, bigint) {
	// Claim All Rewards
	CollectReward(tokenId)

	// unstaked status
	deposit, exist := deposits[tokenId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__UnstakeToken() || tokenId(%d) not staked", tokenId))
	deposits = deleteFromDeposits(deposits, tokenId)

	// transfer NFT ownership to origin owner
	gnft.TransferFrom(a2u(GetOrigPkgAddr()), a2u(deposit.owner), tid(tokenId))

	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)
	return poolPath, token0Amount, token1Amount
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
		incentives = deleteFromIncentives(incentives, incentiveId)
		for i, v := range poolIncentives[targetPoolPath] {
			if v == incentiveId {
				poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath][:i], poolIncentives[targetPoolPath][i+1:]...)
			}
		}
	case incentive.refundee:
		// refundee can end incentive with refund
		refund := incentive.rewardAmount
		poolLeftExternalRewardAmount := balanceOfByRegisterCall(incentive.rewardToken, GetOrigPkgAddr())
		require(poolLeftExternalRewardAmount >= uint64(refund), ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || not enough poolLeftExternalRewardAmount(%s_%d) to refund(%d)", incentive.rewardToken, poolLeftExternalRewardAmount, refund))
		transferByRegisterCall(incentive.rewardToken, incentive.refundee, uint64(refund))

		incentives = deleteFromIncentives(incentives, incentiveId)
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

func deleteFromDeposits(m map[uint64]Deposit, key uint64) map[uint64]Deposit {
	if _, ok := m[key]; ok {
		newMap := make(map[uint64]Deposit)
		for k, v := range m {
			if k != key {
				newMap[k] = v
			}
		}

		return newMap
	}

	return m
}

func deleteFromIncentives(m map[string]Incentive, key string) map[string]Incentive {
	if _, ok := m[key]; ok {
		newMap := make(map[string]Incentive)
		for k, v := range m {
			if k != key {
				newMap[k] = v
			}
		}

		return newMap
	}

	return m
}

func getTokenPairBalanceFromPosition(tokenId uint64) (bigint, bigint) {
	poolKey := pn.PositionGetPositionPoolKey(tokenId)

	pool := pl.GetPoolFromPoolPath(poolKey)
	currentX96 := pool.PoolGetSlot0SqrtPriceX96()
	lowerX96 := pl.TickMathGetSqrtRatioAtTick(pos.PositionGetPositionTickLower(tokenId)).Bigint()
	upperX96 := pl.TickMathGetSqrtRatioAtTick(pos.PositionGetPositionTickUpper(tokenId)).Bigint()

	token0Balance, token1Balance := common.GetAmountsForLiquidity(
		currentX96,
		lowerX96,
		upperX96,
		pn.PositionGetPositionLiquidity(tokenId),
	)

	return token0Balance, token1Balance
}
