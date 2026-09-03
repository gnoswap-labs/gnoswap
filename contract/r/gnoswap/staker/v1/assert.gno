package staker

import (
	"math"
	"strconv"
	"strings"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
)

const (
	TIMESTAMP_90DAYS  = int64(7776000)
	TIMESTAMP_180DAYS = int64(15552000)
	TIMESTAMP_365DAYS = int64(31536000)

	maxIncentiveStartDelay = 7 * 24 * time.Hour

	MAX_UNIX_EPOCH_TIME = 253402300799 // 9999-12-31 23:59:59

	maxUnstakingFee = uint64(1000) // 10%
)

// assertIsValidAmount ensures the amount is non-negative.
func assertIsValidAmount(amount int64) {
	if amount < 0 {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("amount(%d) must be positive", amount),
		))
	}
}

// assertIsValidRewardAmountFormat ensures the reward amount string is formatted as "tokenPath:amount".
func assertIsValidRewardAmountFormat(rewardAmountStr string) {
	parts := strings.SplitN(rewardAmountStr, ":", 2)
	if len(parts) != 2 {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("invalid format for SetTokenMinimumRewardAmount params: expected 'tokenPath:amount', got '%s'", rewardAmountStr),
		))
	}
}

// assertIsDepositor ensures the caller is the owner of the deposit.
func assertIsDepositor(s *stakerV1, caller address, positionId uint64) {
	deposit := s.getDeposits().get(positionId)
	if deposit == nil {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("positionId(%d) not found", positionId),
		))
	}

	if caller != deposit.Owner() {
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not depositor(%s)", caller.String(), deposit.Owner().String()),
		))
	}
}

// assertIsIncentiveOfDeposit ensures the incentive exists and targets the pool the position is staked
// in, so a caller cannot ask a deposit to collect an incentive that can never pay it.
func assertIsIncentiveOfDeposit(s *stakerV1, positionId uint64, incentiveId string) {
	deposit := s.getDeposits().get(positionId)
	assertIsIncentiveOfPool(s, deposit.TargetPoolPath(), positionId, incentiveId)
}

// assertIsIncentiveOfPool ensures the incentive targets the pool the position is staked in.
func assertIsIncentiveOfPool(s *stakerV1, poolPath string, positionId uint64, incentiveId string) {
	// get panics with errDataNotFound when the incentive does not exist.
	incentive := s.getExternalIncentives().get(incentiveId)

	if incentive.TargetPoolPath() != poolPath {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf(
				"incentiveId(%s) targets pool(%s), but positionId(%d) is staked in pool(%s)",
				incentiveId, incentive.TargetPoolPath(), positionId, poolPath,
			),
		))
	}
}

// assertHasNoExitCheckpoint ensures the position carries no reward from a previous stake.
// Collecting it here would smuggle an unbounded calculation into staking, and leaving it would
// let the next unstake overwrite the checkpoint.
func assertHasNoExitCheckpoint(s *stakerV1, positionId uint64) {
	if s.HasUnstakedPosition(positionId) {
		panic(makeErrorWithDetails(
			errUncollectedPosition,
			ufmt.Sprintf("positionId(%d) still owes rewards from its previous stake; collect it first", positionId),
		))
	}
}

// assertHasNoUnsettledIncentive ensures no unstaked position of the pool still owes an
// incentive reward, which has not been drawn down from the incentive yet.
func assertHasNoUnsettledIncentive(s *stakerV1, poolPath string) {
	count := s.unsettledIncentiveCountOf(poolPath)
	if count > 0 {
		panic(makeErrorWithDetails(
			errUncollectedPosition,
			ufmt.Sprintf("pool(%s) has %d unstaked position(s) with uncollected incentive rewards", poolPath, count),
		))
	}
}

// assertIsNotStaked ensures the position is not already staked.
func assertIsNotStaked(s *stakerV1, positionId uint64) {
	if s.getDeposits().Has(positionId) {
		panic(makeErrorWithDetails(
			errAlreadyStaked,
			ufmt.Sprintf("positionId(%d) already staked", positionId),
		))
	}
}

// assertIsPoolExists ensures the pool exists.
func assertIsPoolExists(s *stakerV1, poolPath string) {
	if !s.poolAccessor.ExistsPoolPath(poolPath) {
		panic(makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("pool(%s) does not exist", poolPath),
		))
	}
}

// assertIsValidPoolTier ensures the tier is within valid range.
func assertIsValidPoolTier(tier uint64) {
	if tier >= AllTierCount {
		panic(makeErrorWithDetails(
			errInvalidPoolTier,
			ufmt.Sprintf("tier(%d) must be less than %d", tier, AllTierCount),
		))
	}
}

