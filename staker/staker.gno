package staker

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/avl"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

type Deposits struct {
	tree *avl.Tree
}

func NewDeposits() *Deposits {
	return &Deposits{
		tree: avl.NewTree(),
	}
}

func (self *Deposits) Get(tokenId uint64) *Deposit {
	depositI, ok := self.tree.Get(EncodeUint(tokenId))
	if !ok {
		panic(addDetailToError(	
			errDataNotFound,
			ufmt.Sprintf("staker.gno__Deposits.Get() || tokenId(%d) not found", tokenId),
		))
	}
	deposit := depositI.(*Deposit)
	return deposit
}

func (self *Deposits) Set(tokenId uint64, deposit *Deposit) {
	self.tree.Set(EncodeUint(tokenId), deposit)
}

func (self *Deposits) Has(tokenId uint64) bool {
	return self.tree.Has(EncodeUint(tokenId))
}

func (self *Deposits) Remove(tokenId uint64) {
	self.tree.Remove(EncodeUint(tokenId))
}

func (self *Deposits) Iterate(start uint64, end uint64, fn func(tokenId uint64, deposit *Deposit) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(tokenId string, depositI interface{}) bool {
		return fn(DecodeUint(tokenId), depositI.(*Deposit))
	})
}

func (self *Deposits) Size() int {
	return self.tree.Size()
}

var (
	/* common */
	// deposits stores deposit information for each tokenId
	deposits *Deposits = &Deposits{
		tree: avl.NewTree(),
	}
)

const (
	TIMESTAMP_90DAYS  = 7776000
	TIMESTAMP_180DAYS = 15552000
	TIMESTAMP_365DAYS = 31536000

	MAX_UNIX_EPOCH_TIME = 253402300799 // 9999-12-31 23:59:59

	MUST_EXISTS_IN_TIER_1 = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"
)

func init() {
	// init pool tiers
	// tier 1
	// ONLY GNOT:GNS 0.3%

	poolTier.changeTier(uint64(std.GetHeight()), MUST_EXISTS_IN_TIER_1, 1)
}

// StakeToken stakes the LP token to the staker contract
// Returns poolPath, token0Amount, token1Amount
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#staketoken
func StakeToken(tokenId uint64) (string, string, string) {
	// check whether tokenId already staked or not
	if deposits.Has(tokenId) {
		panic(addDetailToError(
			errAlreadyStaked,
			ufmt.Sprintf("staker.gno__StakeToken() || tokenId(%d) already staked", tokenId),
		))
	}

	owner := gnft.OwnerOf(tid(tokenId))

	// if caller is owner
	caller := std.PrevRealm().Addr()
	callerIsOwner := owner == caller

	// stakerIsOwner
	stakerIsOwner := owner == consts.STAKER_ADDR

	if !(callerIsOwner || stakerIsOwner) {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("staker.gno__StakeToken() || caller(%s) or staker(%s) is not owner(%s) of tokenId(%d)", caller, consts.STAKER_ADDR, owner, tokenId),
		))
	}

	// check pool path from tokenid
	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	currentHeight := uint64(std.GetHeight())
	// check if target pool doesn't have internal or external incentive then panic
	hasInternal := poolTier.IsInternallyIncentivizedPool(currentHeight, poolPath)
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(addDetailToError(
			errNonIncentivizedPool,
			ufmt.Sprintf("staker.gno__StakeToken() || can not stake position to non incentivized pool(%s)", poolPath),
		))
	}
	hasExternal := pool.IsExternallyIncentivizedPool(uint64(std.GetHeight()))
	if hasInternal == false && hasExternal == false {
		panic(addDetailToError(
			errNonIncentivizedPool,
			ufmt.Sprintf("staker.gno__StakeToken() || can not stake position to non incentivized pool(%s)", poolPath),
		))
	}

	// check tokenId has liquidity or not
	liqStr := pn.PositionGetPositionLiquidityStr(tokenId)
	liquidity := u256.MustFromDecimal(liqStr)
	if liquidity.Lte(u256.Zero()) {
		panic(addDetailToError(
			errZeroLiquidity,
			ufmt.Sprintf("staker.gno__StakeToken() || tokenId(%d) has no liquidity", tokenId),
		))
	}



	// staked status
	deposit := &Deposit{
		owner:          std.PrevRealm().Addr(),
		stakeTimestamp: time.Now().Unix(),
		stakeHeight:    std.GetHeight(),

		targetPoolPath: poolPath,
		tickLower:      pn.PositionGetPositionTickLower(tokenId),
		tickUpper:      pn.PositionGetPositionTickUpper(tokenId),
		liquidity:      liquidity,

		lastCollectHeight: currentHeight,
	}
	deposits.Set(tokenId, deposit)

	if callerIsOwner { // if caller is owner, transfer NFT ownership to staker contract
		transferDeposit(tokenId, consts.STAKER_ADDR)
	}

	// after transfer, set caller(user) as position operator (to collect fee and reward)
	pn.SetPositionOperator(tokenId, caller)

	signedLiquidity := i256.FromUint256(liquidity)
	currentTick := pl.PoolGetSlot0Tick(poolPath)

	if pn.PositionIsInRange(tokenId) {
		pool.modifyDeposit(tokenId, signedLiquidity, uint64(std.GetHeight()))
	}

	ticks.Get(deposit.tickLower).modifyDepositLower(currentHeight, currentTick, signedLiquidity)
	ticks.Get(deposit.tickUpper).modifyDepositUpper(currentHeight, currentTick, signedLiquidity)

	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"StakeToken",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"internal_poolPath", poolPath,
		"internal_amount0", token0Amount,
		"internal_amount1", token1Amount,
	)

	// positionsInternalWarmUpAmount[tokenId] = warmUpAmount{}
	return poolPath, token0Amount, token1Amount
}

