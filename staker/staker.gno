package staker

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/consts"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	en "gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	poolIncentives map[string][]string          = make(map[string][]string)          // poolPath => []incentiveId
	incentives     map[string]ExternalIncentive = make(map[string]ExternalIncentive) // incentiveId => ExternalIncentive

	deposits  map[uint64]Deposit      = make(map[uint64]Deposit)      // tokenId => Deposit
	poolTiers map[string]InternalTier = make(map[string]InternalTier) // poolPath -> InternalTier

	lastCalculatedHeight int64
	lastGnsBalance       uint64

	// reward amount can be left due to warm up period
	// keep track of this amount
	leftGnsBalance      uint64
	leftExternalBalance map[string]uint64 = make(map[string]uint64) // tokenPath => amount
)

const (
	TIMESTAMP_90DAYS  = 7776000
	TIMESTAMP_180DAYS = 15552000
	TIMESTAMP_365DAYS = 31536000

	MAX_UNIX_EPOCH_TIME = 253402300799 // 9999-12-31 23:59:59

	MUST_EXISTS_IN_TIER_1 = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/gns:3000"
)

func init() {
	// init pool tiers
	// tier 1
	// ONLY GNOT:GNS 0.3%
	poolTiers[MUST_EXISTS_IN_TIER_1] = InternalTier{
		tier:           1,
		startTimestamp: time.Now().Unix(),
	}
}

// StakeToken stakes the lp token to the staker contract
//
// Panics if any of the following conditions are met:
// - tokenId already staked
// - tokenId has no liquidity
// - tokenId is not owned by the caller or staker
func StakeToken(tokenId uint64) (string, string, string) { // poolPath, token0Amount, token1Amount
	en.MintAndDistributeGns()
	CalcPoolPosition()

	// check whether tokenId already staked or not
	_, exist := deposits[tokenId]
	if exist {
		panic(ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%d) already staked", tokenId))
	}

	// if caller is owner
	callerIsOwner := gnft.OwnerOf(tid(tokenId)) == std.GetOrigCaller()
	// stakerIsOwner
	stakerIsOwner := gnft.OwnerOf(tid(tokenId)) == GetOrigPkgAddr()

	if !(callerIsOwner || stakerIsOwner) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || Neither Caller(%s) or Staker(%s) is not owner of tokenId(%d)", std.GetOrigCaller(), GetOrigPkgAddr(), tokenId))
	}

	// check pool path from tokenid
	poolPath := pn.PositionGetPositionPoolKey(tokenId)

	// check tokenId has liquidity or not
	liquidity := pn.PositionGetPositionLiquidity(tokenId) // *u256.Uint
	if liquidity.Lte(u256.Zero()) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || tokenId(%d) has no liquidity", tokenId))
	}

	// staked status
	deposit := deposits[tokenId]
	deposit.owner = std.GetOrigCaller() // NOT ACTUAL OWNER, MUST BE USER ALWAYS
	deposit.numberOfStakes++
	deposit.stakeTimestamp = time.Now().Unix()
	deposit.stakeHeight = std.GetHeight()
	deposit.targetPoolPath = poolPath
	deposits[tokenId] = deposit

	if callerIsOwner { // if caller is owner, transfer NFT ownership to staker contract
		transferDeposit(tokenId, GetOrigPkgAddr())
	} else if stakerIsOwner { // if staker is owner, approve NFT to caller (≈one click staking)
		gnft.Approve(a2u(std.GetOrigCaller()), tid(tokenId))
	}

	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tokenId", uint64ToStr(tokenId),
		"poolPath", poolPath,
		"amount0", token0Amount,
		"amount1", token1Amount,
	)

	return poolPath, token0Amount, token1Amount
}

