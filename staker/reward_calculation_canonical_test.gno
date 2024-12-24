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

	return NewCanonicalRewardState(poolTier, pools, ticks, deposits, TickCrossHook)
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

	// gnousdc takes the entire emission
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.perBlockEmission)
	
	reward := canonical.EmulatedRewardOf(0)
	if reward.internal != canonical.perBlockEmission * 30 / 100 {
		t.Errorf("RewardOf failed, expected %d, got %d", canonical.perBlockEmission * 30 / 100, reward.internal)
	}

	reward = canonical.CanonicalRewardOf(0)
	if reward.internal != canonical.perBlockEmission * 30 / 100 {
		t.Errorf("RewardOf failed, expected %d, got %d", canonical.perBlockEmission * 30 / 100, reward.internal)
	}

	/*
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