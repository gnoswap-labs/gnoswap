package v1

import (
	"strconv"
	"strings"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/common"
)

const (
	TIMESTAMP_90DAYS  = int64(7776000)
	TIMESTAMP_180DAYS = int64(15552000)
	TIMESTAMP_365DAYS = int64(31536000)

	MAX_UNIX_EPOCH_TIME = 253402300799 // 9999-12-31 23:59:59
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

// assertIsNotStaked ensures the position is not already staked.
func assertIsNotStaked(s *stakerV1, positionId uint64) {
	if s.getDeposits().Has(positionId) {
		panic(makeErrorWithDetails(
			errAlreadyStaked,
			ufmt.Sprintf("positionId(%d) already staked", positionId),
		))
	}
}

// assertIsPositionOwner ensures the caller owns the position NFT.
func assertIsPositionOwner(s *stakerV1, positionId uint64, caller address) {
	owner := s.nftAccessor.MustOwnerOf(positionIdFrom(positionId))
	if owner != caller {
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner(%s)", caller.String(), owner.String()),
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

// assertIsGreaterThanMinimumRewardAmount ensures the reward amount meets minimum requirements.
func assertIsGreaterThanMinimumRewardAmount(s *stakerV1, rewardToken string, rewardAmount int64) {
	minReward := s.getMinimumRewardAmount()

	if minRewardI, found := s.store.GetTokenSpecificMinimumRewards().Get(rewardToken); found {
		minRewardInt64, ok := minRewardI.(int64)
		if !ok {
			panic(makeErrorWithDetails(
				errInvalidInput,
				ufmt.Sprintf("rewardToken(%s) is not int64", rewardToken),
			))
		}

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

const maxUnstakingFee = int64(1000) // 10%

// assertIsValidFeeRate ensures the fee rate is within valid range (0-1000 basis points).
func assertIsValidFeeRate(fee int64) {
	if fee < 0 || fee > maxUnstakingFee {
		panic(makeErrorWithDetails(
			errInvalidUnstakingFee,
			ufmt.Sprintf("fee(%d) must be in range 0 ~ %d", fee, maxUnstakingFee),
		))
	}
}

// assertIsValidIncentiveStartTime ensures the incentive starts at midnight of a future date.
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

	// must be at least +1 day midnight
	tomorrowMidnight := time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour).Unix()
	if startTimestamp < tomorrowMidnight {
		panic(makeErrorWithDetails(
			errInvalidIncentiveStartTime,
			ufmt.Sprintf("startTimestamp(%d) must be at least +1 day midnight(%d)", startTimestamp, tomorrowMidnight),
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

// isMidnight checks if a time represents midnight (00:00:00).
func isMidnight(startTime time.Time) bool {
	hour := startTime.Hour()
	minute := startTime.Minute()
	second := startTime.Second()

	return hour == 0 && minute == 0 && second == 0
}

func assertIsValidUserCoinSend(tokenPath string, amount int64) {
	if common.IsGNOTNativePath(tokenPath) {
		common.AssertIsUserSendGNOTAmount(amount)
	} else {
		common.AssertIsNotHandleNativeCoin()
	}
}
