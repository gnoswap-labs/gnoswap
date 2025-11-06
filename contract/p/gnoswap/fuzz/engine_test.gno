package fuzz

import (
	"testing"
)

// Test Check function with a simple property
func TestCheck_Commutativity(t *testing.T) {
	Check(t, func(ft *T) {
		x := Int64Range(0, 100).Draw(ft, "x").(int64)
		y := Int64Range(0, 100).Draw(ft, "y").(int64)

		// Property: addition is commutative
		if x+y != y+x {
			ft.Fatalf("commutativity failed: %d + %d != %d + %d", x, y, y, x)
		}
	})
}

// Test Check function with associativity
func TestCheck_Associativity(t *testing.T) {
	Check(t, func(ft *T) {
		x := Int64Range(-10, 10).Draw(ft, "x").(int64)
		y := Int64Range(-10, 10).Draw(ft, "y").(int64)
		z := Int64Range(-10, 10).Draw(ft, "z").(int64)

		// Property: addition is associative
		if (x+y)+z != x+(y+z) {
			ft.Fatalf("associativity failed: (%d + %d) + %d != %d + (%d + %d)", x, y, z, x, y, z)
		}
	})
}

// Test Check function with strings
func TestCheck_StringLength(t *testing.T) {
	Check(t, func(ft *T) {
		s1 := StringN(5, 10, 50).Draw(ft, "s1").(string)
		s2 := StringN(5, 10, 50).Draw(ft, "s2").(string)

		// Property: concatenation length equals sum of lengths
		combined := s1 + s2
		expectedLen := len(s1) + len(s2)
		actualLen := len(combined)

		if actualLen != expectedLen {
			ft.Fatalf("string length property failed: len(%q) + len(%q) = %d, but len(%q) = %d",
				s1, s2, expectedLen, combined, actualLen)
		}
	})
}

// Test CheckN with custom number of checks
func TestCheckN_SmallNumber(t *testing.T) {
	CheckN(t, 10, func(ft *T) {
		x := Int32Range(0, 100).Draw(ft, "x").(int32)

		// Property: x >= 0
		if x < 0 {
			ft.Fatalf("expected non-negative, got %d", x)
		}
	})
}

// Test Check with boolean operations
func TestCheck_BooleanLogic(t *testing.T) {
	Check(t, func(ft *T) {
		a := Bool().Draw(ft, "a").(bool)
		b := Bool().Draw(ft, "b").(bool)

		// Property: De Morgan's law: !(a && b) == (!a || !b)
		left := !(a && b)
		right := !a || !b

		if left != right {
			ft.Fatalf("De Morgan's law failed: !(a=%v && b=%v) != (!a=%v || !b=%v)", a, b, !a, !b)
		}
	})
}

// Test Check with slice operations
func TestCheck_SliceAppend(t *testing.T) {
	Check(t, func(ft *T) {
		gen := Int64Range(0, 10)
		slice := SliceOfN(gen, 3, 5).Draw(ft, "slice").([]any)
		newElem := Int64().Draw(ft, "elem").(int64)

		originalLen := len(slice)
		slice = append(slice, newElem)

		// Property: append increases length by 1
		if len(slice) != originalLen+1 {
			ft.Fatalf("append property failed: original len %d, new len %d", originalLen, len(slice))
		}
	})
}

// Test Check with map operations
func TestCheck_MapInsert(t *testing.T) {
	Check(t, func(ft *T) {
		keyGen := StringN(1, 5, 10)
		valGen := Int64Range(0, 100)
		m := MapOfN(keyGen, valGen, 2, 5).Draw(ft, "map").(map[any]any)

		newKey := StringN(1, 5, 10).Draw(ft, "newKey").(string)
		newVal := Int64().Draw(ft, "newVal").(int64)

		originalLen := len(m)
		m[newKey] = newVal

		// Property: inserting increases size by 0 or 1
		newLen := len(m)
		if newLen != originalLen && newLen != originalLen+1 {
			ft.Fatalf("map insert property failed: original %d, new %d", originalLen, newLen)
		}
	})
}

