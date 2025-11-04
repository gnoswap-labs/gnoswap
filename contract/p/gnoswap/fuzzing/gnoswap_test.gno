package fuzzing

import (
	"testing"

	"gno.land/p/gnoswap/int256"
	"gno.land/p/gnoswap/uint256"
)

// Big Number Tests

func TestGnoswap_Uint256(t *testing.T) {
	Check(t, func(ft *T) {
		val := ft.Uint256(128)

		// Should be a valid uint256
		if val == nil {
			ft.Fatalf("generated nil uint256")
		}
	})
}

func TestGnoswap_Uint256_Boundaries(t *testing.T) {
	seenZero := false
	seenOne := false
	cfg := &Config{Iterations: 200, BaseSeed: 1}

	CheckWithConfig(t, cfg, func(ft *T) {
		val := ft.Uint256WithBoundaries(128)

		if val.IsZero() {
			seenZero = true
		}
		if val.Eq(uint256.One()) {
			seenOne = true
		}
	})

	// With boundary bias, should see special values
	if !seenZero {
		t.Error("expected to see zero")
	}
	if !seenOne {
		t.Error("expected to see one")
	}
}

func TestGnoswap_Int256(t *testing.T) {
	Check(t, func(ft *T) {
		val := ft.Int256(true, true, 128)

		// Should be a valid int256
		if val == nil {
			ft.Fatalf("generated nil int256")
		}
	})
}

func TestGnoswap_Int256_NoZero(t *testing.T) {
	Check(t, func(ft *T) {
		val := ft.Int256(false, true, 64)

		// Should never be zero
		if val.IsZero() {
			ft.Fatalf("generated zero when allowZero=false")
		}
	})
}

func TestGnoswap_Int256_NoNegative(t *testing.T) {
	Check(t, func(ft *T) {
		val := ft.Int256(true, false, 64)

		// Should never be negative
		if val.Sign() < 0 {
			ft.Fatalf("generated negative when allowNegative=false")
		}
	})
}

func TestGnoswap_Int256_Boundaries(t *testing.T) {
	seenZero := false
	seenOne := false
	seenNegative := false
	cfg := &Config{Iterations: 200, BaseSeed: 1}

	CheckWithConfig(t, cfg, func(ft *T) {
		val := ft.Int256WithBoundaries(true, true, 128)

		if val.IsZero() {
			seenZero = true
		}
		if val.Eq(int256.One()) {
			seenOne = true
		}
		if val.Sign() < 0 {
			seenNegative = true
		}
	})

	// With boundary bias, should see special values
	if !seenZero {
		t.Error("expected to see zero")
	}
	if !seenOne {
		t.Error("expected to see one")
	}
	if !seenNegative {
		t.Error("expected to see negative values")
	}
}

// Pool & Position Tests

func TestGnoswap_TickRange(t *testing.T) {
	Check(t, func(ft *T) {
		tick := ft.TickRange(60)

		// Should be within bounds
		if tick < MIN_TICK || tick > MAX_TICK {
			ft.Fatalf("tick %d out of bounds [%d, %d]", tick, MIN_TICK, MAX_TICK)
		}

		// Should be aligned to spacing
		if tick%60 != 0 {
			ft.Fatalf("tick %d not aligned to spacing 60", tick)
		}
	})
}

func TestGnoswap_TickRange_Boundaries(t *testing.T) {
	seenMin := false
	seenMax := false
	seenZero := false
	cfg := &Config{Iterations: 500, BaseSeed: 1}

	CheckWithConfig(t, cfg, func(ft *T) {
		tick := ft.TickRangeWithBoundaries(10)

		if tick == MIN_TICK {
			seenMin = true
		}
		if tick == MAX_TICK {
			seenMax = true
		}
		if tick == 0 {
			seenZero = true
		}
	})

	// With boundary bias, should see edge values
	if !seenMin {
		t.Error("expected to see MIN_TICK")
	}
	if !seenMax {
		t.Error("expected to see MAX_TICK")
	}
	if !seenZero {
		t.Error("expected to see zero")
	}
}

