package v1

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/staker"
	sr "gno.land/r/gnoswap/staker"
)

// Test NewPools constructor
func TestNewPools(t *testing.T) {
	pools := NewPools()

	uassert.NotNil(t, pools)
	uassert.NotNil(t, pools.tree)
}

// Test Pools Get and set operations
func TestPoolsGetSet(t *testing.T) {
	tests := []struct {
		name      string
		poolPath  string
		shouldSet bool
	}{
		{
			name:      "set and get pool",
			poolPath:  "pool1",
			shouldSet: true,
		},
		{
			name:      "get non-existent pool",
			poolPath:  "nonexistent",
			shouldSet: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pools := NewPools()
			currentTime := time.Now().Unix()

			if tt.shouldSet {
				pool := sr.NewPool(tt.poolPath, currentTime)
				pools.set(tt.poolPath, pool)

				retrieved, ok := pools.Get(tt.poolPath)
				uassert.True(t, ok)
				uassert.NotNil(t, retrieved)
				uassert.Equal(t, tt.poolPath, retrieved.PoolPath())
			} else {
				_, ok := pools.Get(tt.poolPath)
				uassert.False(t, ok)
			}
		})
	}
}

// Test GetPoolOrNil
func TestGetPoolOrNil(t *testing.T) {
	tests := []struct {
		name        string
		poolPath    string
		shouldExist bool
	}{
		{
			name:        "existing pool returns pool",
			poolPath:    "existing",
			shouldExist: true,
		},
		{
			name:        "non-existing pool returns nil",
			poolPath:    "nonexisting",
			shouldExist: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pools := NewPools()
			currentTime := time.Now().Unix()

			// Verify pools is empty initially
			uassert.Equal(t, 0, pools.tree.Size())

			if tt.shouldExist {
				pool := sr.NewPool(tt.poolPath, currentTime)
				pools.set(tt.poolPath, pool)
			}

			result := pools.GetPoolOrNil(tt.poolPath)

			if tt.shouldExist {
				uassert.NotNil(t, result)
			} else {
				// Use direct nil check instead of uassert.Nil to avoid interface nil issues
				if result != nil {
					t.Errorf("Expected nil but got: %#v", result)
				}
			}
		})
	}
}

// Test Pools Has operation
func TestPoolsHas(t *testing.T) {
	tests := []struct {
		name      string
		poolPath  string
		shouldAdd bool
		expected  bool
	}{
		{
			name:      "has existing pool",
			poolPath:  "test_pool",
			shouldAdd: true,
			expected:  true,
		},
		{
			name:      "has non-existing pool",
			poolPath:  "missing_pool",
			shouldAdd: false,
			expected:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pools := NewPools()
			currentTime := time.Now().Unix()

			if tt.shouldAdd {
				pool := sr.NewPool(tt.poolPath, currentTime)
				pools.set(tt.poolPath, pool)
			}

			result := pools.Has(tt.poolPath)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

// Test NewPoolResolver
func TestNewPoolResolver(t *testing.T) {
	tests := []struct {
		name     string
		poolPath string
	}{
		{
			name:     "create resolver for pool",
			poolPath: "test_pool",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			currentTime := time.Now().Unix()
			pool := sr.NewPool(tt.poolPath, currentTime)
			resolver := NewPoolResolver(pool)

			uassert.NotNil(t, resolver)
			uassert.NotNil(t, resolver.Pool)
		})
	}
}

// Test IncentivesResolver
func TestIncentivesResolverFromPool(t *testing.T) {
	tests := []struct {
		name     string
		poolPath string
	}{
		{
			name:     "get incentives resolver",
			poolPath: "test_pool",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			currentTime := time.Now().Unix()
			pool := sr.NewPool(tt.poolPath, currentTime)
			poolResolver := NewPoolResolver(pool)

			incentivesResolver := poolResolver.IncentivesResolver()
			uassert.NotNil(t, incentivesResolver)
		})
	}
}

// Test CurrentGlobalRewardRatioAccumulation
func TestCurrentGlobalRewardRatioAccumulation(t *testing.T) {
	tests := []struct {
		name        string
		poolPath    string
		currentTime int64
	}{
		{
			name:        "get initial accumulation",
			poolPath:    "test_pool",
			currentTime: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := sr.NewPool(tt.poolPath, tt.currentTime)
			poolResolver := NewPoolResolver(pool)

			timestamp, acc := poolResolver.CurrentGlobalRewardRatioAccumulation(tt.currentTime)

			uassert.NotNil(t, acc)
			uassert.True(t, timestamp >= 0)
		})
	}
}

