package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	gnft "gno.land/r/demo/gnft" // GNFT, Gnoswap NFT
	gns "gno.land/r/demo/gns"   // GNS, Gnoswap Share

	pl "gno.land/r/demo/pool"
	pos "gno.land/r/demo/position"
)

const (
	INTERNAL_REWARD_ACCOUNT = std.Address("g1paqttvcjcluuya9n9twyw7yacv54mt7ld3gvzm") // hardcoded at gns.gno
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
	poolTiers["gno.land/r/demo/gns:gno.land/r/demo/wugnot:500"] = 1
	poolTiers["gno.land/r/demo/bar:gno.land/r/demo/baz:100"] = 1 // dev

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
	rewardAmount uint64,
	startTimestamp int64,
	endTimestamp int64,
) {
	require(GetTimestamp() <= startTimestamp, ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || startTimestamp must be in the future__GetTimestamp(%d) <= startTimestamp(%d)", GetTimestamp(), startTimestamp))

	externalDuration := uint64(endTimestamp - startTimestamp)
	if !(externalDuration == TIMESTAMP_90DAYS || externalDuration == TIMESTAMP_180DAYS || externalDuration == TIMESTAMP_360DAYS) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || externalDuration(%d) must be 90, 180, 360 days)", externalDuration))
	}

	fromBalanceBefore := balanceOfByRegisterCall(rewardToken, GetOrigCaller())
	require(fromBalanceBefore >= rewardAmount, ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || not enough rewardAmount(%d) to create incentive(%d)", fromBalanceBefore, rewardAmount))

	poolRewardBalanceBefore := balanceOfByRegisterCall(rewardToken, GetOrigPkgAddr())

	incentiveId := incentiveIdCompute(GetOrigCaller().String(), targetPoolPath, rewardToken)

	// if same incentiveId exists => increase rewardTokenAmount
	for _, v := range poolIncentives[targetPoolPath] {
		if v == incentiveId {
			transferFromByRegisterCall(rewardToken, GetOrigCaller(), GetOrigPkgAddr(), rewardAmount)
			incentives[v].rewardAmount += rewardAmount
			return
		}
	}

	transferFromByRegisterCall(rewardToken, GetOrigCaller(), GetOrigPkgAddr(), rewardAmount)

	poolRewardBalanceAfter := balanceOfByRegisterCall(rewardToken, GetOrigPkgAddr())
	require(poolRewardBalanceAfter-poolRewardBalanceBefore == rewardAmount, ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || pool reward balance not updated correctly"))

	incentives[incentiveId] = Incentive{
		targetPoolPath: targetPoolPath,
		rewardToken:    rewardToken,
		rewardAmount:   rewardAmount,
		startTimestamp: startTimestamp,
		endTimestamp:   endTimestamp,
		refundee:       GetOrigCaller(),
	}

	poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath], incentiveId)
}

func StakeToken(tokenId uint64) (string, bigint, bigint) {
	// token0Path, token1Path (≈ poolPath)
	// token1AMount, token0Amount

	// check whether tokenId already staked or not
	_, exist := deposits[tokenId]
	require(!exist, ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%d) already staked", tokenId))

	// check tokenId owner
	require(
		gnft.OwnerOf(tid(tokenId)) == GetOrigCaller(),
		ufmt.Sprintf(
			"[STAKER] staker.gno__StakeToken() || only owner can stake their token tokenId(%d), owner(%s) == GetOrigCaller(%s)",
			tokenId, gnft.OwnerOf(tid(tokenId)), GetOrigCaller(),
		),
	)

	// check tokenId has liquidity or not
	liquidity := pos.PositionGetPositionLiquidity(tokenId)
	require(liquidity > 0, ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%d) has no liquidity", tokenId))

	// check pool path from tokenid
	poolKey := pos.PositionGetPositionPoolKey(tokenId)

	// staked status
	deposit := deposits[tokenId]
	deposit.numberOfStakes++
	deposit.stakeTimestamp = GetTimestamp()
	deposit.targetPoolPath = poolKey
	deposits[tokenId] = deposit

	// transfer NFT ownership to staker contract
	transferDeposit(tokenId, GetOrigPkgAddr())

	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)
	return poolKey, token0Amount, token1Amount
}

