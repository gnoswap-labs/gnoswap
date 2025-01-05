package staker

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"

	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	u256 "gno.land/p/gnoswap/uint256"
)

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

	en.MintAndDistributeGns()

	if common.GetLimitCaller() {
		prev := std.PrevRealm()
		if err := common.UserOnly(prev); err != nil {
			panic(ufmt.Sprintf("%v: %v", errNoPermission, err))
		}
	}

	// panic if pool does not exist
	if !pl.DoesPoolPathExist(targetPoolPath) {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("targetPoolPath(%s) does not exist", targetPoolPath),
		))
	}

	// check token can be used as reward
	if err := isAllowedForExternalReward(targetPoolPath, rewardToken); err != nil {
		panic(err.Error())
	}

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
	if err := checkStartTime(startTimestamp); err != nil {
		panic(err.Error())
	}

	// endTimestamp cannot be later than 253402300799 (9999-12-31 23:59:59)
	if endTimestamp >= MAX_UNIX_EPOCH_TIME {
		panic(addDetailToError(
			errInvalidIncentiveEndTime,
			ufmt.Sprintf("staker.gno__CreateExternalIncentive() || endTimestamp(%d) cannot be later than 253402300799 (9999-12-31 23:59:59)", endTimestamp),
		))
	}

	caller := std.PrevRealm().Addr()

	// incentiveId := incentiveIdCompute(std.PrevRealm().Addr(), targetPoolPath, rewardToken, startTimestamp, endTimestamp, std.GetHeight())
	incentiveId := incentiveIdByTime(uint64(startTimestamp), uint64(endTimestamp), caller, rewardToken)

	externalDuration := uint64(endTimestamp - startTimestamp)
	if err := isValidIncentiveDuration(externalDuration); err != nil {
		panic(err.Error())
	}

	pool := pools.GetOrCreate(targetPoolPath)

	incentive := NewExternalIncentive(
		incentiveId,
		targetPoolPath,
		rewardToken,
		rewardAmount,
		startTimestamp,
		endTimestamp,
		caller,
		std.GetHeight(),
		depositGnsAmount,

		time.Now().Unix(),
		gns.GetAvgBlockTimeInMs(),
	)

	if externalIncenvies.Has(incentiveId) {
		panic(addDetailToError(
			errIncentiveAlreadyExists,
			ufmt.Sprintf("incentiveId(%s)", incentiveId),
		))
	}
	// store external incentive information for each incentiveId
	externalIncenvies.Set(incentiveId, incentive)

	// deposit gns amount
	gns.TransferFrom(a2u(caller), a2u(consts.STAKER_ADDR), depositGnsAmount)

	// transfer reward token from user to staker
	teller := common.GetTokenTeller(rewardToken)
	teller.TransferFrom(caller, consts.STAKER_ADDR, rewardAmount)

	pool.incentives.create(caller, incentive)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"CreateExternalIncentive",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", targetPoolPath,
		"rewardToken", rewardToken,
		"rewardAmount", ufmt.Sprintf("%d", rewardAmount),
		"startTimestamp", ufmt.Sprintf("%d", startTimestamp),
		"endTimestamp", ufmt.Sprintf("%d", endTimestamp),
		"internal_incentiveId", incentiveId,
		"internal_depositGnsAmount", ufmt.Sprintf("%d", depositGnsAmount),
		"internal_external", "created",
	)
}

