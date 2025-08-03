package staker

// Evaluate against the canonical implementation

import (
	"std"
	"strings"
	"testing"

	ufmt "gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

func Setup(t *testing.T) *canonicalRewardState {
	pools := NewPools()
	deposits := NewDeposits()

	return NewCanonicalRewardState(t, pools, deposits, tickCrossHook)
}

func TestCanonicalSimple(t *testing.T) {
	canonical := Setup(t)

	gnousdc := test_gnousdc
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

	canonical.NextBlock()

	// gnousdc takes the entire emission delta
	expectedPoolReward := int64(canonical.PerBlockEmission)
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, expectedPoolReward)

	// 30% warmup ratio applied to the distributed emission
	expected := expectedPoolReward * 30 / 100
	canonical.AssertEmulatedRewardOf(0, uint64(expected))
	canonical.AssertCanonicalRewardOf(0, uint64(expected))
}

// To check precision error
func TestCanonicalLargeStakedLiquidity(t *testing.T) {
	canonical := Setup(t)

	gnousdc := test_gnousdc
	canonical.CreatePool(gnousdc, 1, 150)

	canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"),
		100,
		200,
		q128,
	)

	canonical.NextBlock()

	expectedPoolReward := int64(canonical.PerBlockEmission)

	expected := expectedPoolReward * 30 / 100
	canonical.AssertEmulatedRewardOf(0, uint64(expected))
	canonical.AssertCanonicalRewardOf(0, uint64(expected))
}

// To check precision error
func TestCanonicalLargeStakedLiquidity_2(t *testing.T) {
	canonical := Setup(t)

	gnousdc := test_gnousdc
	canonical.CreatePool(gnousdc, 1, 150)

	u2_30 := uint64(1073741824)
	u2_33 := uint64(8589934592)

	// Estimated per-block emission for staker is estimated to not get more than 100 million, but we are stress testing.
	// If more than 100 million is emitted, the overflow could occur inside of the PoolTier distribution logic.
	canonical.SetEmissionUpdate(10000000000000)

	canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"),
		100,
		200,
		u256.NewUint(u2_30),
	)

	canonical.StakeToken(
		1,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgq"),
		100,
		200,
		u256.NewUint(u2_33),
	)

	canonical.NextBlock()

	expectedPoolReward := int64(canonical.PerBlockEmission)
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, expectedPoolReward)

	expected := uint64(expectedPoolReward) / 100 * 30
	canonical.AssertEmulatedRewardOf(0, expected/9)
	canonical.AssertCanonicalRewardOf(0, expected/9)

	expected1 := uint64(2666666666666)
	canonical.AssertEmulatedRewardOf(1, expected1)
	canonical.AssertCanonicalRewardOf(1, expected1)
}

// Tests simple case with tick crossing
func TestCanonicalTickCross_0(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
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

	canonical.NextBlock()

	// gnousdc takes the entire emission
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))

	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected)
	canonical.AssertCanonicalRewardOf(0, expected)

	// The position is now outrange. The reward must be reduced.
	canonical.MoveTick(gnousdc, 90)

	canonical.NextBlock()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))

	canonical.AssertEmulatedRewardOf(0, 0)
	canonical.AssertCanonicalRewardOf(0, 0)

	// The position remains outrange.
	canonical.MoveTick(gnousdc, 80)

	canonical.NextBlock()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))

	canonical.AssertEmulatedRewardOf(0, 0)
	canonical.AssertCanonicalRewardOf(0, 0)

	// The tick passes through the positions range, remains outrange.
	canonical.MoveTick(gnousdc, 220)

	canonical.NextBlock()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))

	canonical.AssertEmulatedRewardOf(0, 0)
	canonical.AssertCanonicalRewardOf(0, 0)

	// The tick goes back to the range.
	canonical.MoveTick(gnousdc, 180)

	canonical.NextBlock()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))

	// The position is now inrange, so it takes the entire emission
	canonical.AssertEmulatedRewardOf(0, expected)
	canonical.AssertCanonicalRewardOf(0, expected)
}

// Tests tick crossing with lazy evaluation of position reward
func TestCanonicalTickCross_1(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
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

	canonical.NextBlockNoCanonical()

	// The position is now outrange. The reward must be reduced.
	canonical.MoveTick(gnousdc, 90)

	canonical.NextBlockNoCanonical()

	// The position remains outrange.
	canonical.MoveTick(gnousdc, 80)

	canonical.NextBlockNoCanonical()

	// The tick passes through the positions range, remains outrange.
	canonical.MoveTick(gnousdc, 220)

	canonical.NextBlockNoCanonical()

	// The tick goes back to the range.
	canonical.MoveTick(gnousdc, 180)

	canonical.NextBlock()
	
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	// We check that emulated reward is lazy evaluated when we finally calculate it.
	// It takes the two block's emission into account.
	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected)
}

// Test tick crossing with multiple positions with same tick, same liquidity
func TestCanonicalTickCross_2(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
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

	err = canonical.StakeToken(
		1,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgq"),
		100,
		200,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	// eligible
	canonical.MoveTick(gnousdc, 120)
	canonical.NextBlockNoCanonical()

	// not eligible
	canonical.MoveTick(gnousdc, 90)
	canonical.NextBlockNoCanonical()

	// not eligible
	canonical.MoveTick(gnousdc, 80)
	canonical.NextBlockNoCanonical()

	// not eligible
	canonical.MoveTick(gnousdc, 220)
	canonical.NextBlockNoCanonical()

	// eligible
	canonical.MoveTick(gnousdc, 180)
	canonical.NextBlockNoCanonical()

	// eligible
	canonical.MoveTick(gnousdc, 120)
	canonical.NextBlockNoCanonical()

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))

	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected/2)
	canonical.AssertEmulatedRewardOf(1, expected/2)
}

// Test tick crossing with multiple positions with same tick, different liquidity
func TestCanonicalTickCross_3(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
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

	err = canonical.StakeToken(
		1,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgq"),
		100,
		200,
		u256.NewUint(3000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	// eligible
	canonical.MoveTick(gnousdc, 120)
	canonical.NextBlockNoCanonical()

	// not eligible
	canonical.MoveTick(gnousdc, 90)
	canonical.NextBlockNoCanonical()

	// not eligible
	canonical.MoveTick(gnousdc, 80)
	canonical.NextBlockNoCanonical()

	// not eligible
	canonical.MoveTick(gnousdc, 220)
	canonical.NextBlockNoCanonical()

	// eligible
	canonical.MoveTick(gnousdc, 180)
	canonical.NextBlockNoCanonical()

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))

	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected/4)
	canonical.AssertEmulatedRewardOf(1, expected*3/4)
}

// Test tick crossing with multiple positions with different tick, same liquidity
func TestCanonicalTickCross_4(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	canonical.CreatePool(gnousdc, 1, 200)

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"),
		100,
		300,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	err = canonical.StakeToken(
		1,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgq"),
		200,
		400,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	expected := canonical.PerBlockEmission * 30 / 100

	// 0 eligible, 1 not eligible (100:0)
	canonical.MoveTick(gnousdc, 101)
	canonical.NextBlock()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertCanonicalRewardOf(0, expected)
	canonical.AssertCanonicalRewardOf(1, 0)
	// 0 eligible, 1 not eligible (100:0)
	canonical.MoveTick(gnousdc, 101)
	canonical.NextBlock()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertCanonicalRewardOf(0, expected)
	canonical.AssertCanonicalRewardOf(1, 0)

	// 0 eligible, 1 eligible (50:50)
	canonical.MoveTick(gnousdc, 201)
	canonical.NextBlock()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertCanonicalRewardOf(0, expected/2)
	canonical.AssertCanonicalRewardOf(1, expected/2)

	// 0 not eligible, 1 not eligible (0:0)
	canonical.MoveTick(gnousdc, 401)
	canonical.NextBlock()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertCanonicalRewardOf(0, 0)
	canonical.AssertCanonicalRewardOf(1, 0)

	// 0 not eligible, 1 eligible (0:100)
	canonical.MoveTick(gnousdc, 301)
	canonical.NextBlock()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertCanonicalRewardOf(0, 0)
	canonical.AssertCanonicalRewardOf(1, expected)
}

// Test tick crossing at tick boundaries, forward direction
func TestCanonicalTickCross_5(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	canonical.CreatePool(gnousdc, 1, 200)

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"),
		100,
		300,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	expected := canonical.PerBlockEmission * 30 / 100

	// not eligible
	// block 1
	canonical.MoveTick(gnousdc, 99)
	canonical.NextBlock()

	// block 2
	canonical.AssertCanonicalRewardOf(0, 0)
	canonical.AssertEmulatedRewardOf(0, 0)

	// eligible
	// entered range
	canonical.MoveTick(gnousdc, 100)
	canonical.NextBlock()

	// block 3
	canonical.AssertCanonicalRewardOf(0, expected)
	canonical.AssertEmulatedRewardOf(0, expected)

	// eligible
	canonical.MoveTick(gnousdc, 101)
	canonical.NextBlock()

	// block 4
	canonical.AssertCanonicalRewardOf(0, expected)
	canonical.AssertEmulatedRewardOf(0, expected)

	// eligible
	canonical.MoveTick(gnousdc, 299)
	canonical.NextBlock()

	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))

	canonical.AssertCanonicalRewardOf(0, expected)
	canonical.AssertEmulatedRewardOf(0, expected)

	// not eligible
	canonical.MoveTick(gnousdc, 300)
	canonical.NextBlock()

	canonical.AssertCanonicalRewardOf(0, 0)
	canonical.AssertEmulatedRewardOf(0, 0)

	// not eligible
	canonical.MoveTick(gnousdc, 301)
	canonical.NextBlock()

	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))

	canonical.AssertCanonicalRewardOf(0, 0)
	canonical.AssertEmulatedRewardOf(0, 0)
}

