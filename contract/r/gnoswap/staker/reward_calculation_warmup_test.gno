package staker

import (
	"math"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/gns"
)

func createWarmup(ratio uint64) Warmup {
	return Warmup{WarmupRatio: ratio}
}

func assertRewardPenalty(t *testing.T, expected, actual int64, label string) {
	t.Helper()
	uassert.Equal(t, expected, actual, ufmt.Sprintf("%s mismatch: expected %d, got %d", label, expected, actual))
}

func TestDefaultWarmupTemplate(t *testing.T) {
	warmups := DefaultWarmupTemplate()

	expectedRatios := []uint64{30, 50, 70, 100}
	uassert.Equal(t, len(expectedRatios), len(warmups))

	for i, expected := range expectedRatios {
		uassert.Equal(t, expected, warmups[i].WarmupRatio)
	}
	uassert.Equal(t, int64(math.MaxInt64), warmups[3].BlockDuration)
}

func TestInstantiateWarmup(t *testing.T) {
	currentHeight := int64(1000)
	warmups := instantiateWarmup(currentHeight)

	for i := 0; i < len(warmups)-1; i++ {
		uassert.True(t, warmups[i].NextWarmupHeight > currentHeight)
		uassert.True(t, warmups[i+1].NextWarmupHeight > warmups[i].NextWarmupHeight)
	}
}

func TestWarmupApply(t *testing.T) {
	tests := []struct {
		name        string
		warmupRatio uint64
		poolReward  int64
		position    uint64
		staked      uint64
	}{
		{"30% ratio", 30, 1000, 100, 200},
		{"50% ratio", 50, 1000, 100, 200},
		{"70% ratio", 70, 1000, 100, 200},
		{"100% ratio", 100, 1000, 100, 200},
		{"big numbers", 50, 1000000, 1000, 1000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			warmup := createWarmup(tt.warmupRatio)

			reward, penalty := warmup.apply(
				tt.poolReward,
				u256.NewUint(tt.position),
				u256.NewUint(tt.staked),
			)

			// Calculate expected values
			baseReward := tt.poolReward * int64(tt.position) / int64(tt.staked)
			expectedReward := baseReward * int64(tt.warmupRatio) / 100
			expectedPenalty := baseReward - expectedReward

			assertRewardPenalty(t, expectedReward, reward, "Reward")
			assertRewardPenalty(t, expectedPenalty, penalty, "Penalty")
			uassert.Equal(t, baseReward, reward+penalty)
		})
	}
}

func TestWarmupEdgeCases(t *testing.T) {
	tests := []struct {
		name     string
		ratio    uint64
		reward   int64
		position uint64
		staked   uint64
	}{
		{"max reward", 50, math.MaxInt64, 1, 1},
		{"zero reward", 50, 0, 1, 1},
		{"small position large staked", 50, 1000, 1, 1000},
		{"large position small staked", 50, 1000, 1000, 1},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			warmup := createWarmup(tt.ratio)
			position := u256.NewUint(tt.position)
			staked := u256.NewUint(tt.staked)

			reward, penalty := warmup.apply(tt.reward, position, staked)

			// Verify total doesn't exceed original reward
			if tt.reward > 0 && tt.position <= tt.staked {
				uassert.True(t, reward+penalty <= tt.reward)
			}
		})
	}
}

func TestFindWarmup(t *testing.T) {
	deposit := &Deposit{
		warmups: instantiateWarmup(1000),
	}

	tests := []struct {
		height        int64
		expectedIndex int
	}{
		{1001, 0},
		{deposit.warmups[0].NextWarmupHeight - 1, 0},
		{deposit.warmups[0].NextWarmupHeight, 1},
		{deposit.warmups[1].NextWarmupHeight, 2},
		{deposit.warmups[2].NextWarmupHeight, 3},
		{math.MaxInt64, 3},
	}

	for _, tt := range tests {
		t.Run(ufmt.Sprintf("height_%d", tt.height), func(t *testing.T) {
			uassert.Equal(t, tt.expectedIndex, deposit.FindWarmup(tt.height))
		})
	}
}