// assertTier1HasSparePool ensures tier 1 keeps at least one pool after a tier change.
func assertTier1HasSparePool(currentTier, tier1Count uint64) {
	if currentTier == Tier1 && tier1Count == 1 {
		panic(makeErrorWithDetails(errInvalidPoolTier, "tier 1 must have at least one pool"))
	}
}

// assertIsGreaterThanMinimumRewardAmount ensures the reward amount meets minimum requirements.
func assertIsGreaterThanMinimumRewardAmount(s *stakerV1, rewardToken string, rewardAmount int64) {
	minReward := s.getMinimumRewardAmount()

	if minRewardInt64, found := s.store.GetTokenSpecificMinimumRewards()[rewardToken]; found {
		minReward = minRewardInt64
	}

	if rewardAmount < minReward {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("rewardAmount(%d) is less than minimum required amount(%d)", rewardAmount, minReward),
		))
	}
}

// assertIsAllowedForExternalReward ensures the token is allowed for external rewards.
func assertIsAllowedForExternalReward(s *stakerV1, poolPath, tokenPath string) {
	token0, token1, _ := poolPathDivide(poolPath)

	if tokenPath == token0 || tokenPath == token1 {
		return
	}

	allowed := contains(s.store.GetAllowedTokens(), tokenPath)
	if allowed {
		return
	}

	panic(makeErrorWithDetails(
		errNotAllowedForExternalReward,
		ufmt.Sprintf("tokenPath(%s) is not allowed for external reward for poolPath(%s)", tokenPath, poolPath),
	))
}

// assertIsExternalRewardTokenAvailable ensures a pool has no unfinished incentive for the token.
func assertIsExternalRewardTokenAvailable(s *stakerV1, poolPath, tokenPath string, currentTime int64) {
	pool := s.getPools().GetPoolOrNil(poolPath)
	if pool == nil || pool.Incentives() == nil {
		return
	}

	minimumActiveIncentiveStartTime := currentTime - TIMESTAMP_365DAYS
	if minimumActiveIncentiveStartTime < 0 {
		minimumActiveIncentiveStartTime = 0
	}

	pool.Incentives().IterateIncentiveIdsByTime(minimumActiveIncentiveStartTime, math.MaxInt64, func(incentiveID string) bool {
		incentive := s.getExternalIncentives().get(incentiveID)
		if incentive == nil {
			return false
		}

		if incentive.RewardToken() != tokenPath || NewExternalIncentiveResolver(incentive).IsEnded(currentTime) {
			return false
		}

		panic(makeErrorWithDetails(
			errIncentiveAlreadyExists,
			ufmt.Sprintf(
				"rewardToken(%s) already has unfinished incentive(%s) for poolPath(%s)",
				tokenPath,
				incentiveID,
				poolPath,
			),
		))
	})
}

// assertIsValidFeeRate ensures the fee rate is within valid range (0-1000 basis points).
func assertIsValidFeeRate(fee uint64) {
	if fee > maxUnstakingFee {
		panic(makeErrorWithDetails(
			errInvalidUnstakingFee,
			ufmt.Sprintf("fee(%d) must be in range 0 ~ %d", fee, maxUnstakingFee),
		))
	}
}

// assertIsValidIncentiveStartTime ensures the incentive starts at midnight no earlier than 24 hours after creation
// and no later than 7 days after the first eligible midnight.
func assertIsValidIncentiveStartTime(startTimestamp int64) {
	// must be in seconds format, not milliseconds
	// REF: https://stackoverflow.com/a/23982005
	numStr := strconv.Itoa(int(startTimestamp))

	if len(numStr) >= 13 {
		panic(makeErrorWithDetails(
			errInvalidIncentiveStartTime,
			ufmt.Sprintf("startTimestamp(%d) must be in seconds format, not milliseconds", startTimestamp),
		))
	}

	// must be at least 24 hours from now
	minimumStartTimestamp := getMinimumIncentiveStartTimestamp()
	if startTimestamp < minimumStartTimestamp {
		panic(makeErrorWithDetails(
			errInvalidIncentiveStartTime,
			ufmt.Sprintf("startTimestamp(%d) must be at least 24 hours later", startTimestamp),
		))
	}

	maximumStartTimestamp := getMaximumIncentiveStartTimestamp()
	if startTimestamp > maximumStartTimestamp {
		panic(makeErrorWithDetails(
			errInvalidIncentiveStartTime,
			ufmt.Sprintf("startTimestamp(%d) exceeds the maximum start time policy", startTimestamp),
		))
	}

	// must be midnight of the day
	startTime := time.Unix(startTimestamp, 0)
	if !isMidnight(startTime) {
		panic(makeErrorWithDetails(
			errInvalidIncentiveStartTime,
			ufmt.Sprintf("startTime(%d = %s) must be midnight of the day", startTimestamp, startTime.String()),
		))
	}
}

