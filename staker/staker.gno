package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	gnft "gno.land/r/demo/gnft" // GNFT, Gnoswap NFT
	gns "gno.land/r/demo/gns"   // INTERAL REWARD FIXED

	s "gno.land/r/demo/position"
)

const (
	INTERNAL_REWARD_ACCOUNT = std.Address("g1d9exzh6lta047h6lta047h6lta047h6l8ylkpa") // hardcoded at gns.gno
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
	poolTiers["gno.land/r/demo/bar:gnot:100"] = 1 // DEV

	// tier 2
	poolTiers["GNS/USDT_500"] = 2
	poolTiers["ATOM/GNS_500"] = 2

	// tier 3
	poolTiers["ATOM/GNOT_500"] = 3
	poolTiers["ATOM/USDT_500"] = 3
	poolTiers["ATOM/WETH_500"] = 3
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

func StakeToken(
	tokenId uint64, // LP TokenID
) {
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
	liquidity := s.PositionGetPositionLiquidity(tokenId)
	require(liquidity > 0, ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%d) has no liquidity", tokenId))

	// check pool path from tokenid
	poolKey := s.PositionGetPositionPoolKey(tokenId)

	// staked status
	deposit := deposits[tokenId]
	deposit.numberOfStakes++
	deposit.stakeTimestamp = GetTimestamp()
	deposit.targetPoolPath = poolKey
	deposits[tokenId] = deposit

	// transfer NFT ownership to staker contract
	transferDeposit(tokenId, GetOrigPkgAddr())
}

func CollectReward(
	tokenId uint64, // LP TokenID
) {
	// check whether tokenId is staked or not
	_, exist := deposits[tokenId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__CollectReward() || tokenId(%d) not staked", tokenId))

	// check tokenId owner
	require(
		gnft.OwnerOf(tid(tokenId)) == GetOrigCaller(),
		ufmt.Sprintf(
			"[STAKER] staker.gno__CollectReward() || only owner can collect reward__gnft.OwnerOf(tid(tokenId(%d)))(%s) == GetOrigCaller()(%s)",
			tokenId, gnft.OwnerOf(tid(tokenId)), GetOrigCaller(),
		),
	)
}

func UnstakeToken(
	tokenId uint64, // LP TokenID
) {
	deposit, exist := deposits[tokenId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__UnstakeToken() || tokenId(%d) not staked", tokenId))

	// address who executed StakeToken() can call UnstakeToken()
	require(PrevRealmAddr() == deposit.owner, ufmt.Sprintf("[STAKER] staker.gno__UnstakeToken() || only owner(%s) can unstake their token(%d), PrevRealmAddr()(%s)", deposit.owner, tokenId, PrevRealmAddr()))

	// poolPath to unstake lp token
	poolPath := s.PositionGetPositionPoolKey(tokenId)

	// get all external reward list for this pool
	for _, incentiveId := range poolIncentives[poolPath] {
		incentive := incentives[incentiveId]
		externalReward := rewardMathComputeExternalRewardAmount(tokenId, deposit, incentive) // external reward

		transferByRegisterCall(incentive.rewardToken, deposit.owner, uint64(externalReward))

		incentive.rewardAmount -= externalReward
		incentives[incentiveId] = incentive
	}

	// default `Internal` reward
	internalGNS := rewardMathComputeInternalRewardAmount(tokenId, deposit)

	// transfer it
	gns.TransferFrom(a2u(INTERNAL_REWARD_ACCOUNT), a2u(deposit.owner), uint64(internalGNS))

	// unstaked status
	delete(deposits, tokenId)

	// transfer NFT ownership to unstaker
	gnft.TransferFrom(a2u(GetOrigPkgAddr()), a2u(deposit.owner), tid(tokenId))
}

func EndExternalIncentive(refundee, targetPoolPath, rewardToken string) {
	incentiveId := incentiveIdCompute(refundee, targetPoolPath, rewardToken)
	incentive, exist := incentives[incentiveId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || cannot end non existent incentive(%s)", incentiveId))
	require(GetTimestamp() >= incentive.endTimestamp, ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || cannot end incentive before endTimestamp(%d), current(%d)", incentive.endTimestamp, GetTimestamp()))

	require(incentive.refundee == std.GetOrigCaller(), "[STAKER] staker.gno__EndExternalIncentive() || only refundee can end incentive")

	refund := incentive.rewardAmount

	poolExternalReward := balanceOfByRegisterCall(incentive.rewardToken, GetOrigPkgAddr())
	require(poolExternalReward >= refund, ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || not enough poolExternalReward(%d) to refund(%d)", poolExternalReward, refund))

	transferByRegisterCall(incentive.rewardToken, incentive.refundee, uint64(refund))

	delete(incentives, incentiveId)
	for i, v := range poolIncentives[targetPoolPath] {
		if v == incentiveId {
			poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath][:i], poolIncentives[targetPoolPath][i+1:]...)
		}
	}
}

func transferDeposit(tokenId uint64, to std.Address) {
	owner := gnft.OwnerOf(tid(tokenId))
	require(owner == GetOrigCaller(), ufmt.Sprintf("[STAKER] staker.gno__transferDeposit() || only owner(%s) can transfer tokenId(%d), GetOrigCaller()(%s)", owner, tokenId, PrevRealmAddr()))

	deposits[tokenId].owner = owner

	// transfer NFT ownership
	gnft.TransferFrom(a2u(owner), a2u(to), tid(tokenId))
}
