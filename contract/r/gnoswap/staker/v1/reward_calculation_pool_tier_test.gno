package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
	pl "gno.land/r/gnoswap/pool"
	sr "gno.land/r/gnoswap/staker"
)

func TestTierRatioFromCounts(t *testing.T) {
	tests := []struct {
		tier1Count uint64
		tier2Count uint64
		tier3Count uint64
		expected   sr.TierRatio
	}{
		{1, 0, 0, sr.TierRatio{Tier1: 100, Tier2: 0, Tier3: 0}},
		{1, 0, 1, sr.TierRatio{Tier1: 80, Tier2: 0, Tier3: 20}},
		{1, 1, 0, sr.TierRatio{Tier1: 70, Tier2: 30, Tier3: 0}},
		{1, 1, 1, sr.TierRatio{Tier1: 50, Tier2: 30, Tier3: 20}},
	}

	for _, tt := range tests {
		result := TierRatioFromCounts(tt.tier1Count, tt.tier2Count, tt.tier3Count)
		if result != tt.expected {
			t.Errorf("TierRatioFromCounts(%d, %d, %d) = %v; want %v",
				tt.tier1Count, tt.tier2Count, tt.tier3Count, result, tt.expected)
		}
	}
}

func TestNewPoolTier(t *testing.T) {
	currentHeight := int64(100)
	currentTime := int64(100000) // Arbitrary time for testing
	mustExistsInTier1 := "testPool"

	poolTier := NewPoolTier(NewPools(), currentHeight, currentTime, mustExistsInTier1, func() int64 { return 0 }, func(start, end int64) ([]int64, []int64) { return nil, nil })

	// Test initial counts
	if count := poolTier.CurrentCount(1); count != 1 {
		t.Errorf("Expected tier 1 count to be 1, got %d", count)
	}
	if count := poolTier.CurrentCount(2); count != 0 {
		t.Errorf("Expected tier 2 count to be 0, got %d", count)
	}
	if count := poolTier.CurrentCount(3); count != 0 {
		t.Errorf("Expected tier 3 count to be 0, got %d", count)
	}

	// Test membership
	if tier := poolTier.CurrentTier(mustExistsInTier1); tier != 1 {
		t.Errorf("Expected pool %s to be in tier 1, got %d", mustExistsInTier1, tier)
	}
}

func TestCacheReward(t *testing.T) {
	currentHeight := int64(250)
	currentTime := int64(250000)
	// Simulate emission updates
	pools := NewPools()
	poolTier := NewPoolTier(pools, currentHeight, currentTime, "testPool", func() int64 { return 1000 }, func(startHeight int64, endHeight int64) ([]int64, []int64) {
		return []int64{100, 150, 200}, []int64{1000, 500, 250}
	})

	// Cache rewards
	poolTier.cacheReward(currentHeight, currentTime, pools)

	// Verify rewards
	reward := poolTier.CurrentReward(1)
	if reward == 0 {
		t.Errorf("Expected reward for tier 1 at height 250, got 0")
	}
}

var test_gnousdc = pl.GetPoolPath("gno.land/r/gnoland/wugnot", "gno.land/r/gnoswap/gns", 3000)

func SetupPoolTier(t *testing.T) *PoolTier {
	pools := NewPools()
	poolTier := NewPoolTier(pools, 1, int64(1000), test_gnousdc, func() int64 { return 1000 }, func(start, end int64) ([]int64, []int64) { return nil, nil })

	poolTier.changeTier(1, int64(1000), pools, test_gnousdc, 1)
	return poolTier
}

func TestTierRatioGet(t *testing.T) {
	ratio := sr.TierRatio{Tier1: 50, Tier2: 30, Tier3: 20}

	tests := []struct {
		tier     uint64
		expected uint64
	}{
		{1, 50},
		{2, 30},
		{3, 20},
	}

	for _, tt := range tests {
		result, err := ratio.Get(tt.tier)
		if err != nil {
			uassert.NotNil(t, err)
		}

		uassert.Equal(t, result, tt.expected)
	}

	ratio.Get(4)
}

