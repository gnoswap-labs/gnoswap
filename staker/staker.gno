package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	gnft "gno.land/r/gnft" // GNFT, Gnoswap NFT
	gns "gno.land/r/gns"   // GNS, INTERNAL Reward Token
	obl "gno.land/r/obl"   // OBL, EXTERNAL Reward Token

	s "gno.land/r/position"
)

const (
	INTERNAL_REWARD_ACCOUNT = std.Address("g1d9exzh6lta047h6lta047h6lta047h6l8ylkpa") // hardcoded
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
	poolTiers["BAR/FOO_500"] = 1 // DEV

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
	// rewardToken *grc20.AdminToken, // FIXED TO OBL for now
	rewardToken string,
	rewardAmount uint64,
	startTimestamp int64,
	endTimestamp int64,
) {
	require(GetTimestamp() <= startTimestamp, ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || startTimestamp must be in the future__GetTimestamp(%d) <= startTimestamp(%d)", GetTimestamp(), startTimestamp))
	require(endTimestamp-startTimestamp >= TIMESTAMP_30DAYS, ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || endTimestamp must be at least 30 days after startTimestamp__endTimestamp-startTimestamp(%d) >= TIMESTAMP_30DAYS(%d)", endTimestamp-startTimestamp, TIMESTAMP_30DAYS))

	incentiveId := incentiveIdCompute(targetPoolPath, rewardToken)

	// check whether incentive already exists or not
	for _, v := range poolIncentives[targetPoolPath] {
		if v == incentiveId {
			panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || incentive(%s) already exists", incentiveId))
		}
	}

	from := a2u(GetOrigCaller())
	fromBalanceBefore := obl.BalanceOf(from)
	require(fromBalanceBefore >= rewardAmount, ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || not enough OBL(%s) to create incentive(%s)", fromBalanceBefore, rewardAmount))

	to := a2u(GetOrigPkgAddr()) // staker contract
	poolRewardBalanceBefore := obl.BalanceOf(to)

	obl.TransferFrom(from, to, rewardAmount)
	poolRewardBalanceAfter := obl.BalanceOf(to)
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
	tokenId uint64, // GNFT ID
) {
	// check whether tokenId already staked or not
	_, exist := deposits[tokenId]
	require(!exist, ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%s) already staked", tokenId))

	// check tokenId owner
	require(
		gnft.OwnerOf(tid(tokenId)) == GetOrigCaller(),
		ufmt.Sprintf(
			"[STAKER] staker.gno__StakeToken() || only owner can stake their token__gnft.OwnerOf(tid(tokenId(%s)))(%s) == GetOrigCaller()(%s)",
			tokenId, gnft.OwnerOf(tid(tokenId)), GetOrigCaller(),
		),
	)

	// check tokenId has liquidity or not
	liquidity := s.PositionGetPositionLiquidity(tokenId)
	require(liquidity > 0, ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%s) has no liquidity", tokenId))

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

func UnstakeToken(
	tokenId uint64, // GNFT TokenID
) {
	deposit, exist := deposits[tokenId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__UnstakeToken() || tokenId(%s) not staked", tokenId))

	// address who executed StakeToken() can call UnstakeToken()
	require(PrevRealmAddr() == deposit.owner, ufmt.Sprintf("[STAKER] staker.gno__UnstakeToken() || only owner(%s) can unstake their token(%s), PrevRealmAddr()(%s)", deposit.owner, tokenId, PrevRealmAddr()))

	// poolPath to unstake lp token
	poolPath := s.PositionGetPositionPoolKey(tokenId)

	// get all external reward list for this pool
	for _, incentiveId := range poolIncentives[poolPath] {
		incentive := incentives[incentiveId]
		externalReward := rewardMathComputeExternalRewardAmount(tokenId, deposit, incentive) // OBL reward

		// r3v4_xxx: get external token then call transfer
		// r3v4_xxx: handle native coin(gnot) reward
		obl.Transfer(a2u(deposit.owner), uint64(externalReward))

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

func EndExternalIncentive(targetPoolPath, rewardToken string) {
	incentiveId := incentiveIdCompute(targetPoolPath, rewardToken)
	incentive, exist := incentives[incentiveId]
	require(exist, ufmt.Sprintf("[STAKER] staker.gno__EndIncentive() || cannot end non existent incentive(%s)", incentiveId))
	require(GetTimestamp() >= incentive.endTimestamp, ufmt.Sprintf("[STAKER] staker.gno__EndIncentive() || cannot end incentive before endTimestamp(%s), current(%s)", incentive.endTimestamp, GetTimestamp()))

	// r3v4_xxx: who can end incentive ??
	// require(incentive.refundee == std.GetOrigCaller(), "[STAKER] staker.gno__EndIncentive() || only refundee can end incentive")

	refund := incentive.rewardAmount

	poolOBL := obl.BalanceOf(a2u(GetOrigPkgAddr()))
	require(poolOBL >= refund, ufmt.Sprintf("[STAKER] staker.gno__EndIncentive() || not enough OBL(%s) to refund(%s)", poolOBL, refund))

	obl.Transfer(a2u(incentive.refundee), uint64(refund))

	delete(incentives, incentiveId)
	for i, v := range poolIncentives[targetPoolPath] {
		if v == incentiveId {
			poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath][:i], poolIncentives[targetPoolPath][i+1:]...)
		}
	}
}

func transferDeposit(tokenId uint64, to std.Address) {
	owner := gnft.OwnerOf(tid(tokenId))
	require(owner == GetOrigCaller(), ufmt.Sprintf("[STAKER] staker.gno__transferDeposit() || only owner(%s) can transfer tokenId(%s), GetOrigCaller()(%s)", owner, tokenId, PrevRealmAddr()))

	deposits[tokenId].owner = owner

	// transfer NFT ownership
	gnft.TransferFrom(a2u(owner), a2u(to), tid(tokenId))
}
