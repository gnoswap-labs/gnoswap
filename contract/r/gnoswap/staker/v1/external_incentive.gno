package staker

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/utils"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	sr "gno.land/r/gnoswap/staker"
)

// CreateExternalIncentive creates an external incentive program for a pool.
//
// Parameters:
//   - targetPoolPath: pool to incentivize
//   - rewardToken: reward token path
//   - rewardAmount: total reward amount
//   - startTimestamp, endTimestamp: incentive period
//
// Only callable by admin.
func (s *stakerV1) CreateExternalIncentive(
	_ int,
	rlm realm,
	targetPoolPath string,
	rewardToken string, // token path should be registered
	rewardAmount int64,
	startTimestamp int64,
	endTimestamp int64,
) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedStaker()

	prevRealm := rlm.Previous()
	caller := prevRealm.Address()
	access.AssertIsAdmin(caller)

	assertIsPoolExists(s, targetPoolPath)

	assertIsGreaterThanMinimumRewardAmount(s, rewardToken, rewardAmount)
	assertIsAllowedForExternalReward(s, targetPoolPath, rewardToken)
	assertIsValidIncentiveStartTime(startTimestamp)
	assertIsValidIncentiveEndTime(endTimestamp)
	assertIsValidIncentiveDuration(gnsmath.SafeSubInt64(endTimestamp, startTimestamp))
	// assert that the user has sent the correct amount of native coin
	common.AssertIsNotHandleNativeCoin()

	en.MintAndDistributeGns(cross(rlm))

	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())

	// transfer reward token from user to staker
	common.SafeGRC20TransferFrom(cross(rlm), rewardToken, caller, stakerAddr, rewardAmount)

	depositGnsAmount := s.store.GetDepositGnsAmount()

	// deposit gns amount
	common.SafeGRC20TransferFrom(cross(rlm), GNS_TOKEN_KEY, caller, stakerAddr, depositGnsAmount)

	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()
	incentiveId := s.store.NextIncentiveID(caller, currentTime)
	pool := s.getPools().GetPoolOrNil(targetPoolPath)
	if pool == nil {
		pool = sr.NewPool(targetPoolPath, currentTime)
		s.getPools().set(targetPoolPath, pool)
	}

	incentive := sr.NewExternalIncentive(
		incentiveId,
		targetPoolPath,
		rewardToken,
		rewardAmount,
		startTimestamp,
		endTimestamp,
		caller,
		depositGnsAmount,
		currentHeight,
		currentTime,
	)

	externalIncentives := s.store.GetExternalIncentives()
	if externalIncentives.Has(incentiveId) {
		panic(makeErrorWithDetails(
			errIncentiveAlreadyExists,
			ufmt.Sprintf("incentiveId(%s)", incentiveId),
		))
	}
	// store external incentive information for each incentiveId
	externalIncentives.Set(incentiveId, incentive)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(incentive)

	chain.Emit(
		"CreateExternalIncentive",
		"prevAddr", caller.String(),
		"prevRealm", prevRealm.PkgPath(),
		"incentiveId", incentiveId,
		"targetPoolPath", targetPoolPath,
		"rewardToken", rewardToken,
		"rewardAmount", utils.FormatInt(rewardAmount),
		"startTimestamp", utils.FormatInt(startTimestamp),
		"endTimestamp", utils.FormatInt(endTimestamp),
		"depositGnsAmount", utils.FormatInt(depositGnsAmount),
		"currentHeight", utils.FormatInt(currentHeight),
		"currentTime", utils.FormatInt(currentTime),
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
// Only callable by Creator or Admin.
func (s *stakerV1) EndExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string, refundAddress address) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	// checks pool registry
	assertIsPoolExists(s, targetPoolPath)
	assertIsValidAddress(refundAddress)

	// checks if the pool has been incentivized
	pool, ok := s.getPools().Get(targetPoolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("targetPoolPath(%s) not found", targetPoolPath),
		))
	}

	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()

	// Get incentive to check if GNS already refunded
	incentiveResolver, exists := incentivesResolver.GetIncentiveResolver(incentiveId)
	if !exists {
		panic(makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("cannot end non existent incentive(%s)", incentiveId),
		))
	}

	// Check if incentive has already been refunded
	if incentiveResolver.Refunded() {
		panic(makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("incentive(%s) has already been refunded", incentiveId),
		))
	}

	caller := rlm.Previous().Address()

	// Process ending
	incentive, refund, err := s.endExternalIncentive(poolResolver, incentiveResolver, caller, time.Now().Unix())
	if err != nil {
		panic(err)
	}

	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	poolLeftExternalRewardAmount := common.BalanceOf(incentiveResolver.RewardToken(), stakerAddr)
	if poolLeftExternalRewardAmount < refund {
		previousRealm := rlm.Previous()
		chain.Emit(
			"EndExternalIncentiveShortfall",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"incentiveId", incentiveId,
			"targetPoolPath", targetPoolPath,
			"refundee", refundAddress.String(),
			"refundToken", incentiveResolver.RewardToken(),
			"expectedRefundAmount", utils.FormatInt(refund),
			"actualRefundAmount", utils.FormatInt(poolLeftExternalRewardAmount),
			"creator", incentiveResolver.Creator().String(),
		)
		refund = poolLeftExternalRewardAmount
	}

	// Mark incentive as refunded and update
	// After this update, attempts to re-claim GNS or rewards that were deposited
	// through the `endExternalIncentive` function will be blocked.
	incentiveResolver.SetRefunded(true)
	incentiveResolver.SetRewardAmount(gnsmath.SafeSubInt64(incentiveResolver.RewardAmount(), refund))
	incentiveResolver.addDistributedRewardAmount(refund)
	incentivesResolver.update(incentive)

	// refund reward token to refundee
	common.SafeGRC20Transfer(cross(rlm), incentiveResolver.RewardToken(), refundAddress, refund)

	// Transfer GNS deposit back to refundee
	common.SafeGRC20Transfer(cross(rlm), GNS_TOKEN_KEY, refundAddress, incentiveResolver.DepositGnsAmount())

	previousRealm := rlm.Previous()
	chain.Emit(
		"EndExternalIncentive",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"incentiveId", incentiveId,
		"targetPoolPath", targetPoolPath,
		"refundee", refundAddress.String(),
		"refundToken", incentiveResolver.RewardToken(),
		"refundAmount", utils.FormatInt(refund),
		"refundGnsAmount", utils.FormatInt(incentiveResolver.DepositGnsAmount()),
		"externalIncentiveEndBy", previousRealm.Address().String(),
		"creator", incentiveResolver.Creator().String(),
	)
}

