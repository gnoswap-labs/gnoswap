package staker

import (
	"testing"

	pl "gno.land/r/gnoswap/v1/pool"
)

func TestTierRatioFromCounts(t *testing.T) {
	tests := []struct {
		tier1Count uint64
		tier2Count uint64
		tier3Count uint64
		expected   TierRatio
	}{
		{1, 0, 0, TierRatio{Tier1: 100, Tier2: 0, Tier3: 0}},
		{1, 0, 1, TierRatio{Tier1: 80, Tier2: 0, Tier3: 20}},
		{1, 1, 0, TierRatio{Tier1: 70, Tier2: 30, Tier3: 0}},
		{1, 1, 1, TierRatio{Tier1: 50, Tier2: 30, Tier3: 20}},
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
	poolTier := NewPoolTier(NewPools(), currentHeight, currentTime, "testPool", func() int64 { return 1000 }, func(startHeight int64, endHeight int64) ([]int64, []int64) {
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
	poolTier := NewPoolTier(NewPools(), 1, int64(1000), test_gnousdc, func() int64 { return 1000 }, func(start, end int64) ([]int64, []int64) { return nil, nil })

	poolTier.changeTier(1, int64(1000), pools, test_gnousdc, 1)
	return poolTier
}

func TestTierRatioGet(t *testing.T) {
	ratio := TierRatio{Tier1: 50, Tier2: 30, Tier3: 20}

	tests := []struct {
		tier     uint64
		expected int64
	}{
		{1, 50},
		{2, 30},
		{3, 20},
	}

	for _, tt := range tests {
		result := ratio.Get(Tier(tt.tier))
		if result != tt.expected {
			t.Errorf("Get(%d) = %d; want %d", tt.tier, result, tt.expected)
		}
	}

	// Test panic for invalid tier
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("Get(4) should panic for invalid tier")
		}
	}()
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
	pools.set(testPool2, NewPool(testPool2, currentTime+1))
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
	pools.set(testPool2, NewPool(testPool2, currentTime+1))
	poolTier.changeTier(currentHeight+1, currentTime+1, pools, testPool2, 2)

	pools.set(testPool3, NewPool(testPool3, currentTime+2))
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
	pools.set(testPool2, NewPool(testPool2, currentTime+1))
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
