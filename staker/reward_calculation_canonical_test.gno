package staker

// Evaluate against the canonical implementation

import (
	"std"
	"testing"
	"strings"

	ufmt "gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

func Setup() *canonicalRewardState {
	poolTier := NewPoolTier(0)
	pools := NewPools()
	ticks := NewTicks()
	deposits := NewDeposits()
	tickCrossHook := TickCrossHook(pools, ticks)

	return NewCanonicalRewardState(poolTier, pools, ticks, deposits, tickCrossHook)
}

func TestCanonicalRewardState(t *testing.T) {
	canonical := Setup()

	gnousdc := GetPoolPath("gno", "usdc", 3000)
	canonical.CreatePool(gnousdc, 1, 150)

	err := canonical.StakeToken(
		0, 
		gnousdc, 
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"), 
		100, 
		200, 
		u256.NewUint(1000000000000000000),
	)

	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	canonical.CalculateReward()

	reward := canonical.EmulatedRewardOf(0)
	/*
	if reward.internal != 1000 {
		t.Errorf("RewardOf failed, expected %d, got %d", 1000, reward.internal)
	}

	if len(reward.external) != 0 {
		t.Errorf("RewardOf failed, expected %d, got %d", 0, len(reward.external))
	}
		*/
}

func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}
	return ufmt.Sprintf("%s:%s:%d", token0Path, token1Path, fee)
}