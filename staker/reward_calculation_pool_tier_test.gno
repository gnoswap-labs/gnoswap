package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/v1/consts"
	pl "gno.land/r/gnoswap/v1/pool"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

func TestTierRatioFromCounts(t *testing.T) {
	CreateSecondPoolWithoutFee(t)
	MakeMintPositionWithoutFee(t)

	user1Addr := testutils.TestAddress("user1")
	user1Realm := std.NewUserRealm(user1Addr)

	std.TestSetRealm(user1Realm)
	bar.Approve(a2u(consts.ROUTER_ADDR), maxApprove)
	baz.Approve(a2u(consts.ROUTER_ADDR), maxApprove)
	qux.Approve(a2u(consts.ROUTER_ADDR), maxApprove)
	TokenFaucet(t, barPath, a2u(user1Addr))

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
		if *result != tt.expected {
			t.Errorf("TierRatioFromCounts(%d, %d, %d) = %v; want %v",
				tt.tier1Count, tt.tier2Count, tt.tier3Count, result, tt.expected)
		}
	}
}

func TestNewPoolTier(t *testing.T) {
	currentHeight := uint64(100)
	mustExistsInTier1 := "testPool"

	poolTier := NewPoolTier(currentHeight, mustExistsInTier1)

	// Test initial counts
	if count := poolTier.CurrentCount(1, currentHeight); count != 1 {
		t.Errorf("Expected tier 1 count to be 1, got %d", count)
	}
	if count := poolTier.CurrentCount(2, currentHeight); count != 0 {
		t.Errorf("Expected tier 2 count to be 0, got %d", count)
	}
	if count := poolTier.CurrentCount(3, currentHeight); count != 0 {
		t.Errorf("Expected tier 3 count to be 0, got %d", count)
	}

	// Test membership
	if tier := poolTier.CurrentTier(mustExistsInTier1, currentHeight); tier != 1 {
		t.Errorf("Expected pool %s to be in tier 1, got %d", mustExistsInTier1, tier)
	}
}

func TestCacheReward(t *testing.T) {
	currentHeight := uint64(100)
	poolTier := NewPoolTier(currentHeight, "testPool")

	// Simulate emission updates
	emissionUpdateHeights := []uint64{100, 150, 200}
	emissionUpdates := []uint64{1000, 500, 250}

	// Cache rewards
	poolTier.cacheReward(250, emissionUpdateHeights, emissionUpdates)

	// Verify rewards
	reward := poolTier.CurrentReward(1, 150)
	if reward == 0 {
		t.Errorf("Expected reward for tier 1 at height 150, got 0")
	}
}

var test_gnousdc = pl.GetPoolPath("gno.land/r/demo/wugnot", "gno.land/r/gnoswap/v1/gns", 3000)

func SetupPoolTier(t *testing.T) *PoolTier {
	poolTier := NewPoolTier(1, test_gnousdc)
	poolTier.changeTier(1, test_gnousdc, 1)
	return poolTier
}

func TestPoolTierSimple(t *testing.T) {
	poolTier := SetupPoolTier(t)

	currentHeight := uint64(1)

	emissionUpdateHeights := []uint64{currentHeight}
	emissionUpdates := []uint64{10000}

	currentHeight = 2

	poolTier.cacheReward(currentHeight, emissionUpdateHeights, emissionUpdates)
	uassert.Equal(t, uint64(1), poolTier.CurrentTier(test_gnousdc, currentHeight))
	uassert.Equal(t, uint64(10000), poolTier.CurrentReward(1, currentHeight))

	currentHeight = 3

	emissionUpdateHeights = append(emissionUpdateHeights, currentHeight)
	emissionUpdates = append(emissionUpdates, 20000)

	gnousdc2 := pl.GetPoolPath("gno.land/r/demo/wugnot", "gno.land/r/gnoswap/v1/gns", 5000)
	poolTier.changeTier(currentHeight, gnousdc2, 2)

	currentHeight = 4

	poolTier.cacheReward(currentHeight, emissionUpdateHeights, emissionUpdates)
	uassert.Equal(t, uint64(1), poolTier.CurrentTier(test_gnousdc, currentHeight))
	uassert.Equal(t, uint64(14000), poolTier.CurrentReward(1, currentHeight))
	uassert.Equal(t, uint64(6000), poolTier.CurrentReward(2, currentHeight))
}