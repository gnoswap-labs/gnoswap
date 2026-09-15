package staker

import (
	"errors"
	"math"

	"gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"
	sr "gno.land/r/gnoswap/staker"
)

const maxDurationOneYear = int64(365 * 86400) // 31,536,000 seconds

// modifyWarmup updates one warmup tier duration while enforcing schedule bounds; it is expected to be called by governance.
//
// Parameters:
//   - warmupTemplate: Warmup tiers to modify.
//   - index: Zero-based tier index to update; out-of-range values panic.
//   - timeDuration: New tier duration in seconds; non-final tiers are limited to one year and the final tier must use math.MaxInt64.
//
// Returns:
//   - warmups: The warmup template with the selected tier's duration updated; the final tier is returned unchanged.
func modifyWarmup(warmupTemplate []sr.Warmup, index int, timeDuration int64) []sr.Warmup {
	if index >= len(warmupTemplate) {
		panic(ufmt.Sprintf("index(%d) is out of range", index))
	}

	// Handle negative duration - panic with error
	if timeDuration < 0 {
		panic(ufmt.Sprintf("warmup duration cannot be negative, got %d seconds", timeDuration))
	}

	// Early return for last tier - must always be math.MaxInt64
	if index == len(warmupTemplate)-1 {
		if timeDuration != math.MaxInt64 {
			panic(ufmt.Sprintf("last warmup tier must have duration of math.MaxInt64, got %d", timeDuration))
		}
		// No modification needed as it's already math.MaxInt64
		return warmupTemplate
	}

	// Limit non-final tier durations to 1 year (365 days)
	if timeDuration > maxDurationOneYear {
		panic(ufmt.Sprintf("warmup duration cannot exceed 1 year (365 days), got %d seconds", timeDuration))
	}

	warmupTemplate[index].SetTimeDuration(timeDuration)

	return warmupTemplate
}

// instantiateWarmup creates a position-specific warmup schedule from a template.
//
// Parameters:
//   - warmupTemplate: Template tiers whose durations and ratios define the schedule.
//   - currentTime: Position start time in Unix seconds from which tier end times are calculated.
//
// Returns:
//   - warmups: New warmup slice with cumulative NextWarmupTime values derived from currentTime.
func instantiateWarmup(warmupTemplate []sr.Warmup, currentTime int64) []sr.Warmup {
	warmups := make([]sr.Warmup, 0, len(warmupTemplate))
	for i, warmup := range warmupTemplate {
		nextWarmupTime := safeAddTime(currentTime, warmup.TimeDuration)

		warmups = append(warmups, sr.NewWarmup(warmup.TimeDuration, nextWarmupTime, warmup.WarmupRatio))

		// Only update currentTime if not the last tier
		if i < len(warmupTemplate)-1 {
			currentTime = safeAddTime(currentTime, warmup.TimeDuration)
		}
	}
	return warmups
}

// applyWarmup splits a position's proportional pool reward into credited reward and warmup penalty.
//
// Parameters:
//   - warmup: Warmup tier whose ratio determines the reward/penalty split.
//   - poolReward: Reward amount available for the pool interval in token smallest units.
//   - positionLiquidity: Position liquidity used to determine its share of poolReward.
//   - stakedLiquidity: Total in-range staked liquidity used as the allocation denominator; zero yields two zero results.
//
// Returns:
//   - reward: Position reward after applying warmup.WarmupRatio percent.
//   - penalty: Portion withheld by the warmup, equal to the complementary percentage.
func applyWarmup(warmup sr.Warmup, poolReward int64, positionLiquidity, stakedLiquidity *u256.Uint) (int64, int64) {
	if stakedLiquidity.IsZero() {
		return 0, 0
	}

	divisor := u256.NewUint(100)
	poolRewardUint := u256.NewUintFromInt64(poolReward)
	perPositionReward, overflow := u256.Zero().MulOverflow(poolRewardUint, positionLiquidity)
	if overflow {
		panic(errors.New(errOverflow))
	}
	perPositionReward = u256.Zero().Div(perPositionReward, stakedLiquidity)

	penaltyRatio := u256.NewUint(100 - warmup.WarmupRatio)
	rewardRatio := u256.NewUint(warmup.WarmupRatio)
	totalReward, overflow := u256.Zero().MulOverflow(perPositionReward, rewardRatio)
	if overflow {
		panic(errors.New(errOverflow))
	}
	totalReward = u256.Zero().Div(totalReward, divisor)

	totalPenalty, overflow := u256.Zero().MulOverflow(perPositionReward, penaltyRatio)
	if overflow {
		panic(errors.New(errOverflow))
	}
	totalPenalty = u256.Zero().Div(totalPenalty, divisor)
	return gnsmath.SafeConvertToInt64(totalReward), gnsmath.SafeConvertToInt64(totalPenalty)
}

// safeAddTime performs safe addition with overflow protection
//
// Parameters:
//   - currentTime: Base timestamp in Unix seconds.
//   - duration: Duration in seconds to add; math.MaxInt64 is treated as an unbounded end time.
//
// Returns:
//   - endTime: Checked sum of currentTime and duration, saturated at math.MaxInt64 for the unbounded duration or positive overflow.
func safeAddTime(currentTime, duration int64) int64 {
	if duration == math.MaxInt64 {
		return math.MaxInt64
	}

	// Check for overflow before addition
	if currentTime > 0 && duration > math.MaxInt64-currentTime {
		return math.MaxInt64
	}

	return gnsmath.SafeAddInt64(currentTime, duration)
}
