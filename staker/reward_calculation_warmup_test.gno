package staker

import (
	"math"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestDefaultWarmupTemplate(t *testing.T) {
	warmups := DefaultWarmupTemplate()

	uassert.Equal(t, 4, len(warmups))

	uassert.Equal(t, uint64(30), warmups[0].WarmupRatio)
	uassert.Equal(t, uint64(50), warmups[1].WarmupRatio)
	uassert.Equal(t, uint64(70), warmups[2].WarmupRatio)
	uassert.Equal(t, uint64(100), warmups[3].WarmupRatio)
	uassert.Equal(t, int64(math.MaxInt64), warmups[3].BlockDuration)
}

func TestInstantiateWarmup(t *testing.T) {
	currentHeight := int64(1000)
	warmups := InstantiateWarmup(currentHeight)

	uassert.True(t, warmups[0].NextWarmupHeight > currentHeight)
	uassert.True(t, warmups[1].NextWarmupHeight > warmups[0].NextWarmupHeight)
}

func TestWarmupApply(t *testing.T) {
	warmup := Warmup{
		WarmupRatio: 30,
	}

	poolReward := uint64(1000)
	positionLiquidity := u256.NewUint(100)
	stakedLiquidity := u256.NewUint(200)

	reward, penalty := warmup.Apply(poolReward, positionLiquidity, stakedLiquidity)

	uassert.Equal(t, poolReward/2, reward+penalty)
	uassert.Equal(t, uint64(150), reward)
	uassert.Equal(t, uint64(350), penalty)
}

func TestWarmupApply2(t *testing.T) {
	tests := []struct {
		name        string
		warmupRatio uint64
		poolReward  uint64
		position    uint64
		staked      uint64
		expReward   uint64
		expPenalty  uint64
	}{
		{
			name:        "30% ratio",
			warmupRatio: 30,
			poolReward:  1000,
			position:    100,
			staked:      200,
			expReward:   150, // (1000 * 100/200) * 30% = 150
			expPenalty:  350, // (1000 * 100/200) * 70% = 350
		},
		{
			name:        "50% ratio",
			warmupRatio: 50,
			poolReward:  1000,
			position:    100,
			staked:      200,
			expReward:   250, // (1000 * 100/200) * 50% = 250
			expPenalty:  250, // (1000 * 100/200) * 50% = 250
		},
		{
			name:        "70% ratio",
			warmupRatio: 70,
			poolReward:  1000,
			position:    100,
			staked:      200,
			expReward:   350, // (1000 * 100/200) * 70% = 350
			expPenalty:  150, // (1000 * 100/200) * 30% = 150
		},
		{
			name:        "100% ratio",
			warmupRatio: 100,
			poolReward:  1000,
			position:    100,
			staked:      200,
			expReward:   500, // (1000 * 100/200) * 100% = 500
			expPenalty:  0,   // (1000 * 100/200) * 0% = 0
		},
		{
			name:        "big number",
			warmupRatio: 50,
			poolReward:  1000000,
			position:    1000,
			staked:      1000,
			expReward:   500000, // (1000000 * 1000/1000) * 50% = 500000
			expPenalty:  500000, // (1000000 * 1000/1000) * 50% = 500000
		},
	}

	for i, tt := range tests {
		t.Run(ufmt.Sprintf("Case %d: WarmupRatio %d%%", i, tt.warmupRatio), func(t *testing.T) {
			warmup := Warmup{
				WarmupRatio: tt.warmupRatio,
			}

			reward, penalty := warmup.Apply(
				tt.poolReward,
				u256.NewUint(tt.position),
				u256.NewUint(tt.staked),
			)

			uassert.Equal(t, tt.expReward, reward)
			uassert.Equal(t, tt.expPenalty, penalty)

			expectedTotal := tt.poolReward * tt.position / tt.staked
			uassert.Equal(t, expectedTotal, reward+penalty)
		})
	}
}

func TestWarmupBoundaryValues(t *testing.T) {
	warmup := Warmup{WarmupRatio: 50}
	maxReward := uint64(math.MaxUint64)
	minReward := uint64(0)

	position := u256.NewUint(1)
	staked := u256.NewUint(1)

	reward, penalty := warmup.Apply(maxReward, position, staked)
	uassert.Equal(t, maxReward/2, reward)

	// zero reward
	reward, penalty = warmup.Apply(0, position, staked)
	uassert.Equal(t, uint64(0), reward)
	uassert.Equal(t, uint64(0), penalty)
}

func TestFindWarmup(t *testing.T) {
	deposit := &Deposit{
		warmups: InstantiateWarmup(1000),
	}

	// check index of warmup
	uassert.Equal(t, 0, deposit.FindWarmup(1001))
	uassert.Equal(t, 3, deposit.FindWarmup(math.MaxInt64))
}

func TestLiquidityRatios(t *testing.T) {
	warmup := Warmup{WarmupRatio: 50}

	// expected reward is calculated by following formula:
	//
	// `finalReward = (position / staked) * totalReward * warmupRatio`
	tests := []struct {
		name     string
		position uint64
		staked   uint64
		reward   uint64
		expected uint64
	}{
		// Case 1: position(100) / staked(200) = 0.5
		// 50% of total reward 1000 is the base reward, which is 500
		// Apply WarmupRatio 50% => 500 * 0.5 = 250
		{"50% ratio", 100, 200, 1000, 250},

		// Case 2: position(200) / staked(100) = 2
		// Total reward 1000 * 2 = 2000 would be the base reward
		// However, can only receive up to maximum 1000
		// Apply WarmupRatio 50% => 1000 * 0.5 = 1000
		{"200% ratio", 200, 100, 1000, 1000},

		// Case 3: position(1) / staked(1000) = 0.001
		// Total reward 1000 * 0.001 = 1 is the base reward
		// Apply WarmupRatio 50% to this => 1 * 0.5 = 0 (floor)
		{"small ratio", 1, 1000, 1000, 0},

		// Case 4: position(1000) / staked(1) = 1000
		// Total reward 1000 * 1000 is the base reward
		// Apply WarmupRatio 50% to this => 1000000 * 0.5 = 500000
		{"large ratio", 1000, 1, 1000, 500000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			reward, _ := warmup.Apply(
				tt.reward,
				u256.NewUint(tt.position),
				u256.NewUint(tt.staked),
			)
			uassert.Equal(t, tt.expected, reward)
		})
	}
}