// endExternalIncentive processes the end of an external incentive program.
func (s *stakerV1) endExternalIncentive(resolver *PoolResolver, incentiveResolver *ExternalIncentiveResolver, caller address, currentTime int64) (*sr.ExternalIncentive, int64, error) {
	if currentTime < incentiveResolver.EndTimestamp() {
		return nil, 0, makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("cannot end incentive before endTime(%d), current(%d)", incentiveResolver.EndTimestamp(), currentTime),
		)
	}

	// only creator or admin can end incentive
	if !access.IsAuthorized(prbac.ROLE_ADMIN.String(), caller) && caller != incentiveResolver.Creator() {
		adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
		return nil, 0, makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf(
				"only creator(%s) or admin(%s) can end incentive, but called from %s",
				incentiveResolver.Creator(), adminAddr.String(), caller,
			),
		)
	}

	// refund = unclaimableReward + remainder + accumulatedPenaltyAmount
	incentivesResolver := resolver.IncentivesResolver()
	unclaimableReward := incentivesResolver.calculateUnclaimableReward(incentiveResolver.IncentiveId())

	duration := gnsmath.SafeSubInt64(incentiveResolver.EndTimestamp(), incentiveResolver.StartTimestamp())
	// distributable = floor((rewardPerSecondX128 * duration) / 2^128).
	// With Q128 scaling the truncation per second collapses to at most 1 wei
	// across the entire duration, so `remainder` is effectively zero and the
	// refund accounts only for unclaimable periods.
	distributableU256 := u256.MulDiv(
		incentiveResolver.RewardPerSecondX128(),
		u256.NewUintFromInt64(duration),
		q128,
	)

	distributable := gnsmath.SafeConvertToInt64(distributableU256)
	remainder := gnsmath.SafeSubInt64(incentiveResolver.TotalRewardAmount(), distributable)

	refund := gnsmath.SafeAddInt64(unclaimableReward, remainder)

	maxRefund := incentiveResolver.RewardAmount()
	if refund > maxRefund {
		refund = maxRefund
	}

	if refund < 0 {
		return nil, 0, makeErrorWithDetails(
			errCalculationError,
			ufmt.Sprintf("refund should never be negative: Got %d", refund),
		)
	}

	return incentiveResolver.ExternalIncentive, refund, nil
}