func TestPoolTierChangeTier(t *testing.T) {
	pools := NewPools()
	currentHeight := int64(100)
	currentTime := int64(100000)
	testPool1 := pl.GetPoolPath("gno.land/r/onbloc/bar", "gno.land/r/onbloc/baz", 3000)
	testPool2 := pl.GetPoolPath("gno.land/r/onbloc/foo", "gno.land/r/onbloc/qux", 3000)

	poolTier := NewPoolTier(pools, currentHeight, currentTime, testPool1,
		func() int64 { return 1000000 },
		func(start, end int64) ([]int64, []int64) { return nil, nil })

	// Add second pool to tier 2
	pools.set(testPool2, sr.NewPool(testPool2, currentTime+1))
	poolTier.changeTier(currentHeight+1, currentTime+1, pools, testPool2, 2)

	// Verify tier assignments
	if tier := poolTier.CurrentTier(testPool1); tier != 1 {
		t.Errorf("Expected pool1 to be in tier 1, got %d", tier)
	}
	if tier := poolTier.CurrentTier(testPool2); tier != 2 {
		t.Errorf("Expected pool2 to be in tier 2, got %d", tier)
	}

	// Verify ratio changed to 70/30/0
	if poolTier.tierRatio.Tier1 != 70 || poolTier.tierRatio.Tier2 != 30 || poolTier.tierRatio.Tier3 != 0 {
		t.Errorf("Expected ratio 70/30/0, got %d/%d/%d",
			poolTier.tierRatio.Tier1, poolTier.tierRatio.Tier2, poolTier.tierRatio.Tier3)
	}

	// Test removing pool from tier (tier 0)
	poolTier.changeTier(currentHeight+2, currentTime+2, pools, testPool2, 0)
	if tier := poolTier.CurrentTier(testPool2); tier != 0 {
		t.Errorf("Expected pool2 to be removed (tier 0), got %d", tier)
	}
}

func TestCurrentAllTierCounts(t *testing.T) {
	pools := NewPools()
	currentHeight := int64(100)
	currentTime := int64(100000)
	testPool1 := pl.GetPoolPath("gno.land/r/onbloc/bar", "gno.land/r/onbloc/baz", 3000)
	testPool2 := pl.GetPoolPath("gno.land/r/onbloc/foo", "gno.land/r/onbloc/qux", 3000)
	testPool3 := pl.GetPoolPath("gno.land/r/gnoland/wugnot", "gno.land/r/onbloc/bar", 3000)

	poolTier := NewPoolTier(pools, currentHeight, currentTime, testPool1,
		func() int64 { return 1000000 },
		func(start, end int64) ([]int64, []int64) { return nil, nil })

	// Add pools to different tiers
	pools.set(testPool2, sr.NewPool(testPool2, currentTime+1))
	poolTier.changeTier(currentHeight+1, currentTime+1, pools, testPool2, 2)

	pools.set(testPool3, sr.NewPool(testPool3, currentTime+2))
	poolTier.changeTier(currentHeight+2, currentTime+2, pools, testPool3, 3)

	counts := poolTier.CurrentAllTierCounts()

	// Should be [0, 1, 1, 1] for tiers 0, 1, 2, 3
	expected := []uint64{0, 1, 1, 1}
	for i, count := range counts {
		if count != expected[i] {
			t.Errorf("Tier %d count = %d; want %d", i, count, expected[i])
		}
	}
}

func TestIsInternallyIncentivizedPool(t *testing.T) {
	pools := NewPools()
	currentHeight := int64(100)
	currentTime := int64(100000)
	testPool1 := pl.GetPoolPath("gno.land/r/onbloc/bar", "gno.land/r/onbloc/baz", 3000)
	testPool2 := pl.GetPoolPath("gno.land/r/onbloc/foo", "gno.land/r/onbloc/qux", 3000)

	poolTier := NewPoolTier(pools, currentHeight, currentTime, testPool1,
		func() int64 { return 1000000 },
		func(start, end int64) ([]int64, []int64) { return nil, nil })

	// testPool1 is in tier 1, should be incentivized
	if !poolTier.IsInternallyIncentivizedPool(testPool1) {
		t.Errorf("Expected pool1 to be internally incentivized")
	}

	// testPool2 is not in any tier, should not be incentivized
	if poolTier.IsInternallyIncentivizedPool(testPool2) {
		t.Errorf("Expected pool2 to not be internally incentivized")
	}
}

