package staker

// Evaluate against the canonical implementation

import (
	"math"
	"std"
	"strings"
	"testing"

	ufmt "gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

func Setup(t *testing.T) *canonicalRewardState {
	poolTier := NewPoolTier(1, test_gnousdc)
	pools := NewPools()
	deposits := NewDeposits()

	return NewCanonicalRewardState(t, poolTier, pools, deposits, TickCrossHook)
}

func TestSimple(t *testing.T) {
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

	// gnousdc takes the entire emission
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.PerBlockEmission)

	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected)
	canonical.AssertCanonicalRewardOf(0, expected)
}

// To check precision error
func TestLargeStakedLiquidity(t *testing.T) {
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

	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.PerBlockEmission)

	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected)
	canonical.AssertCanonicalRewardOf(0, expected)
}

// To check precision error
func TestLargeStakedLiquidity_2(t *testing.T) {
	canonical := Setup(t)

	gnousdc := test_gnousdc
	canonical.CreatePool(gnousdc, 1, 150)

	u2_30 := uint64(1073741824)
	u2_33 := uint64(17179869184 / 2)

	canonical.SetEmissionUpdate(math.MaxUint64 / 100)

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

	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.PerBlockEmission)

	expected := canonical.PerBlockEmission / 100 * 30
	canonical.AssertEmulatedRewardOf(0, expected/9)
	canonical.AssertCanonicalRewardOf(0, expected/9)

	canonical.AssertEmulatedRewardOf(1, expected/9*8)
	canonical.AssertCanonicalRewardOf(1, expected/9*8)
}

// Tests simple case with tick crossing
func TestTickCross_0(t *testing.T) {
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
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.PerBlockEmission)

	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected)
	canonical.AssertCanonicalRewardOf(0, expected)

	// The position is now outrange. The reward must be reduced.
	canonical.MoveTick(gnousdc, 90)

	canonical.NextBlock()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.PerBlockEmission)

	canonical.AssertEmulatedRewardOf(0, 0)
	canonical.AssertCanonicalRewardOf(0, 0)

	// The position remains outrange.
	canonical.MoveTick(gnousdc, 80)

	canonical.NextBlock()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.PerBlockEmission)

	canonical.AssertEmulatedRewardOf(0, 0)
	canonical.AssertCanonicalRewardOf(0, 0)

	// The tick passes through the positions range, remains outrange.
	canonical.MoveTick(gnousdc, 220)

	canonical.NextBlock()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.PerBlockEmission)

	canonical.AssertEmulatedRewardOf(0, 0)
	canonical.AssertCanonicalRewardOf(0, 0)

	// The tick goes back to the range.
	canonical.MoveTick(gnousdc, 180)

	canonical.NextBlock()

	// gnousdc still takes the entire emission, independent from position inrangeness
	canonical.AssertCanonicalInternalRewardPerPool(gnousdc, canonical.PerBlockEmission)

	// The position is now inrange, so it takes the entire emission
	canonical.AssertEmulatedRewardOf(0, expected)
	canonical.AssertCanonicalRewardOf(0, expected)
}

// Tests tick crossing with lazy evaluation of position reward
func TestTickCross_1(t *testing.T) {
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

	canonical.NextBlockNoCanonical()

	// We check that emulated reward is lazy evaluated when we finally calculate it.
	// It takes the two block's emission into account.
	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected*2)
}

// Test tick crossing with multiple positions with same tick, same liquidity
func TestTickCross_2(t *testing.T) {
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

	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected*3/2)
	canonical.AssertEmulatedRewardOf(1, expected*3/2)
}

// Test tick crossing with multiple positions with same tick, different liquidity
func TestTickCross_3(t *testing.T) {
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

	// not eligible
	canonical.MoveTick(gnousdc, 80)
	canonical.NextBlockNoCanonical()

	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected*2*1/4)
	canonical.AssertEmulatedRewardOf(1, expected*2*3/4)
}

// Test tick crossing with multiple positions with different tick, same liquidity
func TestTickCross_4(t *testing.T) {
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
	canonical.AssertCanonicalRewardOf(0, expected)
	canonical.AssertCanonicalRewardOf(1, 0)
	// 0 eligible, 1 not eligible (100:0)
	canonical.MoveTick(gnousdc, 101)
	canonical.NextBlock()
	canonical.AssertCanonicalRewardOf(0, expected)
	canonical.AssertCanonicalRewardOf(1, 0)

	// 0 eligible, 1 eligible (50:50)
	canonical.MoveTick(gnousdc, 201)
	canonical.NextBlock()
	canonical.AssertCanonicalRewardOf(0, expected/2)
	canonical.AssertCanonicalRewardOf(1, expected/2)

	// 0 not eligible, 1 not eligible (0:0)
	canonical.MoveTick(gnousdc, 401)
	canonical.NextBlock()
	canonical.AssertCanonicalRewardOf(0, 0)
	canonical.AssertCanonicalRewardOf(1, 0)

	// 0 not eligible, 1 eligible (0:100)
	canonical.MoveTick(gnousdc, 301)
	canonical.NextBlock()
	canonical.AssertCanonicalRewardOf(0, 0)
	canonical.AssertCanonicalRewardOf(1, expected)

	// 0 total ratio: 250
	// 1 total ratio: 150

	canonical.AssertEmulatedRewardOf(0, expected*4*250/400)
	canonical.AssertEmulatedRewardOf(1, expected*4*150/400)
}

// Test tick crossing at tick boundaries, forward direction
func TestTickCross_5(t *testing.T) {
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

	canonical.AssertCanonicalRewardOf(0, 0)
	canonical.AssertEmulatedRewardOf(0, 0)
}

// Test tick crossing at tick boundaries, backward direction
func TestTickCross_6(t *testing.T) {
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

	canonical.AssertEmulatedRewardOf(0, 0)

	// not eligible
	canonical.MoveTick(gnousdc, 300)
	canonical.NextBlockNoCanonical()

	canonical.AssertEmulatedRewardOf(0, 0)

	// eligible
	canonical.MoveTick(gnousdc, 299)
	canonical.NextBlockNoCanonical()

	canonical.AssertEmulatedRewardOf(0, expected)

	// eligible
	canonical.MoveTick(gnousdc, 101)
	canonical.NextBlockNoCanonical()

	canonical.AssertEmulatedRewardOf(0, expected)

	// eligible
	canonical.MoveTick(gnousdc, 100)
	canonical.NextBlockNoCanonical()

	canonical.AssertEmulatedRewardOf(0, expected)

	// not eligible
	canonical.MoveTick(gnousdc, 99)
	canonical.NextBlockNoCanonical()

	canonical.AssertEmulatedRewardOf(0, 0)
}

func TestExternalReward_1(t *testing.T) {
	canonical := Setup(t)

	gnousdc := GetPoolPath(wugnotPath, gnsPath, 3000)
	canonical.CreatePool(gnousdc, 1, 200)

	incentiveId := canonical.CreateExternalIncentive(gnousdc, gnsPath, 100000000, 1, 5, 1, 5, std.Address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"))

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

	expected := uint64(100000000/4) * 30 / 100

	canonical.AssertEmulatedExternalRewardOf(uint64(0), incentiveId, expected)
}

func TestMultiplePool_1(t *testing.T) {
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

func TestMultiplePool_2(t *testing.T) {
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
func TestLargeBlocksPassed(t *testing.T) {
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

	expected := canonical.PerBlockEmission * 30 / 100
	canonical.AssertEmulatedRewardOf(0, expected*10000)
}

func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}
	return ufmt.Sprintf("%s:%s:%d", token0Path, token1Path, fee)
}

func TestWarmup_1(t *testing.T) {
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
	canonical.NextBlock()
	canonical.AssertEmulatedRewardOf(0, expected*10)

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
	canonical.AssertEmulatedRewardOf(0, expected*10)

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
	canonical.AssertEmulatedRewardOf(0, expected*10)

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
	canonical.AssertEmulatedRewardOf(0, expected*10)
}

func TestWarmup_2(t *testing.T) {
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
	canonical.NextBlock()

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

	canonical.AssertEmulatedRewardOf(0, expected0*10+expected1*10+expected2*10+expected3*10)

}

// ================
// randomized

// Test tick crossing at tick boundaries, random direction
func TestTickCross_7(t *testing.T) {
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

	tcs := []struct {
		tick     int32
		expected uint64
	}{
		{99, 0},
		{100, expected},
		{101, expected},
		{299, expected},
		{300, 0},
		{301, 0},
	}

	index := 0
	for i := 0; i < 100; i++ {
		index = (index + 10007) % len(tcs)
		canonical.MoveTick(gnousdc, tcs[index].tick)
		canonical.NextBlockNoCanonical()
		canonical.AssertEmulatedRewardOf(0, tcs[index].expected)
	}
}

// Test tick crossing with multiple positions with different tick, different liquidity
// Equivalence test
func TestTickCross_8(t *testing.T) {
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
func TestTickCross_9(t *testing.T) {
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
		canonicalRewardMap := make(map[uint64]uint64)
		for j := 0; j < 20; j++ {
			tick = (tick + 10007) % 700
			canonical.MoveTick(gnousdc, tick)
			canonical.NextBlock()
			canonicalRewardMap[0] += canonical.CanonicalRewardOf(0).Internal
			canonicalRewardMap[1] += canonical.CanonicalRewardOf(1).Internal
			canonicalRewardMap[2] += canonical.CanonicalRewardOf(2).Internal
		}
		canonical.AssertEmulatedRewardMap(canonicalRewardMap)
	}
}