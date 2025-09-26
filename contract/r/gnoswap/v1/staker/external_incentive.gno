package staker

import (
	"std"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

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
	halt.AssertIsNotHaltedStakerWithVersion(1)

	caller := std.PreviousRealm().Address()
	access.AssertIsUser(std.PreviousRealm())

	assertIsPoolExists(targetPoolPath)
	assertIsGreaterThanMinimumRewardAmount(rewardToken, rewardAmount)
	assertIsAllowedForExternalReward(targetPoolPath, rewardToken)
	assertIsValidIncentiveStartTime(startTimestamp)
	assertIsValidIncentiveEndTime(endTimestamp)
	assertIsValidIncentiveDuration(endTimestamp - startTimestamp)
	// assert that the user has sent the correct amount of native coin
	assertIsValidUserCoinSend(rewardToken, rewardAmount)

	en.MintAndDistributeGns(cross)

	// transfer reward token from user to staker
	isRequestUnwrap := false
	if rewardToken == GNOT {
		isRequestUnwrap = true
		rewardToken = WUGNOT_PATH
		err := wrapWithTransfer(stakerAddr, rewardAmount)
		if err != nil {
			panic(err)
		}
	} else {
		common.SafeGRC20TransferFrom(cross, rewardToken, caller, stakerAddr, rewardAmount)
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
		isRequestUnwrap,
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
	halt.AssertIsNotHaltedStakerWithVersion(1)
	halt.AssertIsNotHaltedWithdrawWithVersion(1)

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

	// Get incentive to check if GNS already refunded
	incentive, exists := pool.incentives.Get(incentiveId)
	if !exists {
		panic(makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("cannot end non existent incentive(%s)", incentiveId),
		))
	}

	// Check if incentive has already been refunded
	if incentive.refunded {
		panic(makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("incentive(%s) has already been refunded", incentiveId),
		))
	}

	// Process ending
	incentive, refund, err := endExternalIncentive(pool, incentiveId, caller, currentTime)
	if err != nil {
		panic(err)
	}

	poolLeftExternalRewardAmount := common.BalanceOf(incentive.rewardToken, stakerAddr)
	if poolLeftExternalRewardAmount < refund {
		refund = poolLeftExternalRewardAmount
	}

	// handle refund based on original token type
	if incentive.isRequestUnwrap {
		// unwrap to GNOT if originally deposited as native GNOT
		transferErr := unwrapWithTransfer(incentive.refundee, refund)
		if transferErr != nil {
			panic(transferErr)
		}
	} else {
		// keep as WUGNOT or other token if originally deposited as wrapped token
		common.SafeGRC20Transfer(cross, incentive.rewardToken, incentive.refundee, refund)
	}

	// Transfer GNS deposit back to refundee
	gns.Transfer(cross, incentive.refundee, incentive.depositGnsAmount)

	// Mark incentive as refunded and update
	// After this update, attempts to re-claim GNS or rewards that were deposited
	// through the `endExternalIncentive` function will be blocked.
	incentive.setRefunded(true)
	pool.incentives.update(incentive.refundee, incentive)
	pool.incentives.archiveIncentive(incentiveId)

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
		"isRequestUnwrap", formatBool(incentive.isRequestUnwrap),
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

	// Always calculate unclaimed rewards since this function is called only once
	refund := incentive.rewardLeft
	refund += pool.incentives.calculateUnclaimableReward(incentive.incentiveId)
	// Add dust amount from precision loss to refund
	refund += incentive.rewardDust

	return incentive, refund, nil
}
