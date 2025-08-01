package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/halt"
)

// CreateExternalIncentive creates an incentive program for a pool.
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#createexternalincentive
func CreateExternalIncentive(
	cur realm,
	targetPoolPath string,
	rewardToken string, // token path should be registered
	rewardAmount int64,
	startTimestamp int64,
	endTimestamp int64,
) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsUser(std.PreviousRealm())

	assertIsPoolExists(targetPoolPath)
	assertIsGreaterThanMinimumRewardAmount(rewardToken, rewardAmount)
	assertIsAllowedForExternalReward(targetPoolPath, rewardToken)
	assertIsValidIncentiveStartTime(startTimestamp)
	assertIsValidIncentiveEndTime(endTimestamp)
	assertIsValidIncentiveDuration(endTimestamp - startTimestamp)

	en.MintAndDistributeGns(cross)

	// native ugnot check
	if rewardToken == GNOT {
		sent := std.OriginSend()
		ugnotSent := sent.AmountOf("ugnot")

		if ugnotSent != rewardAmount {
			panic(makeErrorWithDetails(
				errInvalidInput,
				ufmt.Sprintf("user(%s) sent ugnot(%d) amount not equal to rewardAmount(%d)", caller.String(), ugnotSent, rewardAmount),
			))
		}

		wrap(ugnotSent)

		rewardToken = WUGNOT_PATH
	}

	incentiveId := nextIncentiveID(caller, std.ChainHeight())
	pool := pools.GetOrCreate(targetPoolPath)
	incentive := NewExternalIncentive(
		incentiveId,
		targetPoolPath,
		rewardToken,
		rewardAmount,
		int64(startTimestamp),
		int64(endTimestamp),
		caller,
		std.ChainHeight(),
		depositGnsAmount,
		time.Now().Unix(),
		gns.AvgBlockTimeInMs(),
	)

	if externalIncentives.Has(incentiveId) {
		panic(makeErrorWithDetails(
			errIncentiveAlreadyExists,
			ufmt.Sprintf("incentiveId(%s)", incentiveId),
		))
	}
	// store external incentive information for each incentiveId
	externalIncentives.set(incentiveId, incentive)

	// deposit gns amount
	gns.TransferFrom(cross, caller, stakerAddr, depositGnsAmount)

	// transfer reward token from user to staker
	common.TransferFrom(cross, rewardToken, caller, stakerAddr, rewardAmount)

	pool.incentives.create(caller, incentive)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"CreateExternalIncentive",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"incentiveId", incentiveId,
		"targetPoolPath", targetPoolPath,
		"rewardToken", rewardToken,
		"rewardAmount", formatInt(rewardAmount),
		"startTimestamp", formatInt(startTimestamp),
		"endTimestamp", formatInt(endTimestamp),
		"depositGnsAmount", formatInt(depositGnsAmount),
		"currentHeight", formatInt(std.ChainHeight()),
		"currentTime", formatInt(time.Now().Unix()),
		"avgBlockTimeInMs", formatInt(gns.AvgBlockTimeInMs()),
	)
}

// EndExternalIncentive ends the external incentive and refunds the remaining reward
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#endexternalincentive
func EndExternalIncentive(cur realm, targetPoolPath, incentiveId string) {
	halt.AssertIsNotHaltedStaker()
	halt.AssertIsNotHaltedWithdraw()

	assertIsPoolExists(targetPoolPath)

	pool, exists := pools.Get(targetPoolPath)
	if !exists {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("targetPoolPath(%s) does not exist", targetPoolPath),
		))
	}

	caller := std.PreviousRealm().Address()
	incentive, refund, err := endExternalIncentive(pool, incentiveId, caller, std.ChainHeight())
	if err != nil {
		panic(err)
	}

	poolLeftExternalRewardAmount := common.BalanceOf(incentive.rewardToken, stakerAddr)
	if poolLeftExternalRewardAmount < refund {
		refund = poolLeftExternalRewardAmount
	}

	common.Transfer(cross, incentive.rewardToken, incentive.refundee, refund)

	// unwrap if wugnot
	if incentive.rewardToken == WUGNOT_PATH {
		unwrap(refund)
	}

	// also refund deposit gns amount
	gns.Transfer(cross, incentive.refundee, int64(incentive.depositGnsAmount))

	pool.incentives.update(incentive.refundee, incentive)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"EndExternalIncentive",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"incentiveId", incentiveId,
		"targetPoolPath", targetPoolPath,
		"refundee", incentive.refundee.String(),
		"refundToken", incentive.rewardToken,
		"refundAmount", formatInt(refund),
		"refundGnsAmount", formatInt(incentive.depositGnsAmount),
		"isRequestUnwrap", formatBool(incentive.rewardToken == WUGNOT_PATH),
		"externalIncentiveEndBy", previousRealm.Address().String(),
	)
}

func endExternalIncentive(pool *Pool, incentiveId string, caller std.Address, currentHeight int64) (*ExternalIncentive, int64, error) {
	incentive, exists := pool.incentives.Get(incentiveId)
	if !exists {
		return nil, 0, makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("cannot end non existent incentive(%s)", incentiveId),
		)
	}

	if int64(currentHeight) < incentive.endHeight {
		return nil, 0, makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("cannot end incentive before endHeight(%d), current(%d)", incentive.endHeight, currentHeight),
		)
	}

	// only refundee or admin can end incentive
	if !access.IsAuthorized(prbac.ROLE_ADMIN.String(), caller) && caller != incentive.refundee {
		return nil, 0, makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf(
				"only refundee(%s) or admin(%s) can end incentive, but called from %s",
				incentive.refundee, adminAddr.String(), caller,
			),
		)
	}

	refund := int64(incentive.rewardLeft)

	if !incentive.unclaimableRefunded {
		refund += int64(pool.incentives.calculateUnclaimableReward(incentive.incentiveId))
		incentive.setUnClaimableRefunded(true)
	}

	return incentive, refund, nil
}