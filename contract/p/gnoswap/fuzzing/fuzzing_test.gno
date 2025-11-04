package fuzzing

import (
	"testing"
)

// Test Check function with successful property
func TestFuzzing_Check_Success(t *testing.T) {
	passCount := 0
	Check(t, func(ft *T) {
		x := ft.IntRange(0, 100)
		if x < 0 || x > 100 {
			ft.Fatalf("x out of range: %d", x)
		}
		passCount++
	})

	// Default iterations is 100
	if passCount != 100 {
		t.Errorf("expected 100 iterations, got %d", passCount)
	}
}

// Test Check function verifies all generated values are valid
func TestFuzzing_Check_AllValid(t *testing.T) {
	passCount := 0
	Check(t, func(ft *T) {
		x := ft.IntRange(0, 100)
		// All values should be in range
		if x < 0 || x > 100 {
			ft.Fatalf("value out of range: %d", x)
		}
		passCount++
	})

	if passCount != 100 {
		t.Errorf("expected 100 passes, got %d", passCount)
	}
}

// Test CheckWithConfig with custom iterations
func TestFuzzing_CheckWithConfig_CustomIterations(t *testing.T) {
	passCount := 0
	cfg := &Config{
		Iterations: 50,
		BaseSeed:   12345,
	}

	CheckWithConfig(t, cfg, func(ft *T) {
		x := ft.IntRange(0, 100)
		if x < 0 || x > 100 {
			ft.Fatalf("x out of range: %d", x)
		}
		passCount++
	})

	if passCount != 50 {
		t.Errorf("expected 50 iterations, got %d", passCount)
	}
}

// Test CheckWithConfig with deterministic seed
func TestFuzzing_CheckWithConfig_DeterministicSeed(t *testing.T) {
	cfg := &Config{
		Iterations: 10,
		BaseSeed:   9999,
	}

	// First run
	values1 := []int{}
	CheckWithConfig(t, cfg, func(ft *T) {
		x := ft.IntRange(0, 1000)
		values1 = append(values1, x)
	})

	// Second run with same seed
	values2 := []int{}
	CheckWithConfig(t, cfg, func(ft *T) {
		x := ft.IntRange(0, 1000)
		values2 = append(values2, x)
	})

	// Should generate same values
	if len(values1) != len(values2) {
		t.Fatalf("different lengths: %d vs %d", len(values1), len(values2))
	}
	for i := range values1 {
		if values1[i] != values2[i] {
			t.Errorf("iteration %d: values differ: %d vs %d", i, values1[i], values2[i])
		}
	}
}

// Test CheckWithConfig with verbose mode
func TestFuzzing_CheckWithConfig_Verbose(t *testing.T) {
	cfg := &Config{
		Iterations: 5,
		Verbose:    true,
	}

	passCount := 0
	CheckWithConfig(t, cfg, func(ft *T) {
		_ = ft.IntRange(0, 10)
		passCount++
	})

	if passCount != 5 {
		t.Errorf("expected 5 iterations, got %d", passCount)
	}
}

// Test T.Fatalf causes panic
func TestT_Fatalf(t *testing.T) {
	ft := newT(1, false)

	defer func() {
		r := recover()
		if r == nil {
			t.Fatal("expected panic from Fatalf")
		}
		// Just verify that it panicked
	}()

	ft.Fatalf("test failed: %d", 42)
}

// Test T.Errorf causes panic
func TestT_Errorf(t *testing.T) {
	ft := newT(1, false)

	defer func() {
		r := recover()
		if r == nil {
			t.Fatal("expected panic from Errorf")
		}
		// Just verify that it panicked
	}()

	ft.Errorf("error: value=%d", 100)
}

// Test T.Logf (should not panic)
func TestT_Logf(t *testing.T) {
	ft := newT(1, true)

	// Should not panic
	ft.Logf("test message: %d", 123)
	ft.Logf("another message")
}

// Test Config default values
func TestFuzzing_Config_Defaults(t *testing.T) {
	// nil config should use defaults
	passCount := 0
	CheckWithConfig(t, nil, func(ft *T) {
		passCount++
	})

	// Default iterations is 100
	if passCount != 100 {
		t.Errorf("expected default 100 iterations, got %d", passCount)
	}
}

// Test multiple generator calls in single property
func TestFuzzing_MultipleGenerators(t *testing.T) {
	Check(t, func(ft *T) {
		x := ft.IntRange(0, 100)
		y := ft.IntRange(0, 100)
		s := ft.String()
		b := ft.Bool()

		// All should be valid
		if x < 0 || x > 100 {
			ft.Fatalf("x out of range: %d", x)
		}
		if y < 0 || y > 100 {
			ft.Fatalf("y out of range: %d", y)
		}
		if s == "" {
			// Empty strings are valid
		}
		if b {
			// true is valid
		}
	})
}

// Test edge case: zero iterations
func TestFuzzing_CheckWithConfig_ZeroIterations(t *testing.T) {
	cfg := &Config{
		Iterations: 0, // Should default to 100
	}

	passCount := 0
	CheckWithConfig(t, cfg, func(ft *T) {
		passCount++
	})

	if passCount != 100 {
		t.Errorf("expected 100 iterations (default), got %d", passCount)
	}
}

// Test property that uses Filter
func TestFuzzing_WithFilter(t *testing.T) {
	Check(t, func(ft *T) {
		// Generate even number
		gen := Filter(IntRange(0, 100), func(v any) bool {
			return v.(int)%2 == 0
		})

		x := gen.value(ft).(int)

		if x%2 != 0 {
			ft.Fatalf("expected even number, got %d", x)
		}
	})
}

// Test property that uses Map
func TestFuzzing_WithMap(t *testing.T) {
	Check(t, func(ft *T) {
		// Generate number and double it
		gen := Map(IntRange(0, 50), func(v any) any {
			return v.(int) * 2
		})

		x := gen.value(ft).(int)

		// Result should be even and in range [0, 100]
		if x%2 != 0 {
			ft.Fatalf("expected even number, got %d", x)
		}
		if x < 0 || x > 100 {
			ft.Fatalf("x out of range: %d", x)
		}
	})
}

// Test property that uses OneOf
func TestFuzzing_WithOneOf(t *testing.T) {
	Check(t, func(ft *T) {
		x := ft.OneOf(
			Just(10),
			Just(20),
			Just(30),
		)

		val := x.(int)
		if val != 10 && val != 20 && val != 30 {
			ft.Fatalf("unexpected value: %d", val)
		}
	})
}

// Test T.Repeat
func TestT_Repeat(t *testing.T) {
	Check(t, func(ft *T) {
		count := 0
		ft.Repeat(5, 10, func() bool {
			count++
			return true
		})

		if count < 5 || count > 10 {
			ft.Fatalf("repeat count out of range: %d", count)
		}
	})
}

// Test T.Repeat always accepts
func TestT_Repeat_AllAccept(t *testing.T) {
	Check(t, func(ft *T) {
		count := 0
		ft.Repeat(1, 5, func() bool {
			count++
			// Always accept
			return true
		})

		// Should run at least once
		if count == 0 {
			ft.Fatalf("no iterations executed")
		}
	})
}
