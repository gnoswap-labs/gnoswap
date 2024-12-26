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

func TestSimple(t *testing.T) {
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
		t.Errorf("0: EmulatedRewardOf failed, expected %d, got %d", canonical.perBlockEmission * 30 / 100, reward.internal)
	}

	reward = canonical.CanonicalRewardOf(0)
	if reward.internal != canonical.perBlockEmission * 30 / 100 {
		t.Errorf("1: CanonicalRewardOf failed, expected %d, got %d", canonical.perBlockEmission * 30 / 100, reward.internal)
	}
}

func TestTickCross_0(t *testing.T) {
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

	// The position remains inrange, no change in reward.
	canonical.MoveTick(gnousdc, 120)

	canonical.CalculateReward()

	// gnousdc takes the entire emission
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.perBlockEmission)
	
	reward := canonical.EmulatedRewardOf(0)
	if reward.internal != canonical.perBlockEmission * 30 / 100 {
		t.Errorf("0: EmulatedRewardOf failed, expected %d, got %d", canonical.perBlockEmission * 30 / 100, reward.internal)
	}

	reward = canonical.CanonicalRewardOf(0)
	if reward.internal != canonical.perBlockEmission * 30 / 100 {
		t.Errorf("1: CanonicalRewardOf failed, expected %d, got %d", canonical.perBlockEmission * 30 / 100, reward.internal)
	}

	// The position is now outrange. The reward must be reduced.
	canonical.MoveTick(gnousdc, 90)

	canonical.CalculateReward()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.perBlockEmission)

	reward = canonical.EmulatedRewardOf(0)
	if reward.internal != 0 {
		t.Errorf("2: EmulatedRewardOf failed, expected %d, got %d", 0, reward.internal)
	}

	reward = canonical.CanonicalRewardOf(0)
	if reward.internal != 0 {
		t.Errorf("3: CanonicalRewardOf failed, expected %d, got %d", 0, reward.internal)
	}

	// The position remains outrange.
	canonical.MoveTick(gnousdc, 80)

	canonical.CalculateReward()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.perBlockEmission)

	reward = canonical.EmulatedRewardOf(0)
	if reward.internal != 0 {
		t.Errorf("4: EmulatedRewardOf failed, expected %d, got %d", 0, reward.internal)
	}

	reward = canonical.CanonicalRewardOf(0)
	if reward.internal != 0 {
		t.Errorf("5: CanonicalRewardOf failed, expected %d, got %d", 0, reward.internal)
	}

	// The tick passes through the positions range, remains outrange.
	canonical.MoveTick(gnousdc, 220)

	canonical.CalculateReward()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.perBlockEmission)

	reward = canonical.EmulatedRewardOf(0)
	if reward.internal != 0 {
		t.Errorf("6: EmulatedRewardOf failed, expected %d, got %d", 0, reward.internal)
	}

	reward = canonical.CanonicalRewardOf(0)
	if reward.internal != 0 {
		t.Errorf("7: CanonicalRewardOf failed, expected %d, got %d", 0, reward.internal)
	}

	// The tick goes back to the range.
	canonical.MoveTick(gnousdc, 180)

	canonical.CalculateReward()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.perBlockEmission)

	reward = canonical.EmulatedRewardOf(0)
	if reward.internal != canonical.perBlockEmission * 30 / 100 {
		t.Errorf("8: EmulatedRewardOf failed, expected %d, got %d", 0, reward.internal)
	}

	reward = canonical.CanonicalRewardOf(0)
	if reward.internal != canonical.perBlockEmission * 30 / 100 {
		t.Errorf("9: CanonicalRewardOf failed, expected %d, got %d", 0, reward.internal)
	}
}

func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}
	return ufmt.Sprintf("%s:%s:%d", token0Path, token1Path, fee)
}