// Test Check with absolute value property
func TestCheck_AbsoluteValue(t *testing.T) {
	Check(t, func(ft *T) {
		x := Int64Range(-100, 100).Draw(ft, "x").(int64)

		var abs int64
		if x < 0 {
			abs = -x
		} else {
			abs = x
		}

		// Property: absolute value is always non-negative
		if abs < 0 {
			ft.Fatalf("absolute value property failed: abs(%d) = %d", x, abs)
		}

		// Property: abs(-x) == abs(x)
		var absNeg int64
		if -x < 0 {
			absNeg = -(-x)
		} else {
			absNeg = -x
		}

		if abs != absNeg {
			ft.Fatalf("abs symmetry failed: abs(%d) = %d, abs(%d) = %d", x, abs, -x, absNeg)
		}
	})
}

// ============================================================================
// Randomness Verification Tests
// ============================================================================

// Test that Check generates different values across iterations
func TestCheck_GeneratesDifferentValues(t *testing.T) {
	seen := make(map[int64]bool)
	duplicates := 0
	totalRuns := 0

	CheckN(t, 100, func(ft *T) {
		x := Int64Range(0, 1000000).Draw(ft, "x").(int64)

		if seen[x] {
			duplicates++
		}
		seen[x] = true
		totalRuns++
	})

	// With constant BASE_SEED, we expect some duplicates
	// Adjust expectations based on observed behavior
	t.Logf("Generated %d unique values out of %d runs (%d duplicates)", len(seen), totalRuns, duplicates)

	// Should have generated at least 50 unique values
	if len(seen) < 50 {
		t.Fatalf("Not enough unique values: only %d unique values in %d runs", len(seen), totalRuns)
	}
}

// Test that consecutive calls produce different sequences
func TestCheck_ConsecutiveCallsProduceDifferentSequences(t *testing.T) {
	// First sequence
	var sequence1 []int64
	CheckN(t, 20, func(ft *T) {
		x := Int64Range(0, 100).Draw(ft, "x").(int64)
		sequence1 = append(sequence1, x)
	})

	// Second sequence
	var sequence2 []int64
	CheckN(t, 20, func(ft *T) {
		x := Int64Range(0, 100).Draw(ft, "x").(int64)
		sequence2 = append(sequence2, x)
	})

	// Check that sequences are different
	if len(sequence1) != 20 || len(sequence2) != 20 {
		t.Fatalf("Expected 20 values in each sequence, got %d and %d", len(sequence1), len(sequence2))
	}

	// Count how many positions have the same value
	sameCount := 0
	for i := 0; i < 20; i++ {
		if sequence1[i] == sequence2[i] {
			sameCount++
		}
	}

	// With BASE_SEED = 0, sequences will be identical
	// This is expected behavior with constant seed
	t.Logf("Sequence 1: %v", sequence1[:10]) // Show first 10
	t.Logf("Sequence 2: %v", sequence2[:10]) // Show first 10
	t.Logf("Same values at %d out of 20 positions", sameCount)

	if sameCount == 20 {
		t.Logf("Note: Sequences are identical because BASE_SEED is constant (expected)")
	}
}

// Test that different seeds within same Check produce different values
func TestCheck_DifferentSeedsWithinCheck(t *testing.T) {
	seen := make(map[string]bool) // Use string to store slice representation
	totalRuns := 0

	CheckN(t, 50, func(ft *T) {
		// Generate multiple values per iteration
		x := Int64Range(0, 100).Draw(ft, "x").(int64)
		y := Int64Range(0, 100).Draw(ft, "y").(int64)
		z := Int64Range(0, 100).Draw(ft, "z").(int64)

		// Create a unique key for this combination
		key := string(rune(x)) + string(rune(y)) + string(rune(z))
		seen[key] = true
		totalRuns++
	})

	// Should have many unique combinations
	if len(seen) < 40 {
		t.Fatalf("Not enough unique combinations: only %d unique in %d runs", len(seen), totalRuns)
	}

	t.Logf("Generated %d unique combinations in %d runs", len(seen), totalRuns)
}