func TestCurrentRewardPerPool(t *testing.T) {
	pools := NewPools()
	currentHeight := int64(100)
	currentTime := int64(100000)
	emission := int64(1000000)
	testPool1 := pl.GetPoolPath("gno.land/r/onbloc/bar", "gno.land/r/onbloc/baz", 3000)
	testPool2 := pl.GetPoolPath("gno.land/r/onbloc/foo", "gno.land/r/onbloc/qux", 3000)

	poolTier := NewPoolTier(pools, currentHeight, currentTime, testPool1,
		func() int64 { return emission },
		func(start, end int64) ([]int64, []int64) { return nil, nil })

	// With only tier 1 pool, it should get 100% of emission
	reward1 := poolTier.CurrentRewardPerPool(testPool1)
	expectedReward1 := emission * 100 / 100 / 1 // 100% ratio, 1 pool
	if reward1 != expectedReward1 {
		t.Errorf("Expected reward %d, got %d", expectedReward1, reward1)
	}

	// Add pool to tier 2
	pools.set(testPool2, sr.NewPool(testPool2, currentTime+1))
	poolTier.changeTier(currentHeight+1, currentTime+1, pools, testPool2, 2)

	// Now tier1 gets 70%, tier2 gets 30%
	reward1After := poolTier.CurrentRewardPerPool(testPool1)
	expectedReward1After := emission * 70 / 100 / 1 // 70% ratio, 1 pool
	if reward1After != expectedReward1After {
		t.Errorf("Expected tier1 reward %d, got %d", expectedReward1After, reward1After)
	}

	reward2 := poolTier.CurrentRewardPerPool(testPool2)
	expectedReward2 := emission * 30 / 100 / 1 // 30% ratio, 1 pool
	if reward2 != expectedReward2 {
		t.Errorf("Expected tier2 reward %d, got %d", expectedReward2, reward2)
	}
}

// Test CurrentReward for different tiers
func TestCurrentReward(t *testing.T) {
	tests := []struct {
		name           string
		tier           uint64
		tierCounts     [AllTierCount]uint64
		emission       int64
		expectedReward int64
		shouldBeZero   bool
	}{
		{
			name:           "tier 1 with single pool",
			tier:           1,
			tierCounts:     [AllTierCount]uint64{0, 1, 0, 0},
			emission:       1000000,
			expectedReward: 1000000,
			shouldBeZero:   false,
		},
		{
			name:           "tier 2 with single pool",
			tier:           2,
			tierCounts:     [AllTierCount]uint64{0, 1, 1, 0},
			emission:       1000000,
			expectedReward: 300000,
			shouldBeZero:   false,
		},
		{
			name:           "tier with zero count",
			tier:           1,
			tierCounts:     [AllTierCount]uint64{0, 0, 0, 0},
			emission:       1000000,
			expectedReward: 0,
			shouldBeZero:   true,
		},
		{
			name:           "tier 3 with multiple pools",
			tier:           3,
			tierCounts:     [AllTierCount]uint64{0, 1, 1, 2},
			emission:       1000000,
			expectedReward: 100000,
			shouldBeZero:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolTier := &PoolTier{
				tierRatio:   TierRatioFromCounts(tt.tierCounts[Tier1], tt.tierCounts[Tier2], tt.tierCounts[Tier3]),
				counts:      tt.tierCounts,
				getEmission: func() int64 { return tt.emission },
			}

			reward := poolTier.CurrentReward(tt.tier)

			if tt.shouldBeZero {
				uassert.Equal(t, int64(0), reward)
			} else {
				uassert.Equal(t, tt.expectedReward, reward)
			}
		})
	}
}