// Test CurrentTick
func TestCurrentTick(t *testing.T) {
	tests := []struct {
		name                 string
		poolPath             string
		setupHistoricalTicks func(poolResolver *PoolResolver)
		currentTime          int64
		expectedTick         int32
		expectedPanic        bool
		expectedPanicMessage string
	}{
		{
			name:     "get current tick by valid historical ticks",
			poolPath: "test_pool",
			setupHistoricalTicks: func(poolResolver *PoolResolver) {
				historicalTicks := staker.NewUintTree()
				historicalTicks.Set(1, int32(1))
				historicalTicks.Set(2, int32(2))
				historicalTicks.Set(3, int32(3))

				poolResolver.Pool.SetHistoricalTick(historicalTicks)
			},
			currentTime:          1000,
			expectedTick:         3,
			expectedPanic:        false,
			expectedPanicMessage: "",
		},
		{
			name:     "get current tick by valid historical ticks",
			poolPath: "test_pool",
			setupHistoricalTicks: func(poolResolver *PoolResolver) {
				historicalTicks := staker.NewUintTree()
				historicalTicks.Set(1, int32(1))
				historicalTicks.Set(2, int32(2))
				historicalTicks.Set(3, int32(3))
				historicalTicks.Set(1001, int32(3))

				poolResolver.Pool.SetHistoricalTick(historicalTicks)
			},
			currentTime:          1000,
			expectedTick:         3,
			expectedPanic:        false,
			expectedPanicMessage: "",
		},
		{
			name:     "get current tick by invalid historical ticks (int64 type)",
			poolPath: "test_pool",
			setupHistoricalTicks: func(poolResolver *PoolResolver) {
				historicalTicks := staker.NewUintTree()
				historicalTicks.Set(1, int64(1))
				historicalTicks.Set(2, int64(2))
				historicalTicks.Set(3, int64(3))

				poolResolver.Pool.SetHistoricalTick(historicalTicks)
			},
			currentTime:          1000,
			expectedPanic:        true,
			expectedPanicMessage: "failed to cast value to int32: int64",
		},
		{
			name:     "get current tick by invalid historical ticks (string type)",
			poolPath: "test_pool",
			setupHistoricalTicks: func(poolResolver *PoolResolver) {
				historicalTicks := staker.NewUintTree()
				historicalTicks.Set(1, "1")
				historicalTicks.Set(2, "2")
				historicalTicks.Set(3, "3")

				poolResolver.Pool.SetHistoricalTick(historicalTicks)
			},
			currentTime:          1000,
			expectedTick:         3,
			expectedPanic:        true,
			expectedPanicMessage: "failed to cast value to int32: string",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := sr.NewPool(tt.poolPath, tt.currentTime)
			poolResolver := NewPoolResolver(pool)

			if tt.setupHistoricalTicks != nil {
				tt.setupHistoricalTicks(poolResolver)
			}

			if tt.expectedPanic {
				uassert.PanicsContains(t, tt.expectedPanicMessage, func() {
					poolResolver.CurrentTick(tt.currentTime)
				})
			} else {
				tick := poolResolver.CurrentTick(tt.currentTime)
				uassert.Equal(t, tt.expectedTick, tick)
			}
		})
	}
}

// Test CurrentStakedLiquidity
func TestCurrentStakedLiquidity(t *testing.T) {
	tests := []struct {
		name        string
		poolPath    string
		currentTime int64
	}{
		{
			name:        "get initial staked liquidity (should be zero)",
			poolPath:    "test_pool",
			currentTime: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := sr.NewPool(tt.poolPath, tt.currentTime)
			poolResolver := NewPoolResolver(pool)

			liquidity := poolResolver.CurrentStakedLiquidity(tt.currentTime)

			uassert.NotNil(t, liquidity)
			uassert.True(t, liquidity.IsZero())
		})
	}
}

// Test CurrentReward
func TestCurrentRewardPool(t *testing.T) {
	tests := []struct {
		name        string
		poolPath    string
		currentTime int64
	}{
		{
			name:        "get initial reward (should be zero)",
			poolPath:    "test_pool",
			currentTime: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := sr.NewPool(tt.poolPath, tt.currentTime)
			poolResolver := NewPoolResolver(pool)

			reward := poolResolver.CurrentReward(tt.currentTime)
			uassert.Equal(t, int64(0), reward)
		})
	}
}

