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

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// CreateExternalIncentive creates an incentive program for a pool.
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#createexternalincentive
func CreateExternalIncentive(
	targetPoolPath string,
	rewardToken string, // token path should be registered
	_rewardAmount string,
	startTimestamp int64,
	endTimestamp int64,
) {
	common.IsHalted()

	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

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
		panic(err)
	}

	rewardAmount := u256.MustFromDecimal(_rewardAmount)

	// native ugnot check
	if rewardToken == consts.GNOT {
		sent := std.GetOrigSend()
		ugnotSent := uint64(sent.AmountOf("ugnot"))

		if ugnotSent != rewardAmount.Uint64() {
			panic(addDetailToError(
				errInvalidInput,
				ufmt.Sprintf("staker.gno__CreateExternalIncentive() || user(%s) sent ugnot(%d) amount not equal to rewardAmount(%d)", std.PrevRealm().Addr(), ugnotSent, rewardAmount.Uint64()),
			))
		}

		wrap(ugnotSent)

		rewardToken = consts.WUGNOT_PATH
	}

	// must be in seconds format, not milliseconds
	// must be at least +1 day midnight
	// must be midnight of the day
	if err := checkStartTime(startTimestamp); err != nil {
		panic(err)
	}

	// endTimestamp cannot be later than 253402300799 (9999-12-31 23:59:59)
	if endTimestamp >= MAX_UNIX_EPOCH_TIME {
		panic(addDetailToError(
			errInvalidIncentiveEndTime,
			ufmt.Sprintf("staker.gno__CreateExternalIncentive() || endTimestamp(%d) cannot be later than 253402300799 (9999-12-31 23:59:59)", endTimestamp),
		))
	}

	incentiveId := incentiveIdCompute(std.PrevRealm().Addr(), targetPoolPath, rewardToken, startTimestamp, endTimestamp, std.GetHeight())

	externalDuration := uint64(endTimestamp - startTimestamp)
	if err := isValidIncentiveDuration(externalDuration); err != nil {
		panic(err)
	}

	// if same incentiveId exists => increase rewardTokenAmount
	for _, v := range poolIncentives[targetPoolPath] {
		if v == incentiveId {
			// external deposit amount
			gns.TransferFrom(a2u(std.PrevRealm().Addr()), a2u(GetOrigPkgAddr()), depositGnsAmount)

			// external reward amount
			transferFromByRegisterCall(rewardToken, std.PrevRealm().Addr(), GetOrigPkgAddr(), rewardAmount.Uint64())

			// incentive, ok := incentives[v]
			ictv, exists := incentives.Get(v)
			if !exists {
				return
			}

			incentiveDuration := endTimestamp - startTimestamp
			incentiveBlock := incentiveDuration / consts.BLOCK_GENERATION_INTERVAL

			ictv.rewardAmount = new(u256.Uint).Add(ictv.rewardAmount, rewardAmount)
			ictv.rewardLeft = new(u256.Uint).Add(ictv.rewardLeft, rewardAmount)

			rewardAmountX96 := new(u256.Uint).Mul(ictv.rewardAmount, u256.MustFromDecimal(consts.Q96))
			rewardPerBlockX96 := new(u256.Uint).Div(rewardAmountX96, u256.NewUint(uint64(incentiveBlock)))

			ictv.rewardPerBlockX96 = rewardPerBlockX96

			ictv.depositGnsAmount += depositGnsAmount
			incentives.Set(v, ictv)

			if rewardToken == consts.GNS_PATH {
				externalGns[incentiveId] = ictv.rewardAmount.Uint64()
			}

			prevAddr, prevRealm := getPrev()
			std.Emit(
				"CreateExternalIncentive",
				"prevAddr", prevAddr,
				"prevRealm", prevRealm,
				"poolPath", targetPoolPath,
				"rewardToken", rewardToken,
				"rewardAmount", ictv.rewardAmount.ToString(),
				"startTimestamp", ufmt.Sprintf("%d", startTimestamp),
				"endTimestamp", ufmt.Sprintf("%d", endTimestamp),
				"internal_incentiveId", incentiveId,
				"internal_depositGnsAmount", ufmt.Sprintf("%d", ictv.depositGnsAmount),
				"internal_external", "updated",
			)

			return
		}
	}

	// external deposit amount
	gns.TransferFrom(a2u(std.PrevRealm().Addr()), a2u(GetOrigPkgAddr()), depositGnsAmount)

	// external reward amount
	transferFromByRegisterCall(rewardToken, std.PrevRealm().Addr(), GetOrigPkgAddr(), rewardAmount.Uint64())

	incentiveDuration := endTimestamp - startTimestamp
	incentiveBlock := incentiveDuration / consts.BLOCK_GENERATION_INTERVAL
	rewardAmountX96 := new(u256.Uint).Mul(rewardAmount, u256.MustFromDecimal(consts.Q96))
	rewardPerBlockX96 := new(u256.Uint).Div(rewardAmountX96, u256.NewUint(uint64(incentiveBlock)))

	newExternalIctv := ExternalIncentive{
		targetPoolPath:    targetPoolPath,
		rewardToken:       rewardToken,
		rewardAmount:      rewardAmount,
		rewardLeft:        rewardAmount,
		startTimestamp:    startTimestamp,
		endTimestamp:      endTimestamp,
		rewardPerBlockX96: rewardPerBlockX96,
		refundee:          std.PrevRealm().Addr(),
		createdHeight:     std.GetHeight(),
		depositGnsAmount:  depositGnsAmount,
	}

	incentives.Set(incentiveId, newExternalIctv)

	existingIctv, exists := poolIncentives.Get(targetPoolPath)
	if exists {
		poolIncentives.Set(targetPoolPath, append(existingIctv, incentiveId))
	} else {
		poolIncentives.Set(targetPoolPath, []string{incentiveId})
	}

	externalLastCalculatedTimestamp[incentiveId] = time.Now().Unix()

	if rewardToken == consts.GNS_PATH {
		externalGns[incentiveId] = rewardAmount.Uint64()
	}

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"CreateExternalIncentive",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", targetPoolPath,
		"rewardToken", rewardToken,
		"rewardAmount", _rewardAmount,
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

	ictvId := incentiveIdCompute(refundee, targetPoolPath, rewardToken, startTimestamp, endTimestamp, height)

	ictv, exists := incentives.Get(ictvId)
	if !exists {
		panic(addDetailToError(
			errCannotEndIncentive,
			ufmt.Sprintf("staker.gno__EndExternalIncentive() || cannot end non existent incentive(%s)", ictvId),
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
	refundUint64 := refund.Uint64()

	poolLeftExternalRewardAmount := balanceOfByRegisterCall(ictv.rewardToken, GetOrigPkgAddr())
	if poolLeftExternalRewardAmount < refundUint64 {
		refundUint64 = poolLeftExternalRewardAmount
	}

	transferByRegisterCall(ictv.rewardToken, ictv.refundee, refundUint64)
	// unwrap if wugnot
	if ictv.rewardToken == consts.WUGNOT_PATH {
		unwrap(refundUint64)
	}

	// also refund deposit gns amount
	gns.Transfer(a2u(ictv.refundee), ictv.depositGnsAmount)

	incentives.Remove(ictvId)

	if ictvList, exists := poolIncentives.Get(targetPoolPath); exists {
		newIctvs := make([]string, 0, len(ictvList)-1)
		for _, v := range ictvList {
			if v != ictvId {
				newIctvs = append(newIctvs, v)
			}
		}
		poolIncentives.Set(targetPoolPath, newIctvs)
	}

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"EndExternalIncentive",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", targetPoolPath,
		"rewardToken", rewardToken,
		"refundee", refundee.String(),
		"internal_endBy", ictv.refundee.String(),
		"internal_refundAmount", refund.ToString(),
		"internal_refundGnsAmount", ufmt.Sprintf("%d", ictv.depositGnsAmount),
		"internal_incentiveId", ictvId,
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