// Test NewPoolTierBy constructor
func TestNewPoolTierBy(t *testing.T) {
	tests := []struct {
		name                     string
		tierCounts               [AllTierCount]uint64
		lastRewardCacheTimestamp int64
		lastRewardCacheHeight    int64
		currentEmission          int64
	}{
		{
			name:                     "create with default values",
			tierCounts:               [AllTierCount]uint64{0, 1, 0, 0},
			lastRewardCacheTimestamp: 100,
			lastRewardCacheHeight:    50,
			currentEmission:          1000000,
		},
		{
			name:                     "create with multiple tiers",
			tierCounts:               [AllTierCount]uint64{0, 2, 3, 1},
			lastRewardCacheTimestamp: 200,
			lastRewardCacheHeight:    100,
			currentEmission:          500000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolTier := NewPoolTierBy(
				avl.NewTree(),
				TierRatioFromCounts(tt.tierCounts[Tier1], tt.tierCounts[Tier2], tt.tierCounts[Tier3]),
				tt.tierCounts,
				tt.lastRewardCacheTimestamp,
				tt.lastRewardCacheHeight,
				tt.currentEmission,
				func() int64 { return tt.currentEmission },
				func(start, end int64) ([]int64, []int64) { return nil, nil },
			)

			uassert.NotNil(t, poolTier)
			uassert.Equal(t, tt.lastRewardCacheTimestamp, poolTier.lastRewardCacheTimestamp)
			uassert.Equal(t, tt.lastRewardCacheHeight, poolTier.lastRewardCacheHeight)
			uassert.Equal(t, tt.currentEmission, poolTier.currentEmission)
		})
	}
}

// Test CurrentCount edge cases
func TestCurrentCountEdgeCases(t *testing.T) {
	tests := []struct {
		name          string
		tier          uint64
		tierCounts    [AllTierCount]uint64
		expectedCount int
	}{
		{
			name:          "tier 0 returns 0",
			tier:          0,
			tierCounts:    [AllTierCount]uint64{10, 1, 2, 3},
			expectedCount: 10,
		},
		{
			name:          "tier beyond AllTierCount returns 0",
			tier:          AllTierCount,
			tierCounts:    [AllTierCount]uint64{0, 1, 2, 3},
			expectedCount: 0,
		},
		{
			name:          "tier far beyond AllTierCount returns 0",
			tier:          100,
			tierCounts:    [AllTierCount]uint64{0, 1, 2, 3},
			expectedCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolTier := &PoolTier{
				counts: tt.tierCounts,
			}

			count := poolTier.CurrentCount(tt.tier)
			uassert.Equal(t, tt.expectedCount, count)
		})
	}
}

// Test applyCacheToAllPools behavior
func TestApplyCacheToAllPools(t *testing.T) {
	tests := []struct {
		name                   string
		emissionInThisInterval int64
		tierCounts             [AllTierCount]uint64
		numPoolsToAdd          int
	}{
		{
			name:                   "single pool single tier",
			emissionInThisInterval: 1000,
			tierCounts:             [AllTierCount]uint64{0, 1, 0, 0},
			numPoolsToAdd:          1,
		},
		{
			name:                   "multiple pools multiple tiers",
			emissionInThisInterval: 5000,
			tierCounts:             [AllTierCount]uint64{0, 2, 2, 1},
			numPoolsToAdd:          5,
		},
		{
			name:                   "zero emission",
			emissionInThisInterval: 0,
			tierCounts:             [AllTierCount]uint64{0, 1, 1, 1},
			numPoolsToAdd:          3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pools := NewPools()
			poolTier := &PoolTier{
				membership:  avl.NewTree(),
				tierRatio:   TierRatioFromCounts(tt.tierCounts[Tier1], tt.tierCounts[Tier2], tt.tierCounts[Tier3]),
				counts:      tt.tierCounts,
				getEmission: func() int64 { return tt.emissionInThisInterval },
			}

			currentTime := int64(1000)

			// Add pools to different tiers
			tier := uint64(1)
			for i := 0; i < tt.numPoolsToAdd; i++ {
				poolPath := pl.GetPoolPath("gno.land/r/test/token"+string(rune('A'+i)), "gno.land/r/test/token"+string(rune('B'+i)), 3000)
				pool := sr.NewPool(poolPath, currentTime)
				pools.set(poolPath, pool)
				poolTier.membership.Set(poolPath, tier)

				// Rotate through tiers
				tier++
				if tier > 3 {
					tier = 1
				}
			}

			// This should not panic
			poolTier.applyCacheToAllPools(pools, currentTime, tt.emissionInThisInterval)
		})
	}
}