// CollectReward collects staked rewards for the given tokenId
// Returns poolPath
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#collectreward
func CollectReward(tokenId uint64, unwrapResult bool) string {
	common.IsHalted()

	deposit := deposits.Get(tokenId)

	caller := std.PrevRealm().Addr()
	if caller != deposit.owner {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("staker.gno__CollectReward() || only owner(%s) can collect reward from tokenId(%d), called from %s", deposit.owner, tokenId, caller),
		))
	}

	poolPath := deposit.targetPoolPath

	// prevAddr, prevRealm := getPrev()
/*
	_, exist = positionExternal[tokenId]
	if exist {
		for _, external := range positionExternal[tokenId] {
			incentive := incentives[external.incentiveId]
			incentiveId := external.incentiveId

			externalWarmUpAmount, exist := positionsExternalWarmUpAmount[tokenId][incentiveId]
			if !exist {
				continue
			}
			fullAmount := externalWarmUpAmount.full30 + externalWarmUpAmount.full50 + externalWarmUpAmount.full70 + externalWarmUpAmount.full100
			toGive := externalWarmUpAmount.give30 + externalWarmUpAmount.give50 + externalWarmUpAmount.give70 + externalWarmUpAmount.full100

			if toGive == 0 {
				continue
			}

			_this := positionExternal[tokenId][incentiveId]
			_this.tokenAmountX96 = u256.Zero()
			_this.tokenAmountFull += fullAmount
			_this.tokenAmountToGive += toGive
			positionExternal[tokenId][incentiveId] = _this

			toUser := handleUnstakingFee(external.tokenPath, toGive, false, tokenId, incentive.targetPoolPath)

			transferByRegisterCall(external.tokenPath, deposit.owner, toUser)
			if external.tokenPath == consts.WUGNOT_PATH && unwrapResult {
				unwrap(toUser)
			}

			positionsExternalWarmUpAmount[tokenId][incentiveId] = warmUpAmount{} // JUST CLEAR
			positionLastExternal[tokenId][incentiveId] = u256.Zero()             // JUST CLEAR

			left := fullAmount - toGive
			transferByRegisterCall(external.tokenPath, consts.PROTOCOL_FEE_ADDR, left)

			std.Emit(
				"ProtocolFeeExternalPenalty",
				"prevAddr", prevAddr,
				"prevRealm", prevRealm,
				"lpTokenId", ufmt.Sprintf("%d", tokenId),
				"internal_poolPath", poolPath,
				"internal_incentiveId", incentiveId,
				"internal_tokenPath", external.tokenPath,
				"internal_amount", ufmt.Sprintf("%d", left),
			)

			incentive.rewardLeft = new(u256.Uint).Sub(incentive.rewardLeft, u256.NewUint(fullAmount))
			incentives[incentiveId] = incentive

			if external.tokenPath == consts.GNS_PATH {
				externalGns[incentiveId] -= fullAmount
			}

			std.Emit(
				"CollectRewardExternal",
				"prevAddr", prevAddr,
				"prevRealm", prevRealm,
				"lpTokenId", ufmt.Sprintf("%d", tokenId),
				"internal_poolPath", poolPath,
				"internal_incentiveId", incentiveId,
				"internal_rewardToken", external.tokenPath,
				"internal_recipient", deposit.owner.String(),
				"internal_amount", ufmt.Sprintf("%d", toUser),
				"internal_unwrapResult", ufmt.Sprintf("%t", unwrapResult),
			)
		}
	}

	// INTERNAL gns emission
	internalWarmUpAmount, exist := positionsInternalWarmUpAmount[tokenId]
	if !exist {
		return poolPath
	}
	fullAmount := internalWarmUpAmount.full30 + internalWarmUpAmount.full50 + internalWarmUpAmount.full70 + internalWarmUpAmount.full100
	toGive := internalWarmUpAmount.give30 + internalWarmUpAmount.give50 + internalWarmUpAmount.give70 + internalWarmUpAmount.full100

	if toGive == 0 {
		return poolPath
	}
	toUser := handleUnstakingFee(consts.GNS_PATH, toGive, true, tokenId, poolPath)
	gns.Transfer(a2u(deposit.owner), toUser)

	// delete(positionsInternalWarmUpAmount, tokenId) // DO NOT DELETE
	positionsInternalWarmUpAmount[tokenId] = warmUpAmount{} // JUST CLEAR

	poolGns[poolPath] -= fullAmount

	left := fullAmount - toGive
	gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), left)
	std.Emit(
		"CommunityPoolEmissionPenalty",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"internal_poolPath", poolPath,
		"internal_incentiveId", "INTERNAL",
		"internal_tokenPath", consts.GNS_PATH,
		"internal_amount", ufmt.Sprintf("%d", left),
	)

	std.Emit(
		"CollectRewardEmission",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"internal_poolPath", poolPath,
		"internal_incentiveId", "INTERNAL",
		"internal_rewardToken", consts.GNS_PATH,
		"internal_recipient", deposit.owner.String(),
		"internal_fullAmount", ufmt.Sprintf("%d", fullAmount),
		"internal_toGive", ufmt.Sprintf("%d", toGive),
		"internal_amount", ufmt.Sprintf("%d", toUser),
		"internal_unstakingFee", ufmt.Sprintf("%d", toGive-toUser),
		"internal_left", ufmt.Sprintf("%d", left),
	)

	// UPDATE stakerGns Balance for calculate_pool_position_reward
	lastCalculatedBalance = gnsBalance(consts.STAKER_ADDR) - externalGnsAmount() - externalDepositGnsAmount()
*/
	return poolPath
}