func TestGnoswap_FeeAmount(t *testing.T) {
	seen := make(map[uint32]bool)
	cfg := &Config{Iterations: 100, BaseSeed: 1}

	CheckWithConfig(t, cfg, func(ft *T) {
		fee := ft.FeeAmount()
		seen[fee] = true

		// Should be one of valid fee tiers
		validFees := map[uint32]bool{100: true, 500: true, 3000: true, 10000: true}
		if !validFees[fee] {
			ft.Fatalf("invalid fee amount: %d", fee)
		}
	})

	// Should see multiple different fee tiers
	if len(seen) < 2 {
		t.Errorf("expected to see at least 2 different fee tiers, got %d", len(seen))
	}
}

func TestGnoswap_TickSpacing(t *testing.T) {
	tests := []struct {
		feeAmount       uint32
		expectedSpacing int32
	}{
		{100, 1},
		{500, 10},
		{3000, 60},
		{10000, 200},
	}

	for _, tc := range tests {
		Check(t, func(ft *T) {
			spacing := ft.TickSpacing(tc.feeAmount)
			if spacing != tc.expectedSpacing {
				ft.Fatalf("fee %d: expected spacing %d, got %d",
					tc.feeAmount, tc.expectedSpacing, spacing)
			}
		})
	}
}

// Token & Address Tests

func TestGnoswap_GnoAddress(t *testing.T) {
	Check(t, func(ft *T) {
		addr := ft.GnoAddress()

		// Should start with g1
		if len(addr) < 2 || addr[:2] != "g1" {
			ft.Fatalf("invalid address format: %s", addr)
		}

		// Should be 40 characters total (g1 + 38 chars)
		if len(addr) != 40 {
			ft.Fatalf("invalid address length: %d", len(addr))
		}
	})
}

func TestGnoswap_TokenPath(t *testing.T) {
	seen := make(map[string]bool)
	cfg := &Config{Iterations: 100, BaseSeed: 1}

	CheckWithConfig(t, cfg, func(ft *T) {
		path := ft.TokenPath()
		seen[path] = true

		// Should be a valid realm path
		if len(path) < 10 || path[:9] != "gno.land/" {
			ft.Fatalf("invalid token path: %s", path)
		}
	})

	// Should see multiple different paths
	if len(seen) < 2 {
		t.Errorf("expected to see at least 2 different token paths, got %d", len(seen))
	}
}

func TestGnoswap_TokenPair(t *testing.T) {
	Check(t, func(ft *T) {
		pair := ft.TokenPair()

		// Should return 2 paths
		if len(pair) != 2 {
			ft.Fatalf("expected 2 tokens, got %d", len(pair))
		}

		// Should be distinct
		if pair[0] == pair[1] {
			ft.Fatalf("tokens not distinct: %s", pair[0])
		}

		// Both should be valid paths
		for _, path := range pair {
			if len(path) < 10 || path[:9] != "gno.land/" {
				ft.Fatalf("invalid token path: %s", path)
			}
		}
	})
}

// Time & Ratio Tests

func TestGnoswap_Timestamp(t *testing.T) {
	Check(t, func(ft *T) {
		ts := ft.Timestamp(1600000000, 1700000000)

		// Should be within range
		if ts < 1600000000 || ts > 1700000000 {
			ft.Fatalf("timestamp %d out of range", ts)
		}
	})
}

func TestGnoswap_Timestamp_Boundaries(t *testing.T) {
	seenMin := false
	seenMax := false
	cfg := &Config{Iterations: 200, BaseSeed: 1}

	CheckWithConfig(t, cfg, func(ft *T) {
		ts := ft.Timestamp(1000000000, 2000000000)

		if ts == 1000000000 {
			seenMin = true
		}
		if ts == 2000000000 {
			seenMax = true
		}
	})

	// With boundary bias, should see edge values
	if !seenMin {
		t.Error("expected to see min timestamp")
	}
	if !seenMax {
		t.Error("expected to see max timestamp")
	}
}

