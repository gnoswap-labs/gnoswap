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
// Parameters:
//   - amount: Signed token amount; values below zero panic as invalid input.
func assertIsValidAmount(amount int64) {
	if amount < 0 {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("amount(%d) must be positive", amount),
		))
	}
}

// assertIsValidRewardAmountFormat ensures the reward amount string is formatted as "tokenPath:amount".
// Parameters:
//   - rewardAmountStr: Reward specification expected in tokenPath:amount form; validation requires the colon delimiter.
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
// Parameters:
//   - s: Staker instance whose deposit store is checked.
//   - caller: Address that must own the requested deposit.
//   - positionId: Identifier of the deposit whose ownership is being asserted.
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

// assertIsIncentiveOfPool ensures the incentive targets the pool the position is staked in.
// Parameters:
//   - s: Staker instance containing the external incentive and deposit stores.
//   - poolPath: Pool in which the position is staked.
//   - positionId: Position identifier used in the mismatch diagnostic.
//   - incentiveId: External incentive identifier to resolve and validate.
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
// Parameters:
//   - s: Staker instance whose unstaked-position store is checked.
//   - positionId: Position identifier that must not have an outstanding exit checkpoint.
func assertHasNoExitCheckpoint(s *stakerV1, positionId uint64) {
	if s.HasUnstakedPosition(positionId) {
		panic(makeErrorWithDetails(
			errUncollectedPosition,
			ufmt.Sprintf("positionId(%d) still owes rewards from its previous stake; collect it first", positionId),
		))
	}
}

// assertHasNoUncollectedIncentive ensures no unstaked position still owes a reward from this
// incentive, which has not been drawn down from it yet.
// Parameters:
//   - s: Staker instance whose uncollected-incentive counts are checked.
//   - incentiveId: Incentive identifier whose outstanding position count must be zero.
func assertHasNoUncollectedIncentive(s *stakerV1, incentiveId string) {
	count := s.uncollectedIncentiveCountOf(incentiveId)
	if count > 0 {
		panic(makeErrorWithDetails(
			errUncollectedPosition,
			ufmt.Sprintf("incentive(%s) is owed to %d unstaked position(s)", incentiveId, count),
		))
	}
}

// assertIsNotStaked ensures the position is not already staked.
// Parameters:
//   - s: Staker instance whose deposit store is checked.
//   - positionId: Position identifier that must not already be present in deposits.
func assertIsNotStaked(s *stakerV1, positionId uint64) {
	if s.getDeposits().Has(positionId) {
		panic(makeErrorWithDetails(
			errAlreadyStaked,
			ufmt.Sprintf("positionId(%d) already staked", positionId),
		))
	}
}

// assertIsPoolExists ensures the pool exists.
// Parameters:
//   - s: Staker instance whose pool accessor is queried.
//   - poolPath: Pool path that must resolve to an existing pool.
func assertIsPoolExists(s *stakerV1, poolPath string) {
	if !s.poolAccessor.ExistsPoolPath(poolPath) {
		panic(makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("pool(%s) does not exist", poolPath),
		))
	}
}

// assertIsValidPoolTier ensures the tier is within valid range.
// Parameters:
//   - tier: Pool tier number; valid values are below AllTierCount.
func assertIsValidPoolTier(tier uint64) {
	if tier >= AllTierCount {
		panic(makeErrorWithDetails(
			errInvalidPoolTier,
			ufmt.Sprintf("tier(%d) must be less than %d", tier, AllTierCount),
		))
	}
}

// assertTier1HasSparePool ensures tier 1 keeps at least one pool after a tier change.
// Parameters:
//   - currentTier: Tier currently assigned to the pool, used to detect removal from tier 1.
//   - tier1Count: Number of pools currently assigned to tier 1.
func assertTier1HasSparePool(currentTier, tier1Count uint64) {
	if currentTier == Tier1 && tier1Count == 1 {
		panic(makeErrorWithDetails(errInvalidPoolTier, "tier 1 must have at least one pool"))
	}
}