// UnstakeToken unstakes the LP token from the staker and collects all reward from tokenId
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#unstaketoken
func UnstakeToken(tokenId uint64, unwrapResult bool) (string, string, string) { // poolPath, token0Amount, token1Amount
	common.IsHalted()

	// unstaked status
	deposit := deposits.Get(tokenId)

	// Claim All Rewards
	CollectReward(tokenId, unwrapResult)

	deposits.Remove(tokenId)

	// transfer NFT ownership to origin owner
	gnft.TransferFrom(a2u(consts.STAKER_ADDR), a2u(deposit.owner), tid(tokenId))
	pn.SetPositionOperator(tokenId, consts.ZERO_ADDRESS)

	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)

	signedLiquidity := i256.FromUint256(deposit.liquidity)
	signedLiquidity = signedLiquidity.Neg(signedLiquidity)

	currentHeight := uint64(std.GetHeight())
	currentTick := pl.PoolGetSlot0Tick(poolPath)

	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("staker.gno__UnstakeToken() || pool(%s) does not exist", poolPath),
		))
	}
	if pn.PositionIsInRange(tokenId) {
		pool.modifyDeposit(tokenId, signedLiquidity, currentHeight)
	}
	ticks.Get(deposit.tickLower).modifyDepositLower(currentHeight, currentTick, signedLiquidity)
	ticks.Get(deposit.tickUpper).modifyDepositUpper(currentHeight, currentTick, signedLiquidity)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"UnstakeToken",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"unwrapResult", ufmt.Sprintf("%t", unwrapResult),
		"internal_poolPath", poolPath,
		"internal_from", GetOrigPkgAddr().String(),
		"internal_to", deposit.owner.String(),
		"internal_amount0", token0Amount,
		"internal_amount1", token1Amount,
	)

	return poolPath, token0Amount, token1Amount
}