// Test cacheReward
func TestCacheRewardPool(t *testing.T) {
	tests := []struct {
		name              string
		poolPath          string
		currentTime       int64
		currentTierReward int64
	}{
		{
			name:              "cache reward with value",
			poolPath:          "test_pool",
			currentTime:       1000,
			currentTierReward: 5000,
		},
		{
			name:              "cache zero reward",
			poolPath:          "test_pool",
			currentTime:       2000,
			currentTierReward: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := sr.NewPool(tt.poolPath, tt.currentTime)
			poolResolver := NewPoolResolver(pool)

			poolResolver.cacheReward(tt.currentTime, tt.currentTierReward)

			reward := poolResolver.CurrentReward(tt.currentTime)
			uassert.Equal(t, tt.currentTierReward, reward)
		})
	}
}

// Test cacheInternalReward
func TestCacheInternalReward(t *testing.T) {
	tests := []struct {
		name            string
		poolPath        string
		currentTime     int64
		currentEmission int64
	}{
		{
			name:            "cache internal reward",
			poolPath:        "test_pool",
			currentTime:     1000,
			currentEmission: 10000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := sr.NewPool(tt.poolPath, tt.currentTime)
			poolResolver := NewPoolResolver(pool)

			poolResolver.cacheInternalReward(tt.currentTime, tt.currentEmission)

			reward := poolResolver.CurrentReward(tt.currentTime)
			uassert.Equal(t, tt.currentEmission, reward)
		})
	}
}

// Test calculateGlobalRewardRatioAccumulation
func TestCalculateGlobalRewardRatioAccumulation(t *testing.T) {
	tests := []struct {
		name                   string
		poolPath               string
		currentTime            int64
		currentStakedLiquidity *u256.Uint
	}{
		{
			name:                   "zero liquidity returns same accumulation",
			poolPath:               "test_pool",
			currentTime:            1000,
			currentStakedLiquidity: u256.Zero(),
		},
		{
			name:                   "non-zero liquidity",
			poolPath:               "test_pool",
			currentTime:            2000,
			currentStakedLiquidity: u256.NewUintFromInt64(1000),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := sr.NewPool(tt.poolPath, tt.currentTime)
			poolResolver := NewPoolResolver(pool)

			acc := poolResolver.calculateGlobalRewardRatioAccumulation(tt.currentTime, tt.currentStakedLiquidity)

			uassert.NotNil(t, acc)
		})
	}
}

// Test updateGlobalRewardRatioAccumulation
func TestUpdateGlobalRewardRatioAccumulation(t *testing.T) {
	tests := []struct {
		name                   string
		poolPath               string
		currentTime            int64
		currentStakedLiquidity *u256.Uint
	}{
		{
			name:                   "update with zero liquidity",
			poolPath:               "test_pool",
			currentTime:            1000,
			currentStakedLiquidity: u256.Zero(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := sr.NewPool(tt.poolPath, tt.currentTime)
			poolResolver := NewPoolResolver(pool)

			newAcc := poolResolver.updateGlobalRewardRatioAccumulation(tt.currentTime, tt.currentStakedLiquidity)

			uassert.NotNil(t, newAcc)
		})
	}
}

// Test RewardStateOf
func TestRewardStateOf(t *testing.T) {
	tests := []struct {
		name       string
		poolPath   string
		numWarmups int
	}{
		{
			name:       "create reward state with single warmup",
			poolPath:   "test_pool",
			numWarmups: 1,
		},
		{
			name:       "create reward state with multiple warmups",
			poolPath:   "test_pool",
			numWarmups: 4,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			currentTime := time.Now().Unix()
			pool := sr.NewPool(tt.poolPath, currentTime)
			poolResolver := NewPoolResolver(pool)

			warmups := make([]sr.Warmup, tt.numWarmups)
			for i := 0; i < tt.numWarmups; i++ {
				warmups[i] = sr.Warmup{
					WarmupRatio:    30 + uint64(i*20),
					NextWarmupTime: currentTime + int64(i*86400),
				}
			}

			deposit := sr.NewDeposit(
				testutils.TestAddress("owner"),
				tt.poolPath,
				u256.NewUintFromInt64(1000),
				currentTime,
				int32(0),
				int32(100),
				warmups,
			)

			rewardState := poolResolver.RewardStateOf(deposit)

			uassert.NotNil(t, rewardState)
			uassert.Equal(t, tt.numWarmups, len(rewardState.rewards))
			uassert.Equal(t, tt.numWarmups, len(rewardState.penalties))
		})
	}
}