// CancelExternalIncentive cancels an external incentive before it starts and
// removes it entirely.
//
// EndExternalIncentive is the counterpart for an incentive whose end timestamp
// has passed: it keeps the record so the penalty accounting and the deposits
// that already collected from it stay resolvable. Cancelling is only allowed
// strictly before startTimestamp, where nothing has accrued yet - no deposit
// references the incentive (both StakeToken and the lazy reward discovery only
// look at incentives whose start timestamp is already in the past), so the
// record can be dropped from the incentive tree and the start-time index
// instead of being marked refunded.
//
// Parameters:
//   - targetPoolPath: pool the incentive was created for
//   - incentiveId: unique incentive identifier
//
// Process:
//  1. Validates the incentive exists and has not started
//  2. Removes it from the incentive tree and the start-time index
//  3. Refunds the full reward amount and the GNS deposit to the creator
//
// Only callable by admin or governance.
func (s *stakerV1) CancelExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	assertIsPoolExists(s, targetPoolPath)

	prevRealm := rlm.Previous()
	caller := prevRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	pool, ok := s.getPools().Get(targetPoolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("targetPoolPath(%s) not found", targetPoolPath),
		))
	}

	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()

	incentiveResolver, exists := incentivesResolver.GetIncentiveResolver(incentiveId)
	if !exists {
		panic(makeErrorWithDetails(
			errCannotCancelIncentive,
			ufmt.Sprintf("cannot cancel non existent incentive(%s)", incentiveId),
		))
	}

	currentTime := time.Now().Unix()
	assertIsNotStartedIncentive(incentiveResolver, currentTime)

	rewardToken := incentiveResolver.RewardToken()
	depositGnsAmount := incentiveResolver.DepositGnsAmount()
	refundAmount := incentiveResolver.RewardAmount()

	// The reward tokens and the GNS deposit are always returned to the incentive
	// creator - the address that funded them in CreateExternalIncentive - so the
	// refund destination is never caller-controlled.
	creator := incentiveResolver.Creator()

	// Cap the refund by the balance actually held, mirroring
	// EndExternalIncentive: a short balance must not abort the cancellation and
	// strand the GNS deposit as well.
	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	rewardBalance := common.BalanceOf(rewardToken, stakerAddr)
	if rewardBalance < refundAmount {
		chain.Emit(
			"CancelExternalIncentiveShortfall",
			"prevAddr", caller.String(),
			"prevRealm", prevRealm.PkgPath(),
			"incentiveId", incentiveId,
			"targetPoolPath", targetPoolPath,
			"refundToken", rewardToken,
			"expectedRefundAmount", utils.FormatInt(refundAmount),
			"actualRefundAmount", utils.FormatInt(rewardBalance),
			"refundee", creator.String(),
			"creator", creator.String(),
		)
		refundAmount = rewardBalance
	}

	// Effects before interactions: once removed, no stake, collect or discovery
	// path can resolve the incentive, so the refund cannot be replayed.
	incentivesResolver.remove(incentiveResolver.ExternalIncentive)
	s.getExternalIncentives().remove(incentiveId)

	if refundAmount > 0 {
		// transfer reward token back to creator
		common.SafeGRC20Transfer(cross(rlm), rewardToken, creator, refundAmount)
	}

	if depositGnsAmount > 0 {
		// transfer GNS deposit back to creator
		common.SafeGRC20Transfer(cross(rlm), GNS_TOKEN_KEY, creator, depositGnsAmount)
	}

	chain.Emit(
		"CancelExternalIncentive",
		"prevAddr", caller.String(),
		"prevRealm", prevRealm.PkgPath(),
		"incentiveId", incentiveId,
		"targetPoolPath", targetPoolPath,
		"refundToken", rewardToken,
		"refundAmount", utils.FormatInt(refundAmount),
		"refundGnsAmount", utils.FormatInt(depositGnsAmount),
		"startTimestamp", utils.FormatInt(incentiveResolver.StartTimestamp()),
		"endTimestamp", utils.FormatInt(incentiveResolver.EndTimestamp()),
		"externalIncentiveCancelBy", caller.String(),
		"creator", creator.String(),
		"currentTime", utils.FormatInt(currentTime),
	)
}