// CreateExternalIncentive creates an incentive program for a pool.
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#createexternalincentive
func CreateExternalIncentive(
	targetPoolPath string,
	rewardToken string, // token path should be registered
	rewardAmount uint64,
	startTimestamp int64,
	endTimestamp int64,
) {
	common.IsHalted()
	if common.GetLimitCaller() {
		prev := std.PrevRealm()
		if !prev.IsUser() {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("staker.gno__CreateExternalIncentive() || only user can call this function, but called from %s", prev.PkgPath()),
			))
		}
	}

	// panic if pool does not exist
	if !(pl.DoesPoolPathExist(targetPoolPath)) {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("staker.gno__CreateExternalIncentive() || targetPoolPath(%s) does not exist", targetPoolPath),
		))
	}

	// check token can be used as reward
	isAllowedForExternalReward(targetPoolPath, rewardToken)

	// native ugnot check
	if rewardToken == consts.GNOT {
		sent := std.GetOrigSend()
		ugnotSent := uint64(sent.AmountOf("ugnot"))

		if ugnotSent != rewardAmount {
			panic(addDetailToError(
				errInvalidInput,
				ufmt.Sprintf("staker.gno__CreateExternalIncentive() || user(%s) sent ugnot(%d) amount not equal to rewardAmount(%d)", std.PrevRealm().Addr(), ugnotSent, rewardAmount),
			))
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
		panic(addDetailToError(
			errInvalidIncentiveEndTime,
			ufmt.Sprintf("staker.gno__CreateExternalIncentive() || endTimestamp(%d) cannot be later than 253402300799 (9999-12-31 23:59:59)", endTimestamp),
		))
	}

	externalDuration := uint64(endTimestamp - startTimestamp)
	if !(externalDuration == TIMESTAMP_90DAYS || externalDuration == TIMESTAMP_180DAYS || externalDuration == TIMESTAMP_365DAYS) {
		panic(addDetailToError(
			errInvalidIncentiveDuration,
			ufmt.Sprintf("staker.gno__CreateExternalIncentive() || externalDuration(%d) must be 90, 180, 365 days", externalDuration),
		))
	}

	// external deposit amount
	gns.TransferFrom(a2u(std.PrevRealm().Addr()), a2u(GetOrigPkgAddr()), depositGnsAmount)

	// external reward amount
	transferFromByRegisterCall(rewardToken, std.PrevRealm().Addr(), GetOrigPkgAddr(), rewardAmount)


	incentive := NewExternalIncentive(
		targetPoolPath,
		rewardToken,
		rewardAmount,
		startTimestamp,
		endTimestamp,
		std.PrevRealm().Addr(),
		std.GetHeight(),
		depositGnsAmount,
	
		gns.GetAvgBlockTimeInMs(),
		time.Now().Unix(),
	)

	pool := pools.GetOrCreate(targetPoolPath)
	pool.incentives.add(std.PrevRealm().Addr(), incentive)


	prevAddr, prevRealm := getPrev()
	std.Emit(
		"CreateExternalIncentive",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", targetPoolPath,
		"rewardToken", rewardToken,
		"rewardAmount", ufmt.Sprintf("%d", incentive.rewardAmount),
		"startTimestamp", ufmt.Sprintf("%d", startTimestamp),
		"endTimestamp", ufmt.Sprintf("%d", endTimestamp),
		"internal_depositGnsAmount", ufmt.Sprintf("%d", incentive.depositGnsAmount),
		"internal_external", "updated",
	)

	return
}