func TestWarmupTransitions(t *testing.T) {
	currentHeight := int64(1000)
	deposit := &Deposit{
		warmups: InstantiateWarmup(currentHeight),
	}

	transitions := []struct {
		height        int64
		expectedIndex int
	}{
		{currentHeight - 1, 0},
		{currentHeight, 0},
		{currentHeight + 1, 0},
		{deposit.warmups[0].NextWarmupHeight - 1, 0},
		{deposit.warmups[0].NextWarmupHeight, 1},
		{deposit.warmups[1].NextWarmupHeight, 2},
		{deposit.warmups[2].NextWarmupHeight, 3},
	}

	for _, tt := range transitions {
		uassert.Equal(t, tt.expectedIndex, deposit.FindWarmup(tt.height))
	}
}

func TestModifyWarmup(t *testing.T) {
	originalTemplate := DefaultWarmupTemplate()

	t.Run("modify warmup with valid index", func(t *testing.T) {
		modifyWarmup(0, 1000)
		uassert.Equal(t, int64(1000), warmupTemplate[0].BlockDuration)
	})

	t.Run("modify warmup with negative block duration", func(t *testing.T) {
		modifyWarmup(0, -1000)
		instantiated := InstantiateWarmup(0)
		uassert.Equal(t, int64(math.MaxInt64), instantiated[0].NextWarmupHeight)
	})

	t.Run("modify warmup with out range index", func(t *testing.T) {
		defer func() {
			if r := recover(); r != nil {
				t.Logf("Recovered from panic: %v", r)
			}
		}()
		modifyWarmup(len(warmupTemplate), 1000)
	})
}

func TestRewardCalculationPrecision(t *testing.T) {
	warmup := Warmup{WarmupRatio: 33} // possible decimal point

	cases := []struct {
		name            string
		reward          uint64
		expectedReward  uint64
		expectedPenalty uint64
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
			reward, penalty := warmup.Apply(tt.reward, position, staked)
			uassert.Equal(t, tt.expectedReward, reward)
			uassert.Equal(t, tt.expectedPenalty, penalty)
			// consider rounding error
			uassert.True(t, math.Abs(float64(tt.reward)-float64(reward+penalty)) <= 1)
		})
	}
}