func CollectReward(
	tokenId uint64, // LP TokenID
) {
	deposit, exist := deposits[tokenId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__CollectReward() || tokenId(%d) not staked", tokenId))

	require(PrevRealmAddr() == deposit.owner, ufmt.Sprintf("[STAKER] staker.gno__CollectReward() || only owner(%s) can collect reward from tokenId(%d), PrevRealmAddr()(%s)", deposit.owner, tokenId, PrevRealmAddr()))

	// poolPath to collect reward
	poolPath := pos.PositionGetPositionPoolKey(tokenId)

	// get all external reward list for this pool
	for _, incentiveId := range poolIncentives[poolPath] {
		incentive := incentives[incentiveId]
		externalReward := rewardMathComputeExternalRewardAmount(tokenId, deposit, incentive) // external reward
		externalReward = userClaimedRewardAmount(deposit.owner, incentive.rewardToken, bigint(externalReward), true)

		if externalReward > 0 {
			transferByRegisterCall(incentive.rewardToken, deposit.owner, uint64(externalReward))
		}

		incentive.rewardAmount -= externalReward
		incentives[incentiveId] = incentive
	}

	// default `Internal` reward
	internalGNS := rewardMathComputeInternalRewardAmount(tokenId, deposit)
	internalGNS = userClaimedRewardAmount(deposit.owner, "gno.land/r/demo/gns", bigint(internalGNS), true)

	if internalGNS > 0 {
		// transfer it
		gns.TransferFrom(a2u(INTERNAL_REWARD_ACCOUNT), a2u(deposit.owner), uint64(internalGNS))
	}

}

func UnstakeToken(tokenId uint64) (string, bigint, bigint) {
	deposit, exist := deposits[tokenId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__UnstakeToken() || tokenId(%d) not staked", tokenId))

	// address who executed StakeToken() can call UnstakeToken()
	require(PrevRealmAddr() == deposit.owner, ufmt.Sprintf("[STAKER] staker.gno__UnstakeToken() || only owner(%s) can unstake their token(%d), PrevRealmAddr()(%s)", deposit.owner, tokenId, PrevRealmAddr()))

	// poolPath to unstake lp token
	poolPath := pos.PositionGetPositionPoolKey(tokenId)

	// get all external reward list for this pool
	for _, incentiveId := range poolIncentives[poolPath] {
		incentive := incentives[incentiveId]
		externalReward := rewardMathComputeExternalRewardAmount(tokenId, deposit, incentive) // external reward
		externalReward = userClaimedRewardAmount(deposit.owner, incentive.rewardToken, bigint(externalReward), true)

		if externalReward > 0 {
			transferByRegisterCall(incentive.rewardToken, deposit.owner, uint64(externalReward))
		}

		incentive.rewardAmount -= externalReward
		incentives[incentiveId] = incentive
	}

	// default `Internal` reward
	internalGNS := rewardMathComputeInternalRewardAmount(tokenId, deposit)
	internalGNS = userClaimedRewardAmount(deposit.owner, "gno.land/r/demo/gns", bigint(internalGNS), true)
	if internalGNS > 0 {
		// transfer it
		gns.TransferFrom(a2u(INTERNAL_REWARD_ACCOUNT), a2u(deposit.owner), uint64(internalGNS))
	}

	// unstaked status
	deposits = deleteFromDeposits(deposits, tokenId)

	// transfer NFT ownership to origin owner
	gnft.TransferFrom(a2u(GetOrigPkgAddr()), a2u(deposit.owner), tid(tokenId))

	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)
	return poolPath, token0Amount, token1Amount
}

func EndExternalIncentive(refundee, targetPoolPath, rewardToken string) {
	incentiveId := incentiveIdCompute(refundee, targetPoolPath, rewardToken)
	incentive, exist := incentives[incentiveId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || cannot end non existent incentive(%s)", incentiveId))
	require(GetTimestamp() >= incentive.endTimestamp, ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || cannot end incentive before endTimestamp(%d), current(%d)", incentive.endTimestamp, GetTimestamp()))

	// when incentive is ended
	// 1. admin can end incentive without refund
	// 2. refundee can end incentive with refund
	switch GetOrigCaller() {
	case std.Address("g16kvq0mra3atvr07lkdwc2x6jqmna8a4kt0e85d"): // ADMIN
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
		require(poolLeftExternalRewardAmount >= refund, ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || not enough poolLeftExternalRewardAmount(%s_%d) to refund(%d)", incentive.rewardToken, poolLeftExternalRewardAmount, refund))
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
	require(owner == GetOrigCaller(), ufmt.Sprintf("[STAKER] staker.gno__transferDeposit() || only owner(%s) can transfer tokenId(%d), GetOrigCaller()(%s)", owner, tokenId, PrevRealmAddr()))

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
	poolKey := pos.PositionGetPositionPoolKey(tokenId)

	pool := pl.GetPoolFromPoolKey(poolKey)
	currentX96 := pool.PoolGetSlot0SqrtPriceX96()
	lowerX96 := pl.TickMathGetSqrtRatioAtTick(pos.PositionGetPositionTickLower(tokenId))
	upperX96 := pl.TickMathGetSqrtRatioAtTick(pos.PositionGetPositionTickUpper(tokenId))

	token0Balance, token1Balance := liquidityAmountsGetAmountsForLiquidity(
		currentX96,
		lowerX96,
		upperX96,
		pos.PositionGetPositionLiquidity(tokenId),
	)

	return token0Balance, token1Balance
}