// EndExternalIncentive ends the external incentive and refunds the remaining reward
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#endexternalincentive
func EndExternalIncentive(refundee std.Address, targetPoolPath, rewardToken string, startTimestamp, endTimestamp, height int64) {
	common.IsHalted()

	pool, exists := pools.Get(targetPoolPath)
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("staker.gno__EndExternalIncentive() || targetPoolPath(%s) does not exist", targetPoolPath),
		))
	}

	ictv, exists := pool.incentives.Get(startTimestamp, endTimestamp, refundee, rewardToken)
	if !exists {
		panic(addDetailToError(
			errCannotEndIncentive,
			ufmt.Sprintf("staker.gno__EndExternalIncentive() || cannot end non existent incentive(%d:%d:%s:%s)", startTimestamp, endTimestamp, refundee, rewardToken),
		))
	}

	now := time.Now().Unix()
	if now < ictv.endTimestamp {
		panic(addDetailToError(
			errCannotEndIncentive,
			ufmt.Sprintf("staker.gno__EndExternalIncentive() || cannot end incentive before endTimestamp(%d), current(%d)", ictv.endTimestamp, now),
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
	refund := ictv.rewardLeft

	poolLeftExternalRewardAmount := common.BalanceOf(ictv.rewardToken, consts.STAKER_ADDR)
	if poolLeftExternalRewardAmount < refund {
		refund = poolLeftExternalRewardAmount
	}

	teller := common.GetTokenTeller(ictv.rewardToken)
	teller.Transfer(ictv.refundee, refund)

	// unwrap if wugnot
	if ictv.rewardToken == consts.WUGNOT_PATH {
		unwrap(refund)
	}

	// also refund deposit gns amount
	gns.Transfer(a2u(ictv.refundee), ictv.depositGnsAmount)

	pool.incentives.remove(ictv)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"EndExternalIncentive",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", targetPoolPath,
		"rewardToken", rewardToken,
		"refundee", refundee.String(),
		"internal_endBy", ictv.refundee.String(),
		"internal_refundAmount", ufmt.Sprintf("%d", refund),
		"internal_refundGnsAmount", ufmt.Sprintf("%d", ictv.depositGnsAmount),
		"internal_incentiveId", ufmt.Sprintf("%d:%d:%s:%s", startTimestamp, endTimestamp, refundee, rewardToken),
	)
}

func isValidIncentiveDuration(dur uint64) error {
	switch dur {
	case TIMESTAMP_90DAYS, TIMESTAMP_180DAYS, TIMESTAMP_365DAYS:
		return nil
	}

	return ufmt.Errorf(
		"%v: externalDuration(%d) must be 90, 180, 365 days",
		errInvalidIncentiveDuration, dur,
	)
}

// checkStartTime checks whether the current time meets the conditions for generating an
// external rewards. Since the earliest time this reward can be generated is from
// midnight of the next day, it uses a timestamp to verify this timing.
func checkStartTime(startTimestamp int64) error {
	// must be in seconds format, not milliseconds
	// REF: https://stackoverflow.com/a/23982005
	numStr := strconv.Itoa(int(startTimestamp))
	if len(numStr) >= 13 {
		return ufmt.Errorf(
			"%v: startTimestamp(%d) must be in seconds format, not milliseconds",
			errInvalidIncentiveStartTime, startTimestamp,
		)
	}

	// must be at least +1 day midnight
	tomorrowMidnight := time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour).Unix()
	if startTimestamp < tomorrowMidnight {
		return ufmt.Errorf(
			"%v: startTimestamp(%d) must be at least +1 day midnight(%d)",
			errInvalidIncentiveStartTime, startTimestamp, tomorrowMidnight,
		)
	}

	// must be midnight of the day
	startTime := time.Unix(startTimestamp, 0)
	if !isMidnight(startTime) {
		return ufmt.Errorf(
			"%v: startTime(%d = %s) must be midnight of the day",
			errInvalidIncentiveStartTime, startTimestamp, startTime.String(),
		)
	}

	return nil
}

func isMidnight(startTime time.Time) bool {
	hour := startTime.Hour()
	minute := startTime.Minute()
	second := startTime.Second()

	return hour == 0 && minute == 0 && second == 0
}

func getTokenPairBalanceFromPosition(poolPath string, tokenId uint64) (string, string) {
	pool := pl.GetPoolFromPoolPath(poolPath)

	currentX96 := pool.Slot0SqrtPriceX96()
	lowerX96 := common.TickMathGetSqrtRatioAtTick(pn.PositionGetPositionTickLower(tokenId))
	upperX96 := common.TickMathGetSqrtRatioAtTick(pn.PositionGetPositionTickUpper(tokenId))

	token0Balance, token1Balance := common.GetAmountsForLiquidity(
		currentX96,
		lowerX96,
		upperX96,
		u256.MustFromDecimal(pn.PositionGetPositionLiquidityStr(tokenId)),
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

func isAllowedForExternalReward(poolPath, tokenPath string) error {
	token0, token1, _ := poolPathDivide(poolPath)

	if tokenPath == token0 || tokenPath == token1 {
		return nil
	}

	allowed := contains(allowedTokens, tokenPath)
	if allowed {
		return nil
	}

	return ufmt.Errorf(
		"%v: tokenPath(%s) is not allowed for external reward for poolPath(%s)",
		errNotAllowedForExternalReward, tokenPath, poolPath,
	)
}
