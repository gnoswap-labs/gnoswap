package staker

import (
	"math"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

const maxDurationOneYear = int64(365 * 86400) // 31,536,000 seconds

type Warmup struct {
	Index          int
	TimeDuration   int64
	NextWarmupTime int64 // time when this warmup period ends
	WarmupRatio    uint64
}

// warmupTemplate defines the warmup periods for staking rewards.
// These parameters can be modified through governance via SetWarmUp.
var warmupTemplate []Warmup = DefaultWarmupTemplate()

func DefaultWarmupTemplate() []Warmup {
	secondsInDay := int64(86400)
	secondsIn5Days := int64(5 * secondsInDay)
	secondsIn10Days := int64(10 * secondsInDay)
	secondsIn30Days := int64(30 * secondsInDay)

	// NextWarmupTime is set to 0 for template.
	// They will be set by InstantiateWarmup()
	return []Warmup{
		{
			Index:        0,
			TimeDuration: secondsIn5Days,
			// NextWarmupTime will be set based on currentTime
			// NextWarmupTime: currentTime + secondsIn5Days,
			WarmupRatio: 30,
		},
		{
			Index:        1,
			TimeDuration: secondsIn10Days,
			// NextWarmupTime will be set based on currentTime
			// NextWarmupTime: currentTime + secondsIn10Days,
			WarmupRatio: 50,
		},
		{
			Index:        2,
			TimeDuration: secondsIn30Days,
			// NextWarmupTime will be set based on currentTime
			// NextWarmupTime: currentTime + secondsIn30Days,
			WarmupRatio: 70,
		},
		{
			Index:        3,
			TimeDuration: math.MaxInt64,
			// NextWarmupTime will be set to math.MaxInt64
			// NextWarmupTime: math.MaxInt64,
			WarmupRatio: 100,
		},
	}
}

// expected to be called by governance
func modifyWarmup(index int, timeDuration int64) {
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
		return
	}

	// Limit non-final tier durations to 1 year (365 days)
	if timeDuration > maxDurationOneYear {
		panic(ufmt.Sprintf("warmup duration cannot exceed 1 year (365 days), got %d seconds", timeDuration))
	}

	warmupTemplate[index].TimeDuration = timeDuration
}

func instantiateWarmup(currentTime int64) []Warmup {
	warmups := make([]Warmup, 0)
	for i, warmup := range warmupTemplate {
		nextWarmupTime := safeAddTime(currentTime, warmup.TimeDuration)

		warmups = append(warmups, Warmup{
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

func (warmup *Warmup) apply(poolReward int64, positionLiquidity, stakedLiquidity *u256.Uint) (int64, int64) {
	if stakedLiquidity.IsZero() {
		return 0, 0
	}

	divisor := u256.NewUint(100)
	poolRewardUint := u256.NewUintFromInt64(poolReward)
	perPositionReward := u256.Zero().Mul(poolRewardUint, positionLiquidity)
	perPositionReward = u256.Zero().Div(perPositionReward, stakedLiquidity)
	rewardRatio := u256.NewUint(warmup.WarmupRatio)
	penaltyRatio := u256.NewUint(100 - warmup.WarmupRatio)
	totalReward := u256.Zero().Mul(perPositionReward, rewardRatio)
	totalReward = u256.Zero().Div(totalReward, divisor)
	totalPenalty := u256.Zero().Mul(perPositionReward, penaltyRatio)
	totalPenalty = u256.Zero().Div(totalPenalty, divisor)
	return safeConvertToInt64(totalReward), safeConvertToInt64(totalPenalty)
}

func (self *Deposit) FindWarmup(currentTime int64) int {
	for i, warmup := range self.warmups {
		if currentTime < warmup.NextWarmupTime {
			return i
		}
	}
	return len(self.warmups) - 1
}

func (self *Deposit) GetWarmup(index int) Warmup {
	return self.warmups[index]
}