// assertIsAdminGovernanceOrCreator ensures the caller may act on an incentive:
// admin and governance are the protocol-level operators, and the creator is the
// address that funded the incentive in CreateExternalIncentive.
func assertIsAdminGovernanceOrCreator(caller, creator address) {
	if caller == creator {
		return
	}
	if access.IsAuthorized(prbac.ROLE_ADMIN.String(), caller) ||
		access.IsAuthorized(prbac.ROLE_GOVERNANCE.String(), caller) {
		return
	}

	panic(makeErrorWithDetails(
		errNoPermission,
		ufmt.Sprintf(
			"caller(%s) must be admin, governance, or the incentive creator(%s)",
			caller.String(), creator.String(),
		),
	))
}

// assertIsNotStartedIncentive ensures the incentive can still be cancelled, i.e.
// it has not started and nothing has been distributed from it. Only such an
// incentive may be removed outright; anything that already emitted rewards has
// to be finalized through EndExternalIncentive so the refund accounting and the
// penalty balance stay reachable.
func assertIsNotStartedIncentive(incentiveResolver *ExternalIncentiveResolver, currentTime int64) {
	if incentiveResolver.IsStarted(currentTime) {
		panic(makeErrorWithDetails(
			errCannotCancelIncentive,
			ufmt.Sprintf(
				"incentive(%s) already started at %d, current(%d)",
				incentiveResolver.IncentiveId(), incentiveResolver.StartTimestamp(), currentTime,
			),
		))
	}

	if incentiveResolver.Refunded() {
		panic(makeErrorWithDetails(
			errCannotCancelIncentive,
			ufmt.Sprintf("incentive(%s) has already been refunded", incentiveResolver.IncentiveId()),
		))
	}

	// Defensive: a not-yet-started incentive can never have distributed a reward
	// or accrued a warmup penalty. Removing a record that carries either would
	// strand those tokens in the staker, so refuse instead of dropping it.
	if incentiveResolver.DistributedRewardAmount() != 0 || incentiveResolver.AccumulatedPenaltyAmount() != 0 {
		panic(makeErrorWithDetails(
			errCannotCancelIncentive,
			ufmt.Sprintf(
				"incentive(%s) has already accrued rewards: distributed(%d), penalty(%d)",
				incentiveResolver.IncentiveId(),
				incentiveResolver.DistributedRewardAmount(),
				incentiveResolver.AccumulatedPenaltyAmount(),
			),
		))
	}
}

// getMinimumIncentiveStartTimestamp returns after 24 hours from now.
func getMinimumIncentiveStartTimestamp() int64 {
	return time.Now().Add(24 * time.Hour).Unix()
}

// getMaximumIncentiveStartTimestamp returns 7 days after the first midnight that satisfies
// the minimum 24-hour delay.
func getMaximumIncentiveStartTimestamp() int64 {
	minimumStartTimestamp := getMinimumIncentiveStartTimestamp()
	firstEligibleMidnight := time.Unix(minimumStartTimestamp, 0).Truncate(24 * time.Hour)
	if firstEligibleMidnight.Unix() < minimumStartTimestamp {
		firstEligibleMidnight = firstEligibleMidnight.Add(24 * time.Hour)
	}

	return firstEligibleMidnight.Add(maxIncentiveStartDelay).Unix()
}

// assertIsValidIncentiveEndTime ensures the end timestamp is within valid epoch range.
func assertIsValidIncentiveEndTime(endTimestamp int64) {
	if endTimestamp >= MAX_UNIX_EPOCH_TIME {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("endTimestamp(%d) cannot be later than 253402300799 (9999-12-31 23:59:59)", endTimestamp),
		))
	}
}

// assertIsValidIncentiveDuration ensures the duration is 90, 180, or 365 days.
func assertIsValidIncentiveDuration(externalDuration int64) {
	switch externalDuration {
	case TIMESTAMP_90DAYS, TIMESTAMP_180DAYS, TIMESTAMP_365DAYS:
		return
	}

	panic(makeErrorWithDetails(
		errInvalidIncentiveDuration,
		ufmt.Sprintf("externalDuration(%d) must be 90, 180, 365 days", externalDuration),
	))
}

// AssertIsValidAddress panics if the provided address is invalid.
func assertIsValidAddress(addr address) {
	if addr == "" || !addr.IsValid() {
		panic(makeErrorWithDetails(
			errInvalidAddress,
			ufmt.Sprintf("address(%s) is invalid", addr.String()),
		))
	}
}

// isMidnight checks if a time represents midnight (00:00:00).
func isMidnight(startTime time.Time) bool {
	hour := startTime.Hour()
	minute := startTime.Minute()
	second := startTime.Second()

	return hour == 0 && minute == 0 && second == 0
}

// assertIsPositionOwner validates that the caller has permission to operate the token.
func assertIsPositionOwner(owner, caller address) {
	if owner != caller {
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner of positionId(%s)", caller, owner),
		))
	}
}