// EndExternalIncentive ends the external incentive and refunds the remaining reward
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#endexternalincentive
func EndExternalIncentive(refundee std.Address, targetPoolPath, rewardToken string, startTimestamp, endTimestamp, height int64) {
	common.IsHalted()

	pool, ok := pools.Get(targetPoolPath)
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("staker.gno__EndExternalIncentive() || pool(%s) does not exist", targetPoolPath),
		))
	}

	incentive := pool.incentives.Get(startTimestamp, endTimestamp, refundee, rewardToken)
	if incentive == nil {
		panic(addDetailToError(
			errCannotEndIncentive,
			ufmt.Sprintf("staker.gno__EndExternalIncentive() || cannot end non existent incentive(%d:%d:%s:%s)", startTimestamp, endTimestamp, refundee, rewardToken),
		))
	}

	if std.GetHeight() < incentive.endHeight {
		panic(addDetailToError(
			errCannotEndIncentive,
			ufmt.Sprintf("staker.gno__EndExternalIncentive() || cannot end incentive before endHeight(%d) of endTimestamp(%d), currentHeight(%d) of currentTimestamp(%d)", incentive.endHeight, incentive.endTimestamp, std.GetHeight(), time.Now().Unix()),
		))
	}

	// when incentive end time is over
	// admin or refundee can end incentive ( left amount will be refunded )
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN && caller != refundee {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("staker.gno__EndExternalIncentive() || only refundee(%s) or admin(%s) can end incentive, but called from %s", refundee, consts.ADMIN, caller),
		))
	}

	// when incentive ended, refund remaining reward
	refund := pool.incentives.claimPenalty()

	poolLeftExternalRewardAmount := balanceOfByRegisterCall(incentive.rewardToken, GetOrigPkgAddr())
	if poolLeftExternalRewardAmount < refund {
		refund = poolLeftExternalRewardAmount
	}

	transferByRegisterCall(incentive.rewardToken, incentive.refundee, refund)
	// unwrap if wugnot
	if incentive.rewardToken == consts.WUGNOT_PATH {
		unwrap(refund)
	}

	// also refund deposit gns amount
	gns.Transfer(a2u(incentive.refundee), incentive.depositGnsAmount)

	pool.incentives.remove(incentive)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"EndExternalIncentive",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", targetPoolPath,
		"rewardToken", rewardToken,
		"refundee", refundee.String(),
		"internal_endBy", incentive.refundee.String(),
		"internal_refundAmount", ufmt.Sprintf("%d", refund),
		"internal_refundGnsAmount", ufmt.Sprintf("%d", incentive.depositGnsAmount),
	)
}

func checkStartTime(startTimestamp int64) {
	// must be in seconds format, not milliseconds
	// REF: https://stackoverflow.com/a/23982005
	numStr := strconv.Itoa(int(startTimestamp))
	if len(numStr) >= 13 {
		panic(addDetailToError(
			errInvalidIncentiveStartTime,
			ufmt.Sprintf("staker.gno__checkStartTime() || startTimestamp(%d) must be in seconds format, not milliseconds", startTimestamp),
		))
	}

	// must be at least +1 day midnight
	tomorrowMidnight := time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour).Unix()
	if startTimestamp < tomorrowMidnight {
		panic(addDetailToError(
			errInvalidIncentiveStartTime,
			ufmt.Sprintf("staker.gno__checkStartTime() || startTimestamp(%d) must be at least +1 day midnight(%d)", startTimestamp, tomorrowMidnight),
		))
	}

	// must be midnight of the day
	startTime := time.Unix(startTimestamp, 0)
	hour, minute, second := startTime.Hour(), startTime.Minute(), startTime.Second()

	isMidnight := hour == 0 && minute == 0 && second == 0
	if !isMidnight {
		panic(addDetailToError(
			errInvalidIncentiveStartTime,
			ufmt.Sprintf("staker.gno__checkStartTime() || startTime(%d = %s) must be midnight of the day", startTimestamp, startTime.String()),
		))
	}
}

func transferDeposit(tokenId uint64, to std.Address) {
	owner := gnft.OwnerOf(tid(tokenId))
	caller := std.PrevRealm().Addr()
	if caller == to {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("staker.gno__transferDeposit() || only owner(%s) can transfer tokenId(%d), called from %s", owner, tokenId, caller),
		))
	}

	// transfer NFT ownership
	gnft.TransferFrom(a2u(owner), a2u(to), tid(tokenId))
}

func getTokenPairBalanceFromPosition(tokenId uint64) (string, string) {
	poolKey := pn.PositionGetPositionPoolKey(tokenId)

	pool := pl.GetPoolFromPoolPath(poolKey)
	currentX96 := pool.Slot0SqrtPriceX96()
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

	panic(addDetailToError(
		errNotAllowedForExternalReward,
		ufmt.Sprintf("staker.gno__isAllowedForExternalReward() || tokenPath(%s) is not allowed for external reward for poolPath(%s)", tokenPath, poolPath),
	))
}
/*
func poolHasInternal(poolPath string) bool {
	_, exist := poolTiers[poolPath]
	return exist
}

func poolHasExternal(poolPath string) bool {
	_, exist := poolIncentives[poolPath]
	return exist
}

func getPoolTiers() map[string]InternalTier {
	return poolTiers
}

// getDeposits returns deposit information for the given tokenId
func getDepositsByTokenId(tokenId uint64) Deposit {
	return deposits[tokenId]
}

// getDeposits returns deposit information for all tokenIds
func getDeposits() map[uint64]Deposit {
	return deposits
}

func getIncentives() map[string]ExternalIncentive {
	return incentives
}

func getPoolIncentives() map[string][]string {
	return poolIncentives
}*/