func TestGnoswap_Percentage(t *testing.T) {
	Check(t, func(ft *T) {
		pct := ft.Percentage()

		// Should be in range [0, 10000]
		if pct > 10000 {
			ft.Fatalf("percentage %d out of range", pct)
		}
	})
}

func TestGnoswap_Percentage_CommonValues(t *testing.T) {
	seen := make(map[uint64]bool)
	cfg := &Config{Iterations: 200, BaseSeed: 1}

	CheckWithConfig(t, cfg, func(ft *T) {
		pct := ft.Percentage()
		seen[pct] = true
	})

	// Should see common values (0%, 25%, 50%, 75%, 100%)
	commonValues := []uint64{0, 2500, 5000, 7500, 10000}
	seenCommon := 0
	for _, v := range commonValues {
		if seen[v] {
			seenCommon++
		}
	}

	if seenCommon < 2 {
		t.Errorf("expected to see at least 2 common percentage values, got %d", seenCommon)
	}
}

func TestGnoswap_BasisPoints(t *testing.T) {
	Check(t, func(ft *T) {
		bp := ft.BasisPoints(500)

		// Should be in range [0, 500]
		if bp > 500 {
			ft.Fatalf("basis points %d out of range", bp)
		}
	})
}

func TestGnoswap_BasisPoints_Zero(t *testing.T) {
	seenZero := false
	cfg := &Config{Iterations: 100, BaseSeed: 1}

	CheckWithConfig(t, cfg, func(ft *T) {
		bp := ft.BasisPoints(100)
		if bp == 0 {
			seenZero = true
		}
	})

	// With 10% bias, should see zero
	if !seenZero {
		t.Error("expected to see zero basis points")
	}
}

// Integration Tests

func TestGnoswap_PoolScenario(t *testing.T) {
	Check(t, func(ft *T) {
		// Generate pool parameters
		feeAmount := ft.FeeAmount()
		tickSpacing := ft.TickSpacing(feeAmount)
		tickLower := ft.TickRange(tickSpacing)
		tickUpper := ft.TickRange(tickSpacing)

		// Ensure proper ordering
		if tickLower > tickUpper {
			tickLower, tickUpper = tickUpper, tickLower
		}

		// Generate token pair
		tokens := ft.TokenPair()

		// Generate amounts
		amount0 := ft.Uint256(96)
		amount1 := ft.Uint256(96)

		// All should be valid
		if tickLower < MIN_TICK || tickUpper > MAX_TICK {
			ft.Fatalf("ticks out of bounds")
		}
		if tickLower >= tickUpper {
			ft.Fatalf("invalid tick range")
		}
		if len(tokens) != 2 || tokens[0] == tokens[1] {
			ft.Fatalf("invalid token pair")
		}
		if amount0 == nil || amount1 == nil {
			ft.Fatalf("nil amounts")
		}
	})
}

func TestGnoswap_DeterministicGeneration(t *testing.T) {
	cfg := &Config{Iterations: 10, BaseSeed: 42}

	// First run
	values1 := []int32{}
	CheckWithConfig(t, cfg, func(ft *T) {
		tick := ft.TickRange(60)
		values1 = append(values1, tick)
	})

	// Second run with same seed
	values2 := []int32{}
	CheckWithConfig(t, cfg, func(ft *T) {
		tick := ft.TickRange(60)
		values2 = append(values2, tick)
	})

	// Should generate same values
	if len(values1) != len(values2) {
		t.Fatalf("different lengths: %d vs %d", len(values1), len(values2))
	}
	for i := range values1 {
		if values1[i] != values2[i] {
			t.Errorf("iteration %d: %d vs %d", i, values1[i], values2[i])
		}
	}
}