// CollectExternalIncentivePenalty collects accumulated warmup penalties
// for a specific ended external incentive.
// Penalties are accumulated during CollectReward and stored in the incentive.
// This function transfers the accumulated penalty to the specified refund address.
// Returns the penalty amount collected.
//
// Only callable by the incentive creator or admin.
func (s *stakerV1) CollectExternalIncentivePenalty(
	_ int,
	rlm realm,
	targetPoolPath string,
	incentiveId string,
	refundAddress address,
) int64 {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	assertIsPoolExists(s, targetPoolPath)
	assertIsValidAddress(refundAddress)

	pool, ok := s.getPools().Get(targetPoolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("targetPoolPath(%s) not found", targetPoolPath),
		))
	}

	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()

	incentiveResolver, exists := incentivesResolver.GetIncentiveResolver(incentiveId)
	if !exists {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("incentive(%s) not found", incentiveId),
		))
	}

	if !incentiveResolver.Refunded() {
		panic(makeErrorWithDetails(
			errIsNotEndedIncentive,
			ufmt.Sprintf("incentive(%s) must be ended first (call EndExternalIncentive)", incentiveId),
		))
	}

	caller := rlm.Previous().Address()
	if !access.IsAuthorized(prbac.ROLE_ADMIN.String(), caller) && caller != incentiveResolver.Creator() {
		adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("only creator(%s) or admin(%s) can collect penalty, but called from %s", incentiveResolver.Creator(), adminAddr.String(), caller),
		))
	}

	penaltyAmount := incentiveResolver.AccumulatedPenaltyAmount()
	if penaltyAmount == 0 {
		return 0
	}

	// Cap by actual staker balance
	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	balance := common.BalanceOf(incentiveResolver.RewardToken(), stakerAddr)
	if balance < penaltyAmount {
		previousRealm := rlm.Previous()
		chain.Emit(
			"CollectExternalIncentivePenaltyShortfall",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"targetPoolPath", targetPoolPath,
			"incentiveId", incentiveId,
			"refundAddress", refundAddress.String(),
			"refundToken", incentiveResolver.RewardToken(),
			"expectedPenaltyAmount", utils.FormatInt(penaltyAmount),
			"actualPenaltyAmount", utils.FormatInt(balance),
			"creator", incentiveResolver.Creator().String(),
		)
		penaltyAmount = balance
	}

	// Reset accumulated penalty
	incentiveResolver.SetAccumulatedPenaltyAmount(gnsmath.SafeSubInt64(incentiveResolver.AccumulatedPenaltyAmount(), penaltyAmount))
	incentivesResolver.update(incentiveResolver.ExternalIncentive)

	// Transfer penalty to refund address
	common.SafeGRC20Transfer(cross(rlm), incentiveResolver.RewardToken(), refundAddress, penaltyAmount)

	previousRealm := rlm.Previous()
	chain.Emit(
		"CollectExternalIncentivePenalty",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"targetPoolPath", targetPoolPath,
		"incentiveId", incentiveId,
		"refundAddress", refundAddress.String(),
		"penaltyAmount", utils.FormatInt(penaltyAmount),
	)

	return penaltyAmount
}