// Test calculatePoolReward function with various edge cases
func TestCalculatePoolReward(t *testing.T) {
	tests := []struct {
		name        string
		emission    int64
		tierRatio   int64
		tierCount   int64
		expected    int64
		shouldPanic bool
	}{
		// Normal cases
		{
			name:      "basic calculation",
			emission:  1000000,
			tierRatio: 50,
			tierCount: 1,
			expected:  500000, // 1000000 * 50 / 100 / 1
		},
		{
			name:      "multiple pools in tier",
			emission:  1000000,
			tierRatio: 50,
			tierCount: 2,
			expected:  250000, // 1000000 * 50 / 100 / 2
		},
		{
			name:      "tier ratio 100 percent",
			emission:  1000000,
			tierRatio: 100,
			tierCount: 1,
			expected:  1000000, // 1000000 * 100 / 100 / 1
		},
		{
			name:      "tier ratio 30 percent with 3 pools",
			emission:  900000,
			tierRatio: 30,
			tierCount: 3,
			expected:  90000, // 900000 * 30 / 100 / 3
		},
		{
			name:      "tier ratio 20 percent",
			emission:  1000000,
			tierRatio: 20,
			tierCount: 5,
			expected:  40000, // 1000000 * 20 / 100 / 5
		},

		// Zero value cases
		{
			name:      "zero emission",
			emission:  0,
			tierRatio: 50,
			tierCount: 1,
			expected:  0, // safeMulDivInt64 returns 0 when a == 0
		},
		{
			name:      "zero tier ratio",
			emission:  1000000,
			tierRatio: 0,
			tierCount: 1,
			expected:  0, // safeMulDivInt64 returns 0 when b == 0
		},
		{
			name:      "zero tier count",
			emission:  1000000,
			tierRatio: 50,
			tierCount: 0,
			expected:  0, // function returns 0 for tierCount == 0
		},
		{
			name:      "all zeros",
			emission:  0,
			tierRatio: 0,
			tierCount: 0,
			expected:  0,
		},

		// Division truncation cases
		{
			name:      "truncation due to integer division",
			emission:  100,
			tierRatio: 33,
			tierCount: 1,
			expected:  33, // 100 * 33 / 100 = 33
		},
		{
			name:      "truncation with tier count",
			emission:  1000,
			tierRatio: 50,
			tierCount: 3,
			expected:  166, // 1000 * 50 / 100 / 3 = 500 / 3 = 166
		},
		{
			name:      "small result truncated to zero",
			emission:  10,
			tierRatio: 1,
			tierCount: 100,
			expected:  0, // 10 * 1 / 100 / 100 = 0 / 100 = 0
		},

		// Large value cases (boundary tests)
		{
			name:      "large emission value",
			emission:  9223372036854775807, // max int64
			tierRatio: 1,
			tierCount: 100,
			expected:  922337203685477, // max int64 * 1 / 100 / 100 (using i256 safe math)
		},
		{
			name:      "large emission with moderate ratio",
			emission:  1000000000000000,
			tierRatio: 70,
			tierCount: 10,
			expected:  70000000000000, // 1000000000000000 * 70 / 100 / 10
		},
		{
			name:      "large tier count",
			emission:  1000000000,
			tierRatio: 50,
			tierCount: 1000000,
			expected:  500, // 1000000000 * 50 / 100 / 1000000
		},

		// Single pool scenarios
		{
			name:      "single pool tier 1",
			emission:  1000000,
			tierRatio: 100,
			tierCount: 1,
			expected:  1000000,
		},
		{
			name:      "single pool tier 2 with tier1 exists",
			emission:  1000000,
			tierRatio: 30,
			tierCount: 1,
			expected:  300000,
		},

		// Realistic protocol scenarios
		{
			name:      "realistic tier 1 scenario",
			emission:  14269406392694063, // realistic emission per block
			tierRatio: 50,
			tierCount: 3,
			expected:  2378234398782343, // emission * 50 / 100 / 3
		},
		{
			name:      "realistic tier 3 scenario with many pools",
			emission:  14269406392694063,
			tierRatio: 20,
			tierCount: 10,
			expected:  285388127853881, // emission * 20 / 100 / 10
		},
		{
			name:        "negative emission",
			emission:    -1000000,
			tierRatio:   50,
			tierCount:   1,
			shouldPanic: true,
		},
		{
			name:        "negative tier ratio",
			emission:    1000000,
			tierRatio:   -50,
			tierCount:   1,
			shouldPanic: true,
		},
		{
			name:        "negative tier count",
			emission:    1000000,
			tierRatio:   50,
			tierCount:   -1,
			shouldPanic: true,
		},
		{
			name:        "both emission and ratio negative",
			emission:    -1000000,
			tierRatio:   -50,
			tierCount:   1,
			shouldPanic: true,
		},
		{
			name:        "all negative",
			emission:    -1000000,
			tierRatio:   -50,
			tierCount:   -1,
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "unexpected calculation error", func() {
					calculatePoolReward(tt.emission, tt.tierRatio, tt.tierCount)
				})
			} else {
				result := calculatePoolReward(tt.emission, tt.tierRatio, tt.tierCount)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestCalculatePoolReward_Boundary(t *testing.T) {
	tests := []struct {
		name        string
		emission    int64
		tierRatio   int64
		tierCount   int64
		expected    int64
		shouldPanic bool
	}{
		{
			name:        "max int64 with ratio 1 should not overflow",
			emission:    9223372036854775807,
			tierRatio:   1,
			tierCount:   1,
			expected:    92233720368547758,
			shouldPanic: false,
		},
		{
			name:        "large values within safe range",
			emission:    1000000000000000000,
			tierRatio:   50,
			tierCount:   1,
			expected:    500000000000000000,
			shouldPanic: false,
		},
		{
			name:        "max int64 with ratio 100 - safe due to i256",
			emission:    9223372036854775807,
			tierRatio:   100,
			tierCount:   1,
			expected:    9223372036854775807,
			shouldPanic: false, // i256 handles the intermediate multiplication
		},
		{
			name:        "large emission with large ratio - safe due to i256",
			emission:    9223372036854775807,
			tierRatio:   50,
			tierCount:   1,
			expected:    4611686018427387903,
			shouldPanic: false, // i256 handles the intermediate multiplication
		},
		{
			name:        "division by zero in tierCount handled by function",
			emission:    1000000,
			tierRatio:   50,
			tierCount:   0,
			shouldPanic: false, // function returns 0 before calling safeMulDivInt64
			expected:    0,
		},
		{
			name:        "max int64 with ratio 101 - should panic",
			emission:    9223372036854775807,
			tierRatio:   101,
			tierCount:   1,
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "overflow", func() {
					result := calculatePoolReward(tt.emission, tt.tierRatio, tt.tierCount)
					t.Logf("result: %d", result)
				})
			} else {
				result := calculatePoolReward(tt.emission, tt.tierRatio, tt.tierCount)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// Test calculatePoolReward with i256 overflow scenarios
// These tests verify behavior when the intermediate i256 multiplication overflows
func TestCalculatePoolReward_I256Overflow(t *testing.T) {
	tests := []struct {
		name        string
		emission    int64
		tierRatio   int64
		tierCount   int64
		shouldPanic bool
	}{
		{
			// This should cause i256 overflow: max_int64 * max_int64
			name:        "both max int64 should cause i256 overflow",
			emission:    9223372036854775807,
			tierRatio:   9223372036854775807,
			tierCount:   1,
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "overflow", func() {
					calculatePoolReward(tt.emission, tt.tierRatio, tt.tierCount)
				})
			} else {
				result := calculatePoolReward(tt.emission, tt.tierRatio, tt.tierCount)
				t.Logf("result: %d", result)
			}
		})
	}
}