func TestRewardCalculationPrecision(t *testing.T) {
	warmup := createWarmup(33) // possible decimal point

	cases := []struct {
		name            string
		reward          int64
		expectedReward  int64
		expectedPenalty int64
	}{
		// reward: 100
		// Reward calculation: 100 * (33/100) = 33
		// Penalty calculation: 100 * (67/100) = 67
		{"small", 100, 33, 67},

		// reward: 1000
		// Reward calculation: 1000 * (33/100) = 330
		// Penalty calculation: 1000 * (67/100) = 670
		{"medium", 1000, 330, 670},

		// Step 1: Per Position Reward calculation
		// perPositionReward = poolReward * positionLiquidity / stakedLiquidity
		// perPositionReward = 999 * 1 / 1 = 999
		//
		// Step 2: Reward calculation with WarmupRatio(33%)
		// totalReward = perPositionReward * rewardRatio / 100
		// totalReward = 999 * 33 / 100 = 329.67 (floor => 329)
		//
		// Step 3: Penalty calculation with PenaltyRatio(67%)
		// totalPenalty = perPositionReward * penaltyRatio / 100
		// totalPenalty = 999 * 67 / 100 = 669.33 (floor => 669)
		{"division rounding", 999, 329, 669},
	}

	position := u256.NewUint(1)
	staked := u256.NewUint(1)

	for _, tt := range cases {
		t.Run(tt.name, func(t *testing.T) {
			reward, penalty := warmup.apply(tt.reward, position, staked)
			uassert.Equal(t, tt.expectedReward, reward)
			uassert.Equal(t, tt.expectedPenalty, penalty)
			// consider rounding error
			uassert.True(t, math.Abs(float64(tt.reward)-float64(reward+penalty)) <= 1)
		})
	}
}

func TestModifyWarmup(t *testing.T) {
	tests := []struct {
		name          string
		index         int
		duration      int64
		shouldPanic   bool
		expectedValue int64
	}{
		{"valid index", 0, 1000, false, 1000},
		{"negative duration", 0, -1000, false, math.MaxInt64},
		{"out of range index", 10, 1000, true, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotNil(t, r, "Expected panic but none occurred")
				}()
			}

			modifyWarmup(tt.index, tt.duration)

			if !tt.shouldPanic {
				if tt.duration < 0 {
					instantiated := instantiateWarmup(0)
					uassert.Equal(t, tt.expectedValue, instantiated[tt.index].NextWarmupHeight)
				} else {
					uassert.Equal(t, tt.expectedValue, warmupTemplate[tt.index].BlockDuration)
				}
			}
		})
	}
}

func TestMultipleWarmupPeriods(t *testing.T) {
	msInDay := int64(86400000)
	blocksInDay := msInDay / int64(gns.AvgBlockTimeInMs())
	baseRewardPerBlock := int64(50)

	// warmup period configurations
	type warmupPeriod struct {
		days  int64
		ratio uint64
	}

	tests := []struct {
		name     string
		periods  []warmupPeriod
		position uint64
		staked   uint64
	}{
		{
			name: "7 days staking",
			periods: []warmupPeriod{
				{5, 30}, // 5 days at 30%
				{2, 50}, // 2 days at 50%
			},
			position: 1000,
			staked:   2000,
		},
		{
			name: "40 days staking",
			periods: []warmupPeriod{
				{5, 30},   // 0-5 days at 30%
				{5, 50},   // 6-10 days at 50%
				{20, 70},  // 11-30 days at 70%
				{10, 100}, // 31-40 days at 100%
			},
			position: 1000,
			staked:   2000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			startHeight := int64(1000)
			testing.SkipHeights(startHeight)

			deposit := &Deposit{
				warmups: instantiateWarmup(startHeight),
			}

			position := u256.NewUint(tt.position)
			staked := u256.NewUint(tt.staked)

			var totalReward int64
			positionRatio := float64(tt.position) / float64(tt.staked)

			for i, period := range tt.periods {
				blocks := period.days * blocksInDay
				totalBlockReward := baseRewardPerBlock * blocks

				reward, _ := deposit.warmups[i].apply(
					totalBlockReward,
					position,
					staked,
				)

				expectedReward := int64(float64(totalBlockReward) * positionRatio * float64(period.ratio) / 100)
				assertRewardPenalty(t, expectedReward, reward, ufmt.Sprintf("Period %d reward", i))

				totalReward += reward
				testing.SkipHeights(blocks)
			}
		})
	}
}