// CollectReward collects staked reward from tokenId
//
// Panics if any of the following conditions are met:
// - token is not staked
// - caller is not owner of lp token
func CollectReward(tokenId uint64) string { // poolPath
	en.MintAndDistributeGns()
	CalcPoolPosition()

	deposit, exist := deposits[tokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CollectReward() || tokenId(%d) not staked", tokenId))
	}

	if std.PrevRealm().Addr() != deposit.owner {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CollectReward() || only owner(%s) can collect reward from tokenId(%d), std.PrevRealm().Addr()(%s)", deposit.owner, tokenId, std.PrevRealm().Addr()))
	}

	poolPath := deposits[tokenId].targetPoolPath

	for k, external := range positionExternal[tokenId] {
		incentive := incentives[external.incentiveId]

		stakedOrCreatedAt := max(deposit.stakeTimestamp, incentive.startTimestamp)
		now := time.Now().Unix()
		if now < stakedOrCreatedAt {
			continue
		}

		// external reward
		duration := now - stakedOrCreatedAt/consts.BLOCK_GENERATION_INTERVAL
		durationRatio := getRewardRatio(duration)

		poolPath := external.poolPath
		tokenPath := external.tokenPath
		tokenAmount := external.tokenAmount

		if tokenAmount == 0 {
			continue
		}

		amountToGive := (tokenAmount * durationRatio) / 100
		amountLeft := tokenAmount - amountToGive

		leftExternalBalance[tokenPath] += amountLeft

		toUser := handleUnstakingFee(tokenPath, amountToGive, false)
		transferByRegisterCall(tokenPath, deposit.owner, toUser)
		if tokenPath == consts.WUGNOT_PATH { // unwrap if wugnot
			unwrap(toUser)
		}

		incentive.rewardLeft = new(u256.Uint).Sub(incentive.rewardLeft, u256.NewUint(tokenAmount))
		incentives[external.incentiveId] = incentive

		external.tokenAmountClaimed += tokenAmount
		external.tokenAmount = 0
		positionExternal[tokenId][k] = external

		std.Emit(
			"GNOSWAP",
			"m_callType", callType(),
			"m_origCaller", origCaller(),
			"m_prevRealm", prevRealm(),
			"p_tokenId", uint64ToStr(tokenId),
			"poolPath", poolPath,
			"rewardToken", tokenPath,
			"recipient", deposit.owner.String(),
			"amount", uint64ToStr(toUser),
		)
	}

	// INTERNAL gns emission
	toGive := rewardMathComputeInternalRewardAmount(tokenId)
	if toGive == 0 {
		return poolPath
	}

	toUser := handleUnstakingFee(consts.GNS_PATH, toGive, true)
	gns.Transfer(a2u(deposit.owner), toUser)

	positionGns[tokenId] = 0

	// emit internal reward tokens
	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tokenId", uint64ToStr(tokenId),
		"poolPath", poolPath,
		"rewardToken", consts.GNS_PATH,
		"recipient", deposit.owner.String(),
		"amount", uint64ToStr(toUser),
	)

	lastGnsBalance = gnsBalance(consts.STAKER_ADDR)
	return poolPath
}

// UnstakeToken unstakes the lp token from the staker and collects all reward from tokenId
//
// Panics if any of the following conditions are met:
// - token is not staked
func UnstakeToken(tokenId uint64) (string, string, string) { // poolPath, token0Amount, token1Amount
	en.MintAndDistributeGns()
	CalcPoolPosition()

	// unstaked status
	deposit, exist := deposits[tokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] staker.gno__UnstakeToken() || tokenId(%d) not staked", tokenId))
	}
	// Claim All Rewards
	CollectReward(tokenId)
	delete(positionGns, tokenId)
	delete(deposits, tokenId)

	// transfer NFT ownership to origin owner
	gnft.TransferFrom(a2u(GetOrigPkgAddr()), a2u(deposit.owner), tid(tokenId))

	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tokenId", uint64ToStr(tokenId),
		"poolPath", poolPath,
		"from", GetOrigPkgAddr().String(),
		"to", deposit.owner.String(),
		"amount0", token0Amount,
		"amount1", token1Amount,
	)

	return poolPath, token0Amount, token1Amount
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
		isUserCalled := std.PrevRealm().PkgPath() == ""
		if !isUserCalled {
			panic("[STAKER] staker.gno__CreateExternalIncentive() || only user can call this function")
		}
	}

	// check token can be used as reward
	isAllowedForExternalReward(targetPoolPath, rewardToken)

	rewardAmount := u256.MustFromDecimal(_rewardAmount)

	// native ugnot check
	if rewardToken == consts.GNOT {
		sent := std.GetOrigSend()
		ugnotSent := uint64(sent.AmountOf("ugnot"))

		if ugnotSent != rewardAmount.Uint64() {
			panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || user(%s) sent ugnot(%d) amount not equal to rewardAmount(%d)", std.GetOrigCaller(), ugnotSent, rewardAmount.Uint64()))
		}

		wrap(ugnotSent)

		rewardToken = consts.WUGNOT_PATH
	}

	// must be in seconds format, not milliseconds
	// must be at least +1 day midnight
	// must be midnight of the day
	checkStartTime(startTimestamp)

	// endTimestamp cannot be later than 253402300799 (9999-12-31 23:59:59)
	if endTimestamp >= MAX_UNIX_EPOCH_TIME {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || endTimestamp(%d) cannot be later than 253402300799 (9999-12-31 23:59:59)", endTimestamp))
	}

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

			incentive, ok := incentives[v]
			if !ok {
				return
			}

			incentive.rewardAmount = new(u256.Uint).Add(incentive.rewardAmount, rewardAmount)
			incentive.rewardLeft = new(u256.Uint).Add(incentive.rewardLeft, rewardAmount)
			incentives[v] = incentive

			std.Emit(
				"GNOSWAP",
				"m_callType", callType(),
				"m_origCaller", origCaller(),
				"m_prevRealm", prevRealm(),
				"p_poolPath", targetPoolPath,
				"p_rewardToken", rewardToken,
				"p_rewardAmount", incentive.rewardAmount.ToString(),
				"p_startTimestamp", int64ToStr(startTimestamp),
				"p_endTimestamp", int64ToStr(endTimestamp),
			)

			return
		}
	}

	transferFromByRegisterCall(rewardToken, std.GetOrigCaller(), GetOrigPkgAddr(), rewardAmount.Uint64())

	poolRewardBalanceAfter := balanceOfByRegisterCall(rewardToken, GetOrigPkgAddr())
	if !(poolRewardBalanceAfter-poolRewardBalanceBefore == rewardAmount.Uint64()) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || pool reward balance not updated correctly(before:%d, added:%d, final:%d)", poolRewardBalanceBefore, rewardAmount.Uint64(), poolRewardBalanceAfter))
	}

	incentives[incentiveId] = ExternalIncentive{
		targetPoolPath: targetPoolPath,
		rewardToken:    rewardToken,
		rewardAmount:   rewardAmount,
		rewardLeft:     rewardAmount,
		startTimestamp: startTimestamp,
		endTimestamp:   endTimestamp,
		refundee:       std.GetOrigCaller(),
	}

	poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath], incentiveId)

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_poolPath", targetPoolPath,
		"p_rewardToken", rewardToken,
		"p_rewardAmount", _rewardAmount,
		"p_startTimestamp", int64ToStr(startTimestamp),
		"p_endTimestamp", int64ToStr(endTimestamp),
	)
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
	// admin or refundee can end incentive ( left amount will be refunded )
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != refundee {
		panic(ufmt.Sprintf("[STAKER] staker.gno__EndExternalIncentive() || only refundee(%s) or admin(%s) can end incentive", refundee, consts.GNOSWAP_ADMIN))
	}

	// refundee can end incentive with refund
	refund := incentive.rewardLeft
	refundUint64 := refund.Uint64()

	poolLeftExternalRewardAmount := balanceOfByRegisterCall(incentive.rewardToken, GetOrigPkgAddr())

	if poolLeftExternalRewardAmount < refundUint64 {
		refundUint64 = poolLeftExternalRewardAmount
	}

	transferByRegisterCall(incentive.rewardToken, incentive.refundee, refundUint64)
	// unwrap if wugnot
	if incentive.rewardToken == consts.WUGNOT_PATH {
		unwrap(refundUint64)
	}

	delete(incentives, incentiveId)
	for i, v := range poolIncentives[targetPoolPath] {
		if v == incentiveId {
			poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath][:i], poolIncentives[targetPoolPath][i+1:]...)
		}
	}

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_poolPath", targetPoolPath,
		"p_rewardToken", rewardToken,
		"p_refundee", _refundee,
		"end_by", incentive.refundee.String(),
		"refund_amount", refund.ToString(),
	)
}

