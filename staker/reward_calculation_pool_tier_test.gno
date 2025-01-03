package staker

import (
	"std"
	"testing"
	"strings"

	ufmt "gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	uassert "gno.land/p/demo/uassert"
)

var test_gnousdc = GetPoolPath("gno", "usdc", 3000)

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

	gnousdc2 := GetPoolPath("gno", "usdc", 5000)
	poolTier.changeTier(currentHeight, gnousdc2, 2)

	currentHeight = 4

	poolTier.cacheReward(currentHeight, emissionUpdateHeights, emissionUpdates)
	uassert.Equal(t, uint64(1), poolTier.CurrentTier(test_gnousdc, currentHeight))
	uassert.Equal(t, uint64(14000), poolTier.CurrentReward(1, currentHeight))
	uassert.Equal(t, uint64(6000), poolTier.CurrentReward(2, currentHeight))
}