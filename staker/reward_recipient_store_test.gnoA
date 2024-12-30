package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestAddInRangePosition(t *testing.T) {
	tests := []struct {
		name    string
		tokenID uint64
		setup   func() (*PoolLiquidity, *InRangeLiquidity)
		verify  func(*PoolLiquidity)
	}{
		{
			name:    "Normal position addition",
			tokenID: 1,
			setup: func() (*PoolLiquidity, *InRangeLiquidity) {
				poolLiquidity := NewPoolLiquidity()
				position := NewInRangeLiquidity()
				position.SetLiquidity(u256.NewUint(1000))
				position.SetLiquidityRatio(u256.NewUint(100))
				position.SetStakedHeight(50)
				return poolLiquidity, position
			},
			verify: func(p *PoolLiquidity) {
				checkIfMapIsInitialized(t, p.inRangeLiquidityMap)

				position := p.GetInRangeLiquidity(1)
				checkIfPositionIsStoredCorrectly(t, position)
				checkIfLiquidityIsStoredCorrectly(t, position, u256.NewUint(1000))
				checkIfTotalLiquidityIsStoredCorrectly(t, p, u256.NewUint(1000))
			},
		},
		{
			name:    "nil position addition",
			tokenID: 2,
			setup: func() (*PoolLiquidity, *InRangeLiquidity) {
				poolLiquidity := NewPoolLiquidity()
				return poolLiquidity, nil
			},
			verify: func(p *PoolLiquidity) {
				checkIfMapIsInitialized(t, p.inRangeLiquidityMap)

				position := p.GetInRangeLiquidity(2)
				checkIfPositionIsStoredCorrectly(t, position)

				if !position.GetLiquidity().IsZero() {
					t.Errorf("liquidity should be zero, got %s", position.GetLiquidity().ToString())
				}
			},
		},
		{
			name:    "nil map addition",
			tokenID: 3,
			setup: func() (*PoolLiquidity, *InRangeLiquidity) {
				poolLiquidity := &PoolLiquidity{
					inRangeLiquidityMap: nil,
					totalLiquidity:      nil,
				}
				position := NewInRangeLiquidity()
				position.SetLiquidity(u256.NewUint(500))
				return poolLiquidity, position
			},
			verify: func(p *PoolLiquidity) {
				checkIfMapIsInitialized(t, p.inRangeLiquidityMap)

				position := p.GetInRangeLiquidity(3)
				checkIfPositionIsStoredCorrectly(t, position)
				checkIfLiquidityIsStoredCorrectly(t, position, u256.NewUint(500))
				checkIfTotalLiquidityIsStoredCorrectly(t, p, u256.NewUint(500))
			},
		},
		{
			name:    "Multiple position addition",
			tokenID: 4,
			setup: func() (*PoolLiquidity, *InRangeLiquidity) {
				poolLiquidity := NewPoolLiquidity()

				// first position addition
				position1 := NewInRangeLiquidity()
				position1.SetLiquidity(u256.NewUint(300))
				poolLiquidity.AddInRangePosition(1, position1)

				// second position addition (test position)
				position2 := NewInRangeLiquidity()
				position2.SetLiquidity(u256.NewUint(700))

				return poolLiquidity, position2
			},
			verify: func(p *PoolLiquidity) {
				// check if total liquidity is stored correctly (300 + 700 = 1000)
				if !p.GetTotalLiquidity().Eq(u256.NewUint(1000)) {
					t.Errorf("expected total liquidity 1000, got %s", p.GetTotalLiquidity().ToString())
				}

				// check if each position is stored correctly
				position1 := p.GetInRangeLiquidity(1)
				checkIfLiquidityIsStoredCorrectly(t, position1, u256.NewUint(300))

				position2 := p.GetInRangeLiquidity(4)
				checkIfLiquidityIsStoredCorrectly(t, position2, u256.NewUint(700))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolLiquidity, position := tt.setup()
			poolLiquidity.AddInRangePosition(tt.tokenID, position)
			tt.verify(poolLiquidity)
		})
	}
}

func checkIfMapIsInitialized(
	t *testing.T,
	targetMap map[uint64]*InRangeLiquidity,
) {
	t.Helper()
	if targetMap == nil {
		t.Error("targetMap should be initialized")
	}
}

func checkIfPositionIsStoredCorrectly(
	t *testing.T,
	targetPosition *InRangeLiquidity,
) {
	t.Helper()

	if targetPosition == nil {
		t.Error("targetPosition should not be nil")
	}
}

func checkIfLiquidityIsStoredCorrectly(
	t *testing.T,
	position *InRangeLiquidity,
	expectedLiquidity *u256.Uint,
) {
	t.Helper()

	if !position.GetLiquidity().Eq(expectedLiquidity) {
		t.Errorf("expected liquidity %s, got %s", expectedLiquidity.ToString(), position.GetLiquidity().ToString())
	}
}

func checkIfTotalLiquidityIsStoredCorrectly(
	t *testing.T,
	poolLiquidity *PoolLiquidity,
	expectedTotalLiquidity *u256.Uint,
) {
	t.Helper()

	if !poolLiquidity.GetTotalLiquidity().Eq(expectedTotalLiquidity) {
		t.Errorf("expected total liquidity %s, got %s", expectedTotalLiquidity.ToString(), poolLiquidity.GetTotalLiquidity().ToString())
	}
}
