package staker

import (
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/v1/gnft"
	pl "gno.land/r/gnoswap/v1/pool"
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
func assertIsDepositor(caller std.Address, positionId uint64) {
	deposit := deposits.get(positionId)
	if deposit == nil {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("positionId(%d) not found", positionId),
		))
	}

	if caller != deposit.owner {
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not depositor(%s)", caller.String(), deposit.owner.String()),
		))
	}
}

// assertIsNotStaked ensures the position is not already staked.
func assertIsNotStaked(positionId uint64) {
	if deposits.Has(positionId) {
		panic(makeErrorWithDetails(
			errAlreadyStaked,
			ufmt.Sprintf("positionId(%d) already staked", positionId),
		))
	}
}

// assertIsPositionOwner ensures the caller owns the position NFT.
func assertIsPositionOwner(positionId uint64, caller std.Address) {
	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	if owner != caller {
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner(%s)", caller.String(), owner.String()),
		))
	}
}

// assertIsPoolExists ensures the pool exists.
func assertIsPoolExists(poolPath string) {
	if !pl.ExistsPoolPath(poolPath) {
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
func assertIsGreaterThanMinimumRewardAmount(rewardToken string, rewardAmount int64) {
	minReward := GetMinimumRewardAmountForToken(rewardToken)
	if rewardAmount < minReward {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("rewardAmount(%d) is less than minimum required amount(%d)", rewardAmount, minReward),
		))
	}
}

// assertIsAllowedForExternalReward ensures the token is allowed for external rewards.
func assertIsAllowedForExternalReward(poolPath, tokenPath string) {
	token0, token1, _ := poolPathDivide(poolPath)

	if tokenPath == token0 || tokenPath == token1 {
		return
	}

	allowed := contains(allowedTokens, tokenPath)
	if allowed {
		return
	}

	panic(makeErrorWithDetails(
		errNotAllowedForExternalReward,
		ufmt.Sprintf("tokenPath(%s) is not allowed for external reward for poolPath(%s)", tokenPath, poolPath),
	))
}

// assertIsValidFeeRate ensures the fee rate is within valid range (0-10000 basis points).
func assertIsValidFeeRate(fee int64) {
	if fee < 0 || fee > 10000 {
		panic(makeErrorWithDetails(
			errInvalidUnstakingFee,
			ufmt.Sprintf("fee(%d) must be in range 0 ~ 10000", fee),
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