// Test startUnclaimablePeriod and endUnclaimablePeriod
func TestUnclaimablePeriod(t *testing.T) {
	tests := []struct {
		name        string
		poolPath    string
		currentTime int64
	}{
		{
			name:        "start and end unclaimable period",
			poolPath:    "test_pool",
			currentTime: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := sr.NewPool(tt.poolPath, tt.currentTime)
			poolResolver := NewPoolResolver(pool)

			// Start unclaimable period
			poolResolver.startUnclaimablePeriod(tt.currentTime)
			uassert.Equal(t, tt.currentTime, poolResolver.Pool.LastUnclaimableTime())

			// End unclaimable period
			poolResolver.endUnclaimablePeriod(tt.currentTime + 100)
			uassert.Equal(t, int64(0), poolResolver.Pool.LastUnclaimableTime())
		})
	}
}

// Test processUnclaimableReward
func TestProcessUnclaimableReward(t *testing.T) {
	tests := []struct {
		name        string
		poolPath    string
		currentTime int64
	}{
		{
			name:        "process unclaimable reward",
			poolPath:    "test_pool",
			currentTime: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := sr.NewPool(tt.poolPath, tt.currentTime)
			poolResolver := NewPoolResolver(pool)
			pools := NewPools()
			pools.set(tt.poolPath, pool)

			poolTier := &PoolTier{
				getEmission: func() int64 { return 1000 },
				getHalvingBlocksInRange: func(start, end int64) ([]int64, []int64) {
					return nil, nil
				},
			}

			// Set up some unclaimable accumulation
			poolResolver.Pool.SetUnclaimableAcc(500)

			unclaimable := poolResolver.processUnclaimableReward(poolTier, tt.currentTime)

			uassert.True(t, unclaimable >= 0)
			uassert.Equal(t, int64(0), poolResolver.Pool.UnclaimableAcc())
		})
	}
}

// Test IsExternallyIncentivizedPool
func TestIsExternallyIncentivizedPool(t *testing.T) {
	tests := []struct {
		name     string
		poolPath string
	}{
		{
			name:     "pool with no external incentives",
			poolPath: "test_pool",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			currentTime := time.Now().Unix()
			pool := sr.NewPool(tt.poolPath, currentTime)
			poolResolver := NewPoolResolver(pool)

			// Should be false initially
			result := poolResolver.IsExternallyIncentivizedPool()
			uassert.False(t, result)
		})
	}
}

// Test TickResolver
func TestTickResolver(t *testing.T) {
	tests := []struct {
		name     string
		poolPath string
		tickId   int32
	}{
		{
			name:     "get tick resolver",
			poolPath: "test_pool",
			tickId:   0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			currentTime := time.Now().Unix()
			pool := sr.NewPool(tt.poolPath, currentTime)
			poolResolver := NewPoolResolver(pool)

			tickResolver := poolResolver.TickResolver(tt.tickId)
			uassert.NotNil(t, tickResolver)
		})
	}
}

// Test RewardState applyWarmup
func TestRewardStateApplyWarmup(t *testing.T) {
	tests := []struct {
		name              string
		rewards           []int64
		warmupRatios      []uint64
		expectedRewards   []int64
		expectedPenalties []int64
	}{
		{
			name:              "apply 100% warmup",
			rewards:           []int64{1000},
			warmupRatios:      []uint64{100},
			expectedRewards:   []int64{1000},
			expectedPenalties: []int64{0},
		},
		{
			name:              "apply 50% warmup",
			rewards:           []int64{1000},
			warmupRatios:      []uint64{50},
			expectedRewards:   []int64{500},
			expectedPenalties: []int64{500},
		},
		{
			name:              "apply 30% warmup",
			rewards:           []int64{1000},
			warmupRatios:      []uint64{30},
			expectedRewards:   []int64{300},
			expectedPenalties: []int64{700},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			currentTime := time.Now().Unix()
			pool := sr.NewPool("test_pool", currentTime)
			poolResolver := NewPoolResolver(pool)

			warmups := make([]sr.Warmup, len(tt.warmupRatios))
			for i, ratio := range tt.warmupRatios {
				warmups[i] = sr.Warmup{
					WarmupRatio:    ratio,
					NextWarmupTime: currentTime + int64(i*86400),
				}
			}

			deposit := sr.NewDeposit(
				testutils.TestAddress("owner"),
				"test_pool",
				u256.NewUintFromInt64(1000),
				currentTime,
				int32(0),
				int32(100),
				warmups,
			)

			rewardState := poolResolver.RewardStateOf(deposit)
			rewardState.rewards = tt.rewards

			rewardState.applyWarmup()

			for i := range tt.expectedRewards {
				uassert.Equal(t, tt.expectedRewards[i], rewardState.rewards[i])
				uassert.Equal(t, tt.expectedPenalties[i], rewardState.penalties[i])
			}
		})
	}
}

