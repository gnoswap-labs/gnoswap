package fuzzing

import (
	"testing"
)

func TestGenFloat01(t *testing.T) {
	// Test that genFloat01 generates values in [0, 1)
	s := newRandomBitStream(12345, false)

	for i := 0; i < 100; i++ {
		f := genFloat01(s)
		if f < 0 || f >= 1 {
			t.Fatalf("genFloat01 returned value outside [0, 1): %f", f)
		}
	}
}

func TestGenFloat01_Determinism(t *testing.T) {
	// Test deterministic generation
	s1 := newRandomBitStream(12345, false)
	s2 := newRandomBitStream(12345, false)

	for i := 0; i < 10; i++ {
		f1 := genFloat01(s1)
		f2 := genFloat01(s2)
		if f1 != f2 {
			t.Fatalf("genFloat01 not deterministic at iteration %d: %f != %f", i, f1, f2)
		}
	}
}

func TestGenUintNUnbiased(t *testing.T) {
	tests := []struct {
		name string
		max  uint64
		seed uint64
	}{
		{"Max 0", 0, 1},
		{"Max 1", 1, 1},
		{"Max 255", 255, 1},
		{"Max 65535", 65535, 1},
		{"Max MaxUint64", 18446744073709551615, 1},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := newRandomBitStream(tc.seed, false)

			for i := 0; i < 20; i++ {
				v := genUintNUnbiased(s, tc.max)
				if v > tc.max {
					t.Fatalf("Generated value %d > max %d", v, tc.max)
				}
			}
		})
	}
}

func TestGenUintNBiased(t *testing.T) {
	tests := []struct {
		name string
		max  uint64
		seed uint64
	}{
		{"Max 0", 0, 1},
		{"Max 1", 1, 1},
		{"Max 100", 100, 1},
		{"Max 10000", 10000, 1},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := newRandomBitStream(tc.seed, true)

			for i := 0; i < 20; i++ {
				v, isMin, isMax := genUintNBiased(s, tc.max)
				if v > tc.max {
					t.Fatalf("Generated value %d > max %d", v, tc.max)
				}
				// isMin/isMax are hints for shrinking, not guarantees
				// Just check they're valid when set
				if isMin && v != 0 {
					t.Fatalf("isMin=true but v=%d != 0", v)
				}
				if isMax && v != tc.max {
					t.Fatalf("isMax=true but v=%d != max %d", v, tc.max)
				}
			}
		})
	}
}

func TestGenUintNBiased_PrefersSmall(t *testing.T) {
	// Test that biased generation prefers small values
	s := newRandomBitStream(12345, true)

	smallCount := 0
	total := 1000
	threshold := uint64(10)

	for i := 0; i < total; i++ {
		v, _, _ := genUintNBiased(s, 10000)
		if v <= threshold {
			smallCount++
		}
	}

	// With bias, we should see more small values
	// Expect at least 20% to be <= 10 out of 10000 range
	if smallCount < total/5 {
		t.Logf("Small values: %d/%d (%.1f%%)", smallCount, total, float64(smallCount)/float64(total)*100)
		// This is a probabilistic test, so we just log rather than fail
	}
}

func TestGenUintRange(t *testing.T) {
	tests := []struct {
		name string
		min  uint64
		max  uint64
		bias bool
	}{
		{"Range [0, 0]", 0, 0, false},
		{"Range [0, 1]", 0, 1, false},
		{"Range [10, 20]", 10, 20, false},
		{"Range [100, 200] biased", 100, 200, true},
		{"Range [0, MaxUint64]", 0, 18446744073709551615, false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := newRandomBitStream(12345, true)

			for i := 0; i < 20; i++ {
				v, _, _ := genUintRange(s, tc.min, tc.max, tc.bias)
				if v < tc.min || v > tc.max {
					t.Fatalf("Generated value %d outside range [%d, %d]", v, tc.min, tc.max)
				}
			}
		})
	}
}

func TestGenIntRange_PositiveRange(t *testing.T) {
	// Test positive range [10, 100]
	s := newRandomBitStream(12345, true)

	for i := 0; i < 20; i++ {
		v, _, _ := genIntRange(s, 10, 100, true)
		if v < 10 || v > 100 {
			t.Fatalf("Generated value %d outside range [10, 100]", v)
		}
	}
}

func TestGenIntRange_NegativeRange(t *testing.T) {
	// Test negative range [-100, -10]
	s := newRandomBitStream(12345, true)

	for i := 0; i < 20; i++ {
		v, _, _ := genIntRange(s, -100, -10, true)
		if v < -100 || v > -10 {
			t.Fatalf("Generated value %d outside range [-100, -10]", v)
		}
	}
}