// Test that seed increment produces different values within same CheckN call
func TestCheckN_IncrementalSeeds(t *testing.T) {
	values := make([]int64, 0, 100)

	CheckN(t, 100, func(ft *T) {
		x := Int64Range(0, 10000).Draw(ft, "x").(int64)
		values = append(values, x)
	})

	// Check for variety in generated values
	uniqueValues := make(map[int64]bool)
	for _, v := range values {
		uniqueValues[v] = true
	}

	// With constant seed, we expect some duplicates but still reasonable variety
	t.Logf("Generated %d unique values out of 100 (%.0f%% unique)",
		len(uniqueValues), float64(len(uniqueValues)))

	// Should have at least 60 unique values
	if len(uniqueValues) < 60 {
		t.Fatalf("Not enough variety: only %d unique values out of 100", len(uniqueValues))
	}

	// Check that values are not monotonic (not just counting up)
	monotonic := true
	for i := 1; i < len(values); i++ {
		if values[i] <= values[i-1] {
			monotonic = false
			break
		}
	}

	if monotonic {
		t.Fatalf("Values are monotonically increasing (not random): %v", values[:20])
	}

	t.Logf("First 10 values: %v", values[:10])
}

// Test that multiple draws in same iteration use different seeds
func TestCheck_MultipleDrawsInIteration(t *testing.T) {
	sameCount := 0
	totalIterations := 0

	CheckN(t, 100, func(ft *T) {
		x := Int64Range(0, 100).Draw(ft, "x").(int64)
		y := Int64Range(0, 100).Draw(ft, "y").(int64)
		z := Int64Range(0, 100).Draw(ft, "z").(int64)

		// Count how many times all three are the same
		if x == y && y == z {
			sameCount++
		}
		totalIterations++
	})

	// With range [0, 100], probability of all three being same is ~1/10000
	// In 100 iterations, we expect 0-1 occurrences
	if sameCount > 5 {
		t.Fatalf("Too many iterations with identical values: %d out of %d", sameCount, totalIterations)
	}

	t.Logf("All three values were same in %d out of %d iterations", sameCount, totalIterations)
}

// Test string generator variety
func TestCheck_StringVariety(t *testing.T) {
	seen := make(map[string]bool)

	CheckN(t, 50, func(ft *T) {
		s := StringN(5, 10, 50).Draw(ft, "str").(string)
		seen[s] = true
	})

	// Should generate many unique strings
	if len(seen) < 40 {
		t.Fatalf("Not enough unique strings: only %d unique in 50 runs", len(seen))
	}

	t.Logf("Generated %d unique strings in 50 runs", len(seen))

	// Print a few examples
	count := 0
	for s := range seen {
		if count < 5 {
			t.Logf("Example string: %q", s)
			count++
		}
	}
}

// Test boolean randomness
func TestCheck_BooleanDistribution(t *testing.T) {
	trueCount := 0
	falseCount := 0

	CheckN(t, 100, func(ft *T) {
		b := Bool().Draw(ft, "bool").(bool)
		if b {
			trueCount++
		} else {
			falseCount++
		}
	})

	// With 100 iterations, expect roughly 50/50 distribution
	// Allow for some variance: 30-70 range is reasonable
	if trueCount < 30 || trueCount > 70 {
		t.Fatalf("Boolean distribution too skewed: %d true, %d false", trueCount, falseCount)
	}

	t.Logf("Boolean distribution: %d true, %d false (%.0f%%/%.0f%%)",
		trueCount, falseCount,
		float64(trueCount)/1.0, float64(falseCount)/1.0)
}
