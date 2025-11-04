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

// Test Check function with failing property
func TestFuzzing_Check_Failure(t *testing.T) {
	mockT := &mockTestingT{}

	Check(mockT, func(ft *T) {
		x := ft.IntRange(0, 100)
		// Intentionally fail on some values
		if x == 50 {
			ft.Fatalf("found forbidden value: %d", x)
		}
	})

	// Should have recorded a failure
	if !mockT.failed {
		t.Error("expected test to fail but it passed")
	}
	if mockT.errorMsg == "" {
		t.Error("expected error message but got empty string")
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

// Test T.Fatalf
func TestT_Fatalf(t *testing.T) {
	ft := newT(1, false)

	defer func() {
		r := recover()
		if r == nil {
			t.Fatal("expected panic from Fatalf")
		}

		tf, ok := r.(*testFailure)
		if !ok {
			t.Fatalf("expected *testFailure, got %T", r)
		}

		if tf.msg != "test failed: 42" {
			t.Errorf("expected 'test failed: 42', got '%s'", tf.msg)
		}
	}()

	ft.Fatalf("test failed: %d", 42)
}

// Test T.Errorf
func TestT_Errorf(t *testing.T) {
	ft := newT(1, false)

	defer func() {
		r := recover()
		if r == nil {
			t.Fatal("expected panic from Errorf")
		}

		tf, ok := r.(*testFailure)
		if !ok {
			t.Fatalf("expected *testFailure, got %T", r)
		}

		if tf.msg != "error: value=100" {
			t.Errorf("expected 'error: value=100', got '%s'", tf.msg)
		}
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
	mockT := &mockTestingT{}

	// nil config should use defaults
	passCount := 0
	CheckWithConfig(mockT, nil, func(ft *T) {
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

// Test T.Repeat with rejection
func TestT_Repeat_WithRejection(t *testing.T) {
	Check(t, func(ft *T) {
		acceptCount := 0
		ft.Repeat(5, 10, func() bool {
			x := ft.IntRange(0, 100)
			// Accept only even numbers
			if x%2 == 0 {
				acceptCount++
				return true
			}
			return false
		})

		if acceptCount < 5 || acceptCount > 10 {
			ft.Fatalf("accept count out of range: %d", acceptCount)
		}
	})
}

// Mock testing.T for testing test failures
type mockTestingT struct {
	failed   bool
	errorMsg string
}

func (m *mockTestingT) Errorf(format string, args ...interface{}) {
	m.failed = true
	m.errorMsg = format
}

func (m *mockTestingT) Logf(format string, args ...interface{}) {
	// Do nothing
}

func (m *mockTestingT) Helper() {
	// Do nothing
}

func (m *mockTestingT) FailNow() {
	m.failed = true
	panic("test failed")
}

func (m *mockTestingT) Failed() bool {
	return m.failed
}