// Test tick crossing at tick boundaries, backward direction
func TestCanonicalTickCross_6(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	canonical.CreatePool(gnousdc, 1, 200)

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"),
		100,
		300,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	expected := canonical.PerBlockEmission * 30 / 100

	// not eligible
	canonical.MoveTick(gnousdc, 301)
	canonical.NextBlockNoCanonical()
	canonical.CalculateCanonicalReward()

	canonical.AssertEmulatedRewardOf(0, 0)

	// not eligible
	canonical.MoveTick(gnousdc, 300)
	canonical.NextBlockNoCanonical()
	canonical.CalculateCanonicalReward()

	canonical.AssertEmulatedRewardOf(0, 0)

	// eligible
	canonical.MoveTick(gnousdc, 299)
	canonical.NextBlockNoCanonical()
	canonical.CalculateCanonicalReward()

	canonical.AssertEmulatedRewardOf(0, expected)

	// eligible
	canonical.MoveTick(gnousdc, 101)
	canonical.NextBlockNoCanonical()
	canonical.CalculateCanonicalReward()

	canonical.AssertEmulatedRewardOf(0, expected)

	// eligible
	canonical.MoveTick(gnousdc, 100)
	canonical.NextBlockNoCanonical()
	canonical.CalculateCanonicalReward()

	canonical.AssertEmulatedRewardOf(0, expected)

	// not eligible
	canonical.MoveTick(gnousdc, 99)
	canonical.NextBlockNoCanonical()
	canonical.CalculateCanonicalReward()

	canonical.AssertEmulatedRewardOf(0, 0)
}