// assertIsGreaterThanMinimumRewardAmount ensures the reward amount meets minimum requirements.
// Parameters:
//   - s: Staker instance providing global and token-specific minimum reward settings.
//   - rewardToken: Token path whose minimum reward override is looked up.
//   - rewardAmount: Proposed reward amount compared with the applicable minimum.
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
// Parameters:
//   - s: Staker instance providing the denied-token list and allowed-token list.
//   - poolPath: Pool path whose two constituent tokens are intrinsically eligible.
//   - tokenPath: Reward-token path that must be allowed and not denied.
func assertIsAllowedForExternalReward(s *stakerV1, poolPath, tokenPath string) {
	// Operational stop switch: a denied token can never start a NEW incentive,
	// whether it qualifies as a pool-pair token or through the governance
	// allowlist. Collection of already-created incentives is deliberately
	// unaffected; the delivery guard in deliverExternalIncentiveReward bounds
	// that blast radius instead.
	if contains(s.store.GetDeniedRewardTokens(), tokenPath) {
		panic(makeErrorWithDetails(
			errDeniedRewardToken,
			ufmt.Sprintf("tokenPath(%s) is denied as an external reward token", tokenPath),
		))
	}

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
// Parameters:
//   - s: Staker instance containing pool and external incentive state.
//   - poolPath: Pool whose unfinished incentives are searched.
//   - tokenPath: Reward-token path that must not have another unfinished incentive.
//   - currentTime: Current Unix timestamp used to determine whether an incentive has ended.
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
// Parameters:
//   - fee: Unstaking fee in basis points; values above 1000 (10%) are rejected.
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
// Parameters:
//   - startTimestamp: Incentive start time in Unix seconds; it must fall in the permitted future window at midnight.
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
// Parameters:
//   - caller: Address attempting to act on the incentive.
//   - creator: Address that funded or created the incentive and is therefore authorized.
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
// Parameters:
//   - incentiveResolver: Resolver exposing the incentive's start, refund, and accrued-reward state.
//   - currentTime: Current Unix timestamp used to determine whether the incentive has started.
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

// getMinimumIncentiveStartTimestamp returns the earliest permitted incentive start timestamp.
//
// Returns:
//   - int64: Unix timestamp exactly 24 hours after the current wall-clock time.
func getMinimumIncentiveStartTimestamp() int64 {
	return time.Now().Add(24 * time.Hour).Unix()
}

// getMaximumIncentiveStartTimestamp returns the latest permitted incentive start timestamp.
//
// Returns:
//   - int64: Unix timestamp seven days after the first midnight meeting the minimum 24-hour delay.
func getMaximumIncentiveStartTimestamp() int64 {
	minimumStartTimestamp := getMinimumIncentiveStartTimestamp()
	firstEligibleMidnight := time.Unix(minimumStartTimestamp, 0).Truncate(24 * time.Hour)
	if firstEligibleMidnight.Unix() < minimumStartTimestamp {
		firstEligibleMidnight = firstEligibleMidnight.Add(24 * time.Hour)
	}

	return firstEligibleMidnight.Add(maxIncentiveStartDelay).Unix()
}

// assertIsValidIncentiveEndTime ensures the end timestamp is within valid epoch range.
// Parameters:
//   - endTimestamp: Incentive end time in Unix seconds; it must be earlier than the maximum supported epoch.
func assertIsValidIncentiveEndTime(endTimestamp int64) {
	if endTimestamp >= MAX_UNIX_EPOCH_TIME {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("endTimestamp(%d) cannot be later than 253402300799 (9999-12-31 23:59:59)", endTimestamp),
		))
	}
}

// assertIsValidIncentiveDuration ensures the duration is 90, 180, or 365 days.
// Parameters:
//   - externalDuration: Incentive duration in seconds; only 90, 180, or 365 days are accepted.
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
// Parameters:
//   - addr: Address value to validate; empty or invalid addresses panic.
func assertIsValidAddress(addr address) {
	if addr == "" || !addr.IsValid() {
		panic(makeErrorWithDetails(
			errInvalidAddress,
			ufmt.Sprintf("address(%s) is invalid", addr.String()),
		))
	}
}

// isMidnight checks if a time represents midnight (00:00:00).
// Parameters:
//   - startTime: Time value whose hour, minute, and second must all be zero.
//
// Returns:
//   - bool: True when startTime's hour, minute, and second are all zero; false otherwise.
func isMidnight(startTime time.Time) bool {
	hour := startTime.Hour()
	minute := startTime.Minute()
	second := startTime.Second()

	return hour == 0 && minute == 0 && second == 0
}

// assertIsPositionOwner validates that the caller owns the position.
// Parameters:
//   - owner: Address recorded as the position owner.
//   - caller: Address attempting to operate the position; it must equal owner.
func assertIsPositionOwner(owner, caller address) {
	if owner != caller {
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner of positionId(%s)", caller, owner),
		))
	}
}
