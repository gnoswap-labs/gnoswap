package v1

import (
	"math"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
	sr "gno.land/r/gnoswap/staker"
)

const maxDurationOneYear = int64(365 * 86400) // 31,536,000 seconds

// expected to be called by governance
func modifyWarmup(warmupTemplate []sr.Warmup, index int, timeDuration int64) []sr.Warmup {
	if index >= len(warmupTemplate) {
		panic(ufmt.Sprintf("index(%d) is out of range", index))
	}

	// Handle negative duration - set to math.MaxInt64
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

func instantiateWarmup(warmupTemplate []sr.Warmup, currentTime int64) []sr.Warmup {
	warmups := make([]sr.Warmup, 0, len(warmupTemplate))
	for i, warmup := range warmupTemplate {
		nextWarmupTime := safeAddTime(currentTime, warmup.TimeDuration)

		warmups = append(warmups, sr.Warmup{
			Index:          warmup.Index,
			TimeDuration:   warmup.TimeDuration,
			NextWarmupTime: nextWarmupTime,
			WarmupRatio:    warmup.WarmupRatio,
		})

		// Only update currentTime if not the last tier
		if i < len(warmupTemplate)-1 {
			currentTime = safeAddTime(currentTime, warmup.TimeDuration)
		}
	}
	return warmups
}

func applyWarmup(warmup sr.Warmup, poolReward int64, positionLiquidity, stakedLiquidity *u256.Uint) (int64, int64) {
	if stakedLiquidity.IsZero() {
		return 0, 0
	}

	divisor := u256.NewUint(100)
	poolRewardUint := u256.NewUintFromInt64(poolReward)
	perPositionReward, overflow := u256.Zero().MulOverflow(poolRewardUint, positionLiquidity)
	if overflow {
		panic(errOverflow)
	}
	perPositionReward = u256.Zero().Div(perPositionReward, stakedLiquidity)

	penaltyRatio := u256.NewUint(100 - warmup.WarmupRatio)
	rewardRatio := u256.NewUint(warmup.WarmupRatio)
	totalReward, overflow := u256.Zero().MulOverflow(perPositionReward, rewardRatio)
	if overflow {
		panic(errOverflow)
	}
	totalReward = u256.Zero().Div(totalReward, divisor)

	totalPenalty, overflow := u256.Zero().MulOverflow(perPositionReward, penaltyRatio)
	if overflow {
		panic(errOverflow)
	}
	totalPenalty = u256.Zero().Div(totalPenalty, divisor)
	return safeConvertToInt64(totalReward), safeConvertToInt64(totalPenalty)
}

// safeAddTime performs safe addition with overflow protection
func safeAddTime(currentTime, duration int64) int64 {
	if duration == math.MaxInt64 {
		return math.MaxInt64
	}

	// Check for overflow before addition
	if currentTime > 0 && duration > math.MaxInt64-currentTime {
		return math.MaxInt64
	}

	return currentTime + duration
}
