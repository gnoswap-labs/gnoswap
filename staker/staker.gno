package staker

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gnft"
	"gno.land/r/gnoswap/v2/gns"

	en "gno.land/r/gnoswap/v2/emission"
	pl "gno.land/r/gnoswap/v2/pool"
	pn "gno.land/r/gnoswap/v2/position"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	/* internal */

	// poolTiers stores internal tier information for each pool
	poolTiers map[string]InternalTier = make(map[string]InternalTier)

	/* external */

	// poolIncentives maps pool paths to their associated incentive IDs
	poolIncentives map[string][]string = make(map[string][]string)

	// incentives stores external incentive for each incentive ID
	incentives map[string]ExternalIncentive = make(map[string]ExternalIncentive)

	// deposits stores deposit information for each tokenId
	deposits map[uint64]Deposit = make(map[uint64]Deposit)
)

const (
	TIMESTAMP_90DAYS  = 7776000
	TIMESTAMP_180DAYS = 15552000
	TIMESTAMP_365DAYS = 31536000

	MAX_UNIX_EPOCH_TIME = 253402300799 // 9999-12-31 23:59:59

	MUST_EXISTS_IN_TIER_1 = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:3000"
)

func init() {
	// init pool tiers
	// tier 1
	// ONLY GNOT:GNS 0.3%
	poolTiers[MUST_EXISTS_IN_TIER_1] = InternalTier{
		tier:           1,
		startTimestamp: time.Now().Unix(),
		startHeight:    std.GetHeight(),
		updateHeight:   std.GetHeight(),
	}
}

// StakeToken stakes the LP token to the staker contract
//
// Parameters:
//   - tokenID (uint64): The ID of the LP token to stake
//
// Returnes:
//   - poolPath     (string): The path of the pool associated with the staked token
//   - token0Amount (string): The amount of token0 in the position
//   - token1Amount (string): The amount of token1 in the position
//
// Panics:
//   - tokenId already staked
//   - tokenId has no liquidity
//   - tokenId is not owned by the caller or staker
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

	// check if target pool doesn't have internal or external incentive then panic
	hasInternal := poolHasInternal(poolPath)
	hasExternal := poolHasExternal(poolPath)
	if hasInternal == false && hasExternal == false {
		panic(ufmt.Sprintf("[STAKER] staker.gno__StakeToken() || poolPath(%s) has no internal or external incentive(can not stake)", poolPath))
	}

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

	positionsInternalWarmUpAmount[tokenId] = warmUpAmount{}
	return poolPath, token0Amount, token1Amount
}

