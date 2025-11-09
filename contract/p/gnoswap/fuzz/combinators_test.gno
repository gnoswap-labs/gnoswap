package fuzz

import (
	"testing"
)

// Test Just generator
func TestCombinators_Just(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	expectedValue := int64(42)

	// Just should always return the same value
	for i := 0; i < 50; i++ {
		val := Just(expectedValue).Draw(testT, "just").(int64)
		if val != expectedValue {
			t.Fatalf("Just(%d) returned different value: %d", expectedValue, val)
		}
	}
}

// Test SampledFrom generator
func TestCombinators_SampledFrom(t *testing.T) {
	seed := uint64(54321)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	options := []any{int64(1), int64(2), int64(3), int64(4), int64(5)}

	// All values should be from the options
	for i := 0; i < 100; i++ {
		val := SampledFrom(options).Draw(testT, "sample").(int64)

		found := false
		for _, opt := range options {
			if val == opt.(int64) {
				found = true
				break
			}
		}

		if !found {
			t.Fatalf("SampledFrom produced value not in options: %d", val)
		}
	}
}

// Test SampledFrom with strings
func TestCombinators_SampledFromStrings(t *testing.T) {
	seed := uint64(11111)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	options := []any{"apple", "banana", "cherry", "date"}

	for i := 0; i < 50; i++ {
		val := SampledFrom(options).Draw(testT, "fruit").(string)

		found := false
		for _, opt := range options {
			if val == opt.(string) {
				found = true
				break
			}
		}

		if !found {
			t.Fatalf("SampledFrom produced value not in options: %s", val)
		}
	}
}

// Test OneOf generator
func TestCombinators_OneOf(t *testing.T) {
	seed := uint64(22222)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	gen1 := Int64Range(1, 10)
	gen2 := Int64Range(100, 110)
	gen3 := Int64Range(1000, 1010)

	for i := 0; i < 100; i++ {
		val := OneOf(gen1, gen2, gen3).Draw(testT, "oneof").(int64)

		// Value should be in one of the three ranges
		inRange1 := val >= 1 && val <= 10
		inRange2 := val >= 100 && val <= 110
		inRange3 := val >= 1000 && val <= 1010

		if !inRange1 && !inRange2 && !inRange3 {
			t.Fatalf("OneOf produced value not in any range: %d", val)
		}
	}
}

// Test OneOf with different types
func TestCombinators_OneOfMixedTypes(t *testing.T) {
	seed := uint64(33333)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	genInt := Int64Range(1, 10)
	genBool := Bool()

	for i := 0; i < 100; i++ {
		val := OneOf(genInt, genBool).Draw(testT, "mixed")

		// Should be either int64 or bool
		_, isInt := val.(int64)
		_, isBool := val.(bool)

		if !isInt && !isBool {
			t.Fatalf("OneOf(int, bool) produced unexpected type: %T", val)
		}
	}
}

// Test Permutation generator
func TestCombinators_Permutation(t *testing.T) {
	seed := uint64(11111)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	original := []any{int64(1), int64(2), int64(3), int64(4), int64(5)}

	for i := 0; i < 30; i++ {
		val := Permutation(original).Draw(testT, "perm").([]any)

		// Should have same length
		if len(val) != len(original) {
			t.Fatalf("Permutation produced slice with different length: %d vs %d", len(val), len(original))
		}

		// Should contain all original elements
		found := make(map[int64]bool)
		for _, v := range val {
			intVal := v.(int64)
			found[intVal] = true
		}

		for _, orig := range original {
			origInt := orig.(int64)
			if !found[origInt] {
				t.Fatalf("Permutation missing element: %d", origInt)
			}
		}

		if len(found) != len(original) {
			t.Fatalf("Permutation has duplicate elements")
		}
	}
}