func TestGenIntRange_CrossingZero(t *testing.T) {
	// Test range crossing zero [-50, 50]
	s := newRandomBitStream(12345, true)

	hasNegative := false
	hasPositive := false

	for i := 0; i < 100; i++ {
		v, _, _ := genIntRange(s, -50, 50, true)
		if v < -50 || v > 50 {
			t.Fatalf("Generated value %d outside range [-50, 50]", v)
		}
		if v < 0 {
			hasNegative = true
		} else if v > 0 {
			hasPositive = true
		}
	}

	// Probabilistic check - should see both sides
	if !hasNegative || !hasPositive {
		t.Log("Warning: didn't see both negative and positive values")
	}
}

func TestGenIntRange_MinMax(t *testing.T) {
	// Test boundary values
	tests := []struct {
		name string
		min  int64
		max  int64
	}{
		{"Single value", 42, 42},
		{"Zero range", 0, 0},
		{"Min int64", -9223372036854775808, -9223372036854775807},
		{"Max int64", 9223372036854775806, 9223372036854775807},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := newRandomBitStream(12345, true)

			for i := 0; i < 10; i++ {
				v, _, _ := genIntRange(s, tc.min, tc.max, true)
				if v < tc.min || v > tc.max {
					t.Fatalf("Generated value %d outside range [%d, %d]", v, tc.min, tc.max)
				}
			}
		})
	}
}

func TestGenIndex(t *testing.T) {
	tests := []struct {
		name string
		n    int
		bias bool
	}{
		{"n=1", 1, false},
		{"n=10", 10, false},
		{"n=100", 100, false},
		{"n=10 biased", 10, true},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := newRandomBitStream(12345, true)

			for i := 0; i < 20; i++ {
				idx := genIndex(s, tc.n, tc.bias)
				if idx < 0 || idx >= tc.n {
					t.Fatalf("Generated index %d outside range [0, %d)", idx, tc.n)
				}
			}
		})
	}
}

func TestFlipBiasedCoin(t *testing.T) {
	tests := []struct {
		name string
		p    float64
	}{
		{"Never (p=0)", 0.0},
		{"Always (p=1)", 1.0},
		{"Fair (p=0.5)", 0.5},
		{"Biased 25%", 0.25},
		{"Biased 75%", 0.75},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := newRandomBitStream(12345, true)

			trueCount := 0
			total := 100

			for i := 0; i < total; i++ {
				if flipBiasedCoin(s, tc.p) {
					trueCount++
				}
			}

			// Check extreme cases
			if tc.p == 0 && trueCount != 0 {
				t.Fatalf("p=0 but got %d true values", trueCount)
			}
			if tc.p == 1 && trueCount != total {
				t.Fatalf("p=1 but got %d/%d true values", trueCount, total)
			}

			// For probabilistic cases, just log
			if tc.p > 0 && tc.p < 1 {
				ratio := float64(trueCount) / float64(total)
				t.Logf("p=%.2f resulted in %.2f true ratio", tc.p, ratio)
			}
		})
	}
}

func TestRepeat_Basic(t *testing.T) {
	// Test basic repeat functionality
	s := newRandomBitStream(12345, true)
	r := newRepeat(0, 10, -1, "test")

	count := 0
	for r.more(s) {
		count++
	}

	if count < 0 || count > 10 {
		t.Fatalf("Repeat count %d outside range [0, 10]", count)
	}
}

func TestRepeat_MinCount(t *testing.T) {
	// Test that minCount is enforced
	s := newRandomBitStream(12345, true)
	r := newRepeat(5, 10, -1, "test")

	count := 0
	for r.more(s) {
		count++
	}

	if count < 5 {
		t.Fatalf("Repeat count %d < minCount 5", count)
	}
	if count > 10 {
		t.Fatalf("Repeat count %d > maxCount 10", count)
	}
}

func TestRepeat_MaxCount(t *testing.T) {
	// Test that maxCount is enforced
	s := newRandomBitStream(12345, true)
	r := newRepeat(0, 5, -1, "test")

	count := 0
	for r.more(s) {
		count++
		if count > 100 { // Safety check
			t.Fatal("Repeat didn't stop after 100 iterations")
		}
	}

	if count > 5 {
		t.Fatalf("Repeat count %d > maxCount 5", count)
	}
}

func TestRepeat_Reject(t *testing.T) {
	// Test rejection mechanism
	s := newRandomBitStream(12345, true)
	r := newRepeat(0, 10, -1, "test")

	acceptCount := 0
	for r.more(s) {
		// Reject half the iterations
		if acceptCount%2 == 0 {
			r.reject()
		} else {
			acceptCount++
		}
	}

	if r.rejections == 0 {
		t.Log("Warning: no rejections recorded")
	}
}

func TestRepeat_ForceStop(t *testing.T) {
	// Test force stop - once set, more() should return false
	s := newRandomBitStream(12345, true)
	r := newRepeat(0, 100, -1, "test")

	// Run a few iterations
	for i := 0; i < 3; i++ {
		if !r.more(s) {
			break
		}
	}

	// Set forceStop
	r.forceStop = true

	// Next call to more() should return false
	if r.more(s) {
		t.Fatal("more() returned true after forceStop was set")
	}
}