// CollectReward collects staked rewards for the given tokenId
//
// Parameters:
//   - tokenId (uint64): The ID of the LP token to collect rewards for
//
// Returns:
//   - poolPath (string): The path of the pool associated with the collected rewards
//
// Panics:
//   - token is not staked
//   - caller is not owner of lp token
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

	println("[ START ] CollectReward_EXTERNAL", tokenId)

	_, exist = positionExternal[tokenId]
	if exist {
		for _, external := range positionExternal[tokenId] {
			incentive := incentives[external.incentiveId]
			incentiveId := external.incentiveId

			println(" > CollectReward_EXTERNAL_START")
			println("  > tokenId:", tokenId)
			println("  > incentiveId:", incentiveId)
			println("  > rewardToken:", external.tokenPath)

			fullAmount, toGive := rewardMathComputeExternalRewardAmount(tokenId, incentiveId)
			println("  > position fullAmount(rewardMathComputeExternal)", fullAmount)
			println("  > position toGive(rewardMathComputeExternal)", toGive)

			if toGive == 0 {
				continue
			}

			_this := positionExternal[tokenId][incentiveId]
			_this.tokenAmountX96 = u256.Zero()
			_this.tokenAmountFull += fullAmount
			_this.tokenAmountActualFull += toGive
			positionExternal[tokenId][incentiveId] = _this

			toUser := handleUnstakingFee(external.tokenPath, toGive, false, tokenId, incentive.targetPoolPath)
			println("  > position toUser(after staking fee)", toUser)
			println("  > unstakingFee", toGive-toUser)
			transferByRegisterCall(external.tokenPath, deposit.owner, toUser)
			println("  > toAddr:", deposit.owner)
			println("  > toUser:", toUser)

			positionsExternalWarmUpAmount[tokenId][incentiveId] = warmUpAmount{} // JUST CLEAR
			positionLastExternal[tokenId][incentiveId] = u256.Zero()             // JUST CLEAR

			left := fullAmount - toGive
			println("  > warm up left := fullAmount - toGive (to protocol_fee)", left)
			transferByRegisterCall(external.tokenPath, consts.PROTOCOL_FEE_ADDR, left)
			std.Emit(
				"GNOSWAP_PROTOCOL_FEE",
				"m_callType", callType(),
				"m_origCaller", origCaller(),
				"m_prevRealm", prevRealm(),
				"lpTokenId", uint64ToStr(tokenId),
				"poolPath", poolPath,
				"reason", "unstaking_fee_penalty",
				"token", external.tokenPath,
				"amount", strconv.FormatUint(left, 10),
			)

			incentive.rewardLeft = new(u256.Uint).Sub(incentive.rewardLeft, u256.NewUint(fullAmount))
			incentives[incentiveId] = incentive

			if external.tokenPath == consts.GNS_PATH {
				externalGns[incentiveId] -= fullAmount
			}

			std.Emit(
				"GNOSWAP",
				"m_callType", callType(),
				"m_origCaller", origCaller(),
				"m_prevRealm", prevRealm(),
				"p_tokenId", uint64ToStr(tokenId),
				"poolPath", poolPath,
				"rewardToken", external.tokenPath,
				"recipient", deposit.owner.String(),
				"amount", uint64ToStr(toUser),
			)
		}
	}
	println("[ END ] CollectReward_EXTERNAL", tokenId)
	println()

	// INTERNAL gns emission
	println("[ START ] CollectReward_INTERNAL", tokenId)
	fullAmount, toGive := rewardMathComputeInternalRewardAmount(tokenId)
	println(" > position fullAmount(rewardMathComputeInternal)", fullAmount)
	println(" > position toGive(rewardMathComputeInternal)", toGive)
	if toGive == 0 {
		return poolPath
	}
	toUser := handleUnstakingFee(consts.GNS_PATH, toGive, true, tokenId, poolPath)
	println(" > position toUser(after staking fee)", toUser)
	println(" > unstakingFee", toGive-toUser)
	gns.Transfer(a2u(deposit.owner), toUser)

	println(" > clear positionGns[tokenId] = 0")
	// positionGns[tokenId] = 0

	// delete(positionsInternalWarmUpAmount, tokenId) // DO NOT DELETE
	positionsInternalWarmUpAmount[tokenId] = warmUpAmount{} // JUST CLEAR

	println(" > poolGns[poolPath]", poolGns[poolPath])
	println(" > position fullAmount", fullAmount)

	poolGns[poolPath] -= fullAmount
	println(" > poolGns[poolPath] - fullAmount", poolGns[poolPath])

	left := fullAmount - toGive
	println(" > warm up left := fullAmount - toGive (to protocol_fee)", left)
	gns.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), left)
	std.Emit(
		"GNOSWAP_PROTOCOL_FEE",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"lpTokenId", uint64ToStr(tokenId),
		"poolPath", poolPath,
		"reason", "gns_penalty",
		"token", consts.GNS_PATH,
		"amount", strconv.FormatUint(left, 10),
	)

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
		"fullAmount", uint64ToStr(fullAmount),
		"toGive", uint64ToStr(toGive),
		"amount", uint64ToStr(toUser),
		"unstakingFee", uint64ToStr(toGive-toUser),
		"left", uint64ToStr(left),
	)

	// DEBUG
	println(" > fullAmount", fullAmount)
	println(" > toGive", toGive)
	println(" > toUser", toUser)
	println(" > unstakingFee", toGive-toUser)
	println(" > left", left)

	// UPDATE stakerGns Balance for calculate_pool_position_reward
	lastCalculatedBalance = gnsBalance(consts.STAKER_ADDR) - externalGnsAmount()

	println("[ END ] CollectReward_INTERNAL", tokenId)
	return poolPath
}