func TestCanonicalExternalReward_1(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	canonical.CreatePool(gnousdc, 1, 200)

	currentHeight := int64(canonical.CurrentHeight())
	incentiveId := canonical.CreateExternalIncentive(gnousdc, gnsPath, 100000000, currentHeight+1, currentHeight+5, std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"))

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgg"),
		100,
		300,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	canonical.NextBlock()

	// Incentive has been started, but but we can collect rewards accumulated until the previous block

	canonical.NextBlock()

	// now there is a single block worth of reward

	expected := uint64(100000000/4) * 30 / 100

	canonical.AssertEmulatedExternalRewardOf(uint64(0), incentiveId, expected)
}

func TestCanonicalExternalReward_2(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	canonical.CreatePool(gnousdc, 1, 200)

	currentHeight := int64(canonical.CurrentHeight())
	incentiveId := canonical.CreateExternalIncentive(gnousdc, gnsPath, 100000000, currentHeight+1, currentHeight+5, std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"))

	canonical.NextBlock()
	canonical.NextBlock()

	// Incentive has been already started

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgg"),
		100,
		300,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	canonical.NextBlock()

	// now there is a single block worth of reward

	expected := uint64(100000000/4) * 30 / 100

	canonical.AssertEmulatedExternalRewardOf(uint64(0), incentiveId, expected)
}

func TestCanonicalExternalReward_3(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	canonical.CreatePool(gnousdc, 1, 200)

	currentHeight := int64(canonical.CurrentHeight())
	incentiveId := canonical.CreateExternalIncentive(gnousdc, gnsPath, 100000000, currentHeight+1, currentHeight+5, std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"))

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgg"),
		100,
		300,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}
	canonical.NextBlock()

	// eligible

	canonical.NextBlock()

	// eligible

	canonical.NextBlock()

	canonical.CalculateCanonicalReward()

	// incentive has been ended

	expected := uint64(100000000/4*2) * 30 / 100

	canonical.AssertEmulatedExternalRewardOf(uint64(0), incentiveId, expected)
}

func TestCanonicalMultiplePool_1(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	gnousdc2 := GetPoolPath(wugnotPath, gnsPath, 10000)
	canonical.CreatePool(gnousdc, 1, 200)
	canonical.CreatePool(gnousdc2, 1, 200)

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"),
		100,
		300,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	err = canonical.StakeToken(
		1,
		gnousdc2,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgq"),
		200,
		400,
		u256.NewUint(2000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	canonical.NextBlock()

	expected := canonical.PerBlockEmission * 30 / 100

	canonical.AssertEmulatedRewardOf(0, expected/2)
	canonical.AssertEmulatedRewardOf(1, expected/2)

	canonical.MoveTick(gnousdc, 100)
	canonical.NextBlock()
	canonical.AssertEmulatedRewardOf(0, expected/2)
	canonical.AssertEmulatedRewardOf(1, expected/2)

	canonical.MoveTick(gnousdc2, 100)
	canonical.NextBlock()
	canonical.AssertEmulatedRewardOf(0, expected/2)
	canonical.AssertEmulatedRewardOf(1, 0)

	canonical.MoveTick(gnousdc, 100)
	canonical.NextBlock()
	canonical.AssertEmulatedRewardOf(0, expected/2)
	canonical.AssertEmulatedRewardOf(1, 0)

	canonical.MoveTick(gnousdc, 300)
	canonical.MoveTick(gnousdc2, 300)
	canonical.NextBlock()
	canonical.AssertEmulatedRewardOf(0, 0)
	canonical.AssertEmulatedRewardOf(1, expected/2)
}

func TestCanonicalMultiplePool_2(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	gnousdc2 := GetPoolPath(wugnotPath, gnsPath, 10000)
	gnousdc3 := GetPoolPath(wugnotPath, gnsPath, 30000)
	canonical.CreatePool(gnousdc, 1, 200)
	canonical.CreatePool(gnousdc2, 2, 200)
	canonical.CreatePool(gnousdc3, 3, 200)

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"),
		100,
		300,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	err = canonical.StakeToken(
		1,
		gnousdc2,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgq"),
		200,
		400,
		u256.NewUint(2000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	err = canonical.StakeToken(
		2,
		gnousdc3,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgz"),
		300,
		500,
		u256.NewUint(3000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	expected := canonical.PerBlockEmission * 30 / 100

	canonical.NextBlock()
	canonical.AssertEmulatedRewardOf(0, expected*50/100)
	canonical.AssertEmulatedRewardOf(1, expected*30/100)
	canonical.AssertEmulatedRewardOf(2, 0)
	canonical.MoveTick(gnousdc, 100)
	canonical.MoveTick(gnousdc2, 100)
	canonical.MoveTick(gnousdc3, 100)

	canonical.NextBlock()
	canonical.AssertEmulatedRewardOf(0, expected*50/100)
	canonical.AssertEmulatedRewardOf(1, 0)
	canonical.AssertEmulatedRewardOf(2, 0)
	canonical.MoveTick(gnousdc, 400)
	canonical.MoveTick(gnousdc2, 400)
	canonical.MoveTick(gnousdc3, 400)

	canonical.NextBlock()
	canonical.AssertEmulatedRewardOf(0, 0)
	canonical.AssertEmulatedRewardOf(1, 0)
	canonical.AssertEmulatedRewardOf(2, expected*20/100)
	canonical.ChangePoolTier(gnousdc2, 1)
	canonical.MoveTick(gnousdc, 200)
	canonical.MoveTick(gnousdc2, 300)
	canonical.MoveTick(gnousdc3, 400)

	canonical.NextBlock()
	canonical.AssertEmulatedRewardOf(0, expected*40/100)
	canonical.AssertEmulatedRewardOf(1, expected*40/100)
	canonical.AssertEmulatedRewardOf(2, expected*20/100)
}

// Large number of blocks passed
func TestCanonicalLargeBlocksPassed(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
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

	for i := 0; i < 10000; i++ {
		canonical.NextBlockNoCanonical()
	}

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))

	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected)
}

func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}
	return ufmt.Sprintf("%s:%s:%d", token0Path, token1Path, fee)
}

func TestCanonicalWarmup_1(t *testing.T) {
	modifyWarmup(0, 10)
	modifyWarmup(1, 10)
	modifyWarmup(2, 10)

	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
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

	canonical.CalculateCanonicalReward()

	expected := canonical.PerBlockEmission * 30 / 100

	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertEmulatedRewardOf(0, expected)

	expected = canonical.PerBlockEmission * 50 / 100

	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertEmulatedRewardOf(0, expected)

	expected = canonical.PerBlockEmission * 70 / 100

	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertEmulatedRewardOf(0, expected)

	expected = canonical.PerBlockEmission * 100 / 100

	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertEmulatedRewardOf(0, expected)
}

func TestCanonicalWarmup_2(t *testing.T) {
	modifyWarmup(0, 10)
	modifyWarmup(1, 10)
	modifyWarmup(2, 10)

	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
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

	canonical.CalculateCanonicalReward()

	expected0 := canonical.PerBlockEmission * 30 / 100

	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertEmulatedRewardOf(0, expected0)

	expected1 := canonical.PerBlockEmission * 50 / 100

	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertEmulatedRewardOf(0, expected1)

	expected2 := canonical.PerBlockEmission * 70 / 100

	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertEmulatedRewardOf(0, expected2)

	expected3 := canonical.PerBlockEmission * 100 / 100

	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.CalculateCanonicalReward()
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, int64(canonical.PerBlockEmission))
	canonical.AssertEmulatedRewardOf(0, expected3)
}

// ================
// randomized

// Removed skipped test TestCanonicalTickCross_7

// Test tick crossing with multiple positions with different tick, different liquidity
// Equivalence test
func TestCanonicalTickCross_8(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	canonical.CreatePool(gnousdc, 1, 200)

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"),
		100,
		300,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	err = canonical.StakeToken(
		1,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgq"),
		200,
		400,
		u256.NewUint(2000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	err = canonical.StakeToken(
		2,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgz"),
		300,
		500,
		u256.NewUint(3000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	tick := int32(0)

	for i := 0; i < 500; i++ {
		tick = (tick + 10007) % 700
		canonical.MoveTick(gnousdc, tick)
		canonical.NextBlock()
		canonical.AssertEquivalence(0)
		canonical.AssertEquivalence(1)
		canonical.AssertEquivalence(2)
	}
}

// Test tick crossing with multiple positions with different tick, different liquidity, emulated reward flushed for every 100 blocks
// Equivalence test
func TestCanonicalTickCross_9(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	canonical.CreatePool(gnousdc, 1, 200)

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"),
		100,
		300,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	err = canonical.StakeToken(
		1,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgq"),
		200,
		400,
		u256.NewUint(2000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	err = canonical.StakeToken(
		2,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgz"),
		300,
		500,
		u256.NewUint(3000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	tick := int32(0)
	for i := 0; i < 20; i++ {
		for j := 0; j < 20; j++ {
			tick = (tick + 10007) % 700
			canonical.MoveTick(gnousdc, tick)
			canonical.NextBlock()
			canonical.AssertCanonicalRewardOf(0, uint64(canonical.EmulatedRewardOf(0).Internal))
		}
	}
}

// Test tick crossing with multiple positions with different tick, different liquidity, emulated reward flushed for every 100 blocks
// Equivalence test
func TestCanonicalTickCross_10(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	canonical.CreatePool(gnousdc, 1, -200)

	err := canonical.StakeToken(
		0,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"),
		-300,
		-100,
		u256.NewUint(1000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	err = canonical.StakeToken(
		1,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgq"),
		-400,
		-200,
		u256.NewUint(2000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	err = canonical.StakeToken(
		2,
		gnousdc,
		std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgz"),
		-500,
		-300,
		u256.NewUint(3000000000000000000),
	)
	if err != nil {
		t.Errorf("StakeToken failed: %s", err.Error())
	}

	tick := int32(0)
	for i := 0; i < 20; i++ {
		for j := 0; j < 20; j++ {
			tick = (tick + 10007) % 700
			canonical.MoveTick(gnousdc, -tick)
			canonical.NextBlock()
			canonical.AssertCanonicalRewardOf(0, uint64(canonical.EmulatedRewardOf(0).Internal))
		}
	}
}