// TransferLeftGnsEmission transfers left gns emission to fee address
// Only admin or gov can transfer left gns emission
func TransferLeftGnsEmission() {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(ufmt.Sprintf("[STAKER] staker.gno__TransfeLeftGnsEmission() || only admin(%s) or gov(%s) can transfer left gns emission", consts.GNOSWAP_ADMIN, consts.GOV_ADDR))
	}

	stakerGns := gnsBalance(consts.STAKER_ADDR)
	if stakerGns < leftGnsBalance {
		leftGnsBalance = stakerGns
	}

	gns.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), leftGnsBalance)
	leftGnsBalance = 0
}

func checkStartTime(startTimestamp int64) {
	// must be in seconds format, not milliseconds
	// REF: https://stackoverflow.com/a/23982005
	numStr := strconv.Itoa(int(startTimestamp))
	if len(numStr) >= 13 {
		panic(ufmt.Sprintf("[STAKER] staker.gno__checkStartTime() || startTimestamp(%d) must be in seconds format, not milliseconds", startTimestamp))
	}

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
		panic(ufmt.Sprintf("[STAKER] staker.gno__checkStartTime() || startTime(%d = %s) must be midnight of the day", startTimestamp, startTime.String()))
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

func getTokenPairBalanceFromPosition(tokenId uint64) (string, string) {
	poolKey := pn.PositionGetPositionPoolKey(tokenId)

	pool := pl.GetPoolFromPoolPath(poolKey)
	currentX96 := pool.PoolGetSlot0SqrtPriceX96()
	lowerX96 := common.TickMathGetSqrtRatioAtTick(pn.PositionGetPositionTickLower(tokenId))
	upperX96 := common.TickMathGetSqrtRatioAtTick(pn.PositionGetPositionTickUpper(tokenId))

	token0Balance, token1Balance := common.GetAmountsForLiquidity(
		currentX96,
		lowerX96,
		upperX96,
		i256.FromUint256(pn.PositionGetPositionLiquidity(tokenId)),
	)

	if token0Balance == "" {
		token0Balance = "0"
	}
	if token1Balance == "" {
		token1Balance = "0"
	}

	return token0Balance, token1Balance
}

func gnsBalance(addr std.Address) uint64 {
	return gns.BalanceOf(a2u(addr))
}

func isAllowedForExternalReward(poolPath, tokenPath string) {
	token0, token1, _ := poolPathDivide(poolPath)

	if tokenPath == token0 || tokenPath == token1 {
		return
	}

	allowed := contains(allowedTokens, tokenPath)
	if allowed {
		return
	}

	panic(ufmt.Sprintf("[STAKER] staker.gno__isAllowedForExternalReward() || tokenPath(%s) is not allowed for external reward for poolPath(%s)", tokenPath, poolPath))
}