// UnstakeToken unstakes the LP token from the staker and collects all reward from tokenId
//
// Parameters:
//   - tokenId (uint64): The ID of the LP token to unstake
//
// Returns:
//   - poolPath     (string): The path of the pool associated with the unstaked token
//   - token0Amount (string): The amount of token0 in the unstaked position
//   - token1Amount (string): The amount of token1 in the unstaked position
//
// Panics:
//   - If the token is not staked
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
	delete(positionsInternalWarmUpAmount, tokenId)

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
// Parameters:
//   - targetPoolPath (string): The path of the pool to create the incentive for
//   - rewardToken    (string): The token path of the reward token (must be registered)
//   - _rewardAmount  (string): The amount of reward token to provide as incentive
//   - startTimestamp (int64): The start timestamp of the incentive
//   - endTimestamp   (int64): The end timestamp of the incentive
//
// Panics:
//   - If startTimestamp is not in the future
//   - If externalDuration is not 90, 180, or 365 days
//   - If user doesn't have enough balance to provide as reward
func CreateExternalIncentive(
	targetPoolPath string,
	rewardToken string, // token path should be registered
	_rewardAmount string,
	startTimestamp int64,
	endTimestamp int64,
) {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	if common.GetLimitCaller() {
		isUserCalled := std.PrevRealm().PkgPath() == ""
		if !isUserCalled {
			panic("[STAKER] staker.gno__CreateExternalIncentive() || only user can call this function")
		}
	}

	// panic if pool does not exist
	if !(pl.DoesPoolPathExist(targetPoolPath)) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || targetPoolPath(%s) does not exist", targetPoolPath))
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

	incentiveId := incentiveIdCompute(std.GetOrigCaller(), targetPoolPath, rewardToken, startTimestamp, endTimestamp, std.GetHeight())

	// if same incentiveId exists => increase rewardTokenAmount
	for _, v := range poolIncentives[targetPoolPath] {
		if v == incentiveId {
			transferFromByRegisterCall(rewardToken, std.GetOrigCaller(), GetOrigPkgAddr(), rewardAmount.Uint64())

			incentive, ok := incentives[v]
			if !ok {
				return
			}

			incentiveDuration := endTimestamp - startTimestamp
			incentiveBlock := incentiveDuration / consts.BLOCK_GENERATION_INTERVAL
			rewardAmountX96 := new(u256.Uint).Mul(rewardAmount, u256.MustFromDecimal(consts.Q96))
			rewardPerBlockX96 := new(u256.Uint).Div(rewardAmountX96, u256.NewUint(uint64(incentiveBlock)))
			incentive.rewardPerBlockX96 = rewardPerBlockX96

			incentive.rewardAmount = new(u256.Uint).Add(incentive.rewardAmount, rewardAmount)
			incentive.rewardLeft = new(u256.Uint).Add(incentive.rewardLeft, rewardAmount)
			incentives[v] = incentive

			if rewardToken == consts.GNS_PATH {
				externalGns[incentiveId] = incentive.rewardAmount.Uint64()
			}

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
				"incentiveId", incentiveId,
				"external", "updated",
			)

			return
		}
	}

	transferFromByRegisterCall(rewardToken, std.GetOrigCaller(), GetOrigPkgAddr(), rewardAmount.Uint64())

	poolRewardBalanceAfter := balanceOfByRegisterCall(rewardToken, GetOrigPkgAddr())
	if !(poolRewardBalanceAfter-poolRewardBalanceBefore == rewardAmount.Uint64()) {
		panic(ufmt.Sprintf("[STAKER] staker.gno__CreateExternalIncentive() || pool reward balance not updated correctly(before:%d, added:%d, final:%d)", poolRewardBalanceBefore, rewardAmount.Uint64(), poolRewardBalanceAfter))
	}

	incentiveDuration := endTimestamp - startTimestamp
	incentiveBlock := incentiveDuration / consts.BLOCK_GENERATION_INTERVAL
	rewardAmountX96 := new(u256.Uint).Mul(rewardAmount, u256.MustFromDecimal(consts.Q96))
	rewardPerBlockX96 := new(u256.Uint).Div(rewardAmountX96, u256.NewUint(uint64(incentiveBlock)))

	incentives[incentiveId] = ExternalIncentive{
		targetPoolPath:    targetPoolPath,
		rewardToken:       rewardToken,
		rewardAmount:      rewardAmount,
		rewardLeft:        rewardAmount,
		startTimestamp:    startTimestamp,
		endTimestamp:      endTimestamp,
		rewardPerBlockX96: rewardPerBlockX96,
		refundee:          std.GetOrigCaller(),
		createdHeight:     std.GetHeight(),
	}

	poolIncentives[targetPoolPath] = append(poolIncentives[targetPoolPath], incentiveId)

	externalLastCalculatedTimestamp[incentiveId] = time.Now().Unix()

	if rewardToken == consts.GNS_PATH {
		externalGns[incentiveId] = rewardAmount.Uint64()
	}

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
		"incentiveId", incentiveId,
		"external", "created",
	)
}

// EndExternalIncentive ends the external incentive and refunds the remaining reward
//
// Parameters:
//   - _refundee	     (string): The address of the refundee
//   - targetPoolPath (string): The path of the pool associated with the incentive
//   - rewardToken    (string): The token path of the reward token
//   - startTimestamp (int64): The start timestamp of the incentive
//   - endTimestamp   (int64): The end timestamp of the incentive
//   - height         (int64): The height of the block when the incentive was created
//
// Panics:
//   - If incentive expiration time is not over
//   - If reward token amount is not enough to refund
//   - If the caller is neither the refundee nor the admin
func EndExternalIncentive(_refundee, targetPoolPath, rewardToken string, startTimestamp, endTimestamp, height int64) {
	refundee := std.Address(_refundee)

	incentiveId := incentiveIdCompute(refundee, targetPoolPath, rewardToken, startTimestamp, endTimestamp, height)

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

func poolHasInternal(poolPath string) bool {
	_, exist := poolTiers[poolPath]
	return exist
}

func poolHasExternal(poolPath string) bool {
	_, exist := poolIncentives[poolPath]
	return exist
}
