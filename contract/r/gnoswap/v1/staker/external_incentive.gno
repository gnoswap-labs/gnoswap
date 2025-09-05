package staker

import (
	"std"
	"time"

	"gno.land/p/nt/ufmt"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"
)

// CreateExternalIncentive creates an external incentive program for a pool.
//
// Parameters:
//   - targetPoolPath: pool to incentivize
//   - rewardToken: reward token path
//   - rewardAmount: total reward amount
//   - startTimestamp, endTimestamp: incentive period
//
// Only callable by users.
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

	// transfer reward token from user to staker
	if rewardToken == GNOT {
		rewardToken = WUGNOT_PATH
		err := wrapWithTransfer(stakerAddr, rewardAmount)
		if err != nil {
			panic(err)
		}
	} else {
		err := common.TransferFrom(cross, rewardToken, caller, stakerAddr, rewardAmount)
		if err != nil {
			panic(err)
		}
	}

	// deposit gns amount
	gns.TransferFrom(cross, caller, stakerAddr, depositGnsAmount)

	currentTime := time.Now().Unix()
	currentHeight := std.ChainHeight()
	incentiveId := nextIncentiveID(caller, currentTime)
	pool := pools.GetOrCreate(targetPoolPath)

	incentive := NewExternalIncentive(
		incentiveId,
		targetPoolPath,
		rewardToken,
		rewardAmount,
		startTimestamp,
		endTimestamp,
		caller,
		currentHeight,
		depositGnsAmount,
		currentTime,
	)

	if externalIncentives.Has(incentiveId) {
		panic(makeErrorWithDetails(
			errIncentiveAlreadyExists,
			ufmt.Sprintf("incentiveId(%s)", incentiveId),
		))
	}
	// store external incentive information for each incentiveId
	externalIncentives.set(incentiveId, incentive)

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
		"currentHeight", formatInt(currentHeight),
		"currentTime", formatInt(currentTime),
	)
}

// EndExternalIncentive ends an external incentive and refunds remaining rewards.
//
// Finalizes incentive program after end timestamp.
// Returns unallocated rewards and GNS deposit.
// Calculates unclaimable rewards for refund.
//
// Parameters:
//   - targetPoolPath: Pool with the incentive
//   - incentiveId: Unique incentive identifier
//
// Process:
//  1. Validates incentive end time reached
//  2. Calculates remaining and unclaimable rewards
//  3. Refunds rewards to original creator
//  4. Returns 100 GNS deposit
//  5. Removes incentive from active list
//
// Only callable by Refundee or Admin.
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
	currentTime := time.Now().Unix()
	incentive, refund, err := endExternalIncentive(pool, incentiveId, caller, currentTime)
	if err != nil {
		panic(err)
	}

	poolLeftExternalRewardAmount := common.BalanceOf(incentive.rewardToken, stakerAddr)
	if poolLeftExternalRewardAmount < refund {
		refund = poolLeftExternalRewardAmount
	}

	// unwrap if wugnot
	isUnwrap := incentive.rewardToken == WUGNOT_PATH
	if isUnwrap {
		err = unwrapWithTransfer(incentive.refundee, refund)
	} else {
		err = common.Transfer(cross, incentive.rewardToken, incentive.refundee, refund)
	}

	if err != nil {
		panic(err)
	}

	// also refund deposit gns amount
	gns.Transfer(cross, incentive.refundee, incentive.depositGnsAmount)

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

// endExternalIncentive processes the end of an external incentive program.
func endExternalIncentive(pool *Pool, incentiveId string, caller std.Address, currentTime int64) (*ExternalIncentive, int64, error) {
	incentive, exists := pool.incentives.Get(incentiveId)
	if !exists {
		return nil, 0, makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("cannot end non existent incentive(%s)", incentiveId),
		)
	}

	if currentTime < incentive.endTimestamp {
		return nil, 0, makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("cannot end incentive before endTime(%d), current(%d)", incentive.endTimestamp, currentTime),
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