// Test RewardState reset
func TestRewardStateReset(t *testing.T) {
	currentTime := time.Now().Unix()
	pool := sr.NewPool("test_pool", currentTime)
	poolResolver := NewPoolResolver(pool)

	warmups := []sr.Warmup{
		{WarmupRatio: 30, NextWarmupTime: currentTime + 86400},
		{WarmupRatio: 50, NextWarmupTime: currentTime + 172800},
		{WarmupRatio: 70, NextWarmupTime: currentTime + 259200},
	}

	deposit := sr.NewDeposit(
		testutils.TestAddress("owner"),
		"test_pool",
		u256.NewUint(1000),
		currentTime,
		int32(-100),
		int32(100),
		warmups,
	)

	rewardState := poolResolver.RewardStateOf(deposit)

	// Set some values
	rewardState.rewards[0] = 1000
	rewardState.rewards[1] = 2000
	rewardState.rewards[2] = 3000
	rewardState.penalties[0] = 100
	rewardState.penalties[1] = 200
	rewardState.penalties[2] = 300

	// Reset
	rewardState.reset()

	// Verify all values are zero
	for i := range rewardState.rewards {
		uassert.Equal(t, int64(0), rewardState.rewards[i])
		uassert.Equal(t, int64(0), rewardState.penalties[i])
	}
}

func TestRewardStateReset_MultipleResets(t *testing.T) {
	currentTime := time.Now().Unix()
	pool := sr.NewPool("test_pool", currentTime)
	poolResolver := NewPoolResolver(pool)

	warmups := []sr.Warmup{
		{WarmupRatio: 50, NextWarmupTime: currentTime + 86400},
	}

	deposit := sr.NewDeposit(
		testutils.TestAddress("owner"),
		"test_pool",
		u256.NewUint(1000),
		currentTime,
		int32(-100),
		int32(100),
		warmups,
	)

	rewardState := poolResolver.RewardStateOf(deposit)

	// First round: set values and reset
	rewardState.rewards[0] = 5000
	rewardState.penalties[0] = 500
	rewardState.reset()

	uassert.Equal(t, int64(0), rewardState.rewards[0])
	uassert.Equal(t, int64(0), rewardState.penalties[0])

	// Second round: set different values and reset
	rewardState.rewards[0] = 9999
	rewardState.penalties[0] = 1111
	rewardState.reset()

	uassert.Equal(t, int64(0), rewardState.rewards[0])
	uassert.Equal(t, int64(0), rewardState.penalties[0])
}

func TestRewardStateReset_PreservesSliceLength(t *testing.T) {
	currentTime := time.Now().Unix()
	pool := sr.NewPool("test_pool", currentTime)
	poolResolver := NewPoolResolver(pool)

	warmups := []sr.Warmup{
		{WarmupRatio: 30, NextWarmupTime: currentTime + 86400},
		{WarmupRatio: 50, NextWarmupTime: currentTime + 172800},
		{WarmupRatio: 70, NextWarmupTime: currentTime + 259200},
		{WarmupRatio: 100, NextWarmupTime: currentTime + 345600},
	}

	deposit := sr.NewDeposit(
		testutils.TestAddress("owner"),
		"test_pool",
		u256.NewUint(1000),
		currentTime,
		int32(-100),
		int32(100),
		warmups,
	)

	rewardState := poolResolver.RewardStateOf(deposit)
	originalLen := len(rewardState.rewards)

	rewardState.reset()

	// Length should be preserved
	uassert.Equal(t, originalLen, len(rewardState.rewards))
	uassert.Equal(t, originalLen, len(rewardState.penalties))
}

// Test Pools IterateAll
func TestPoolsIterateAll(t *testing.T) {
	tests := []struct {
		name     string
		numPools int
	}{
		{
			name:     "iterate over zero pools",
			numPools: 0,
		},
		{
			name:     "iterate over single pool",
			numPools: 1,
		},
		{
			name:     "iterate over multiple pools",
			numPools: 5,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pools := NewPools()
			currentTime := time.Now().Unix()

			for i := 0; i < tt.numPools; i++ {
				poolPath := "pool_" + string(rune('A'+i))
				pool := sr.NewPool(poolPath, currentTime)
				pools.set(poolPath, pool)
			}

			count := 0
			pools.IterateAll(func(key string, pool *sr.Pool) bool {
				count++
				uassert.NotNil(t, pool)
				return false
			})

			uassert.Equal(t, tt.numPools, count)
		})
	}
}
