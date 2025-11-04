package fuzzing

import (
	"testing"
)

func TestJust(t *testing.T) {
	// Test Just generator
	ft := newT(12345, false)
	gen := Just(42)

	for i := 0; i < 10; i++ {
		v := gen.value(ft)
		if v.(int) != 42 {
			t.Fatalf("Just(42) returned %v", v)
		}
	}
}

func TestSampledFrom(t *testing.T) {
	// Test SampledFrom generator
	ft := newT(12345, false)
	slice := []any{1, 2, 3, 4, 5}
	gen := SampledFrom(slice)

	seen := make(map[int]bool)
	for i := 0; i < 50; i++ {
		v := gen.value(ft)
		val := v.(int)
		seen[val] = true

		// Check value is from slice
		found := false
		for _, x := range slice {
			if x.(int) == val {
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("SampledFrom returned value %d not in slice", val)
		}
	}

	// Should have seen multiple values
	if len(seen) < 2 {
		t.Log("Warning: only saw 1-2 distinct values in 50 samples")
	}
}

func TestSampledFrom_SingleElement(t *testing.T) {
	// Test SampledFrom with single element
	ft := newT(12345, false)
	gen := SampledFrom([]any{"only"})

	for i := 0; i < 10; i++ {
		v := gen.value(ft)
		if v.(string) != "only" {
			t.Fatalf("SampledFrom single element returned %v", v)
		}
	}
}

func TestOneOf(t *testing.T) {
	// Test OneOf generator
	ft := newT(12345, false)
	gen := OneOf(Just(1), Just(2), Just(3))

	seen := make(map[int]bool)
	for i := 0; i < 50; i++ {
		v := gen.value(ft)
		val := v.(int)
		seen[val] = true

		if val < 1 || val > 3 {
			t.Fatalf("OneOf returned value %d outside expected range", val)
		}
	}

	// Should have seen multiple generators
	if len(seen) < 2 {
		t.Log("Warning: only saw 1 generator in 50 samples")
	}
}

func TestMap(t *testing.T) {
	// Test Map combinator
	ft := newT(12345, false)
	gen := Map(IntRange(0, 10), func(v any) any {
		return v.(int) * 2
	})

	for i := 0; i < 20; i++ {
		v := gen.value(ft)
		val := v.(int)
		if val < 0 || val > 20 || val%2 != 0 {
			t.Fatalf("Map(IntRange(0, 10), *2) returned invalid value %d", val)
		}
	}
}

func TestFilter(t *testing.T) {
	// Test Filter combinator
	ft := newT(12345, false)
	gen := Filter(IntRange(0, 100), func(v any) bool {
		return v.(int)%2 == 0 // Only even numbers
	})

	for i := 0; i < 20; i++ {
		v := gen.value(ft)
		val := v.(int)
		if val%2 != 0 {
			t.Fatalf("Filter(even) returned odd number %d", val)
		}
		if val < 0 || val > 100 {
			t.Fatalf("Filter returned value %d outside range", val)
		}
	}
}

func TestFilter_AllReject(t *testing.T) {
	// Test Filter when all values are rejected
	ft := newT(12345, false)
	gen := Filter(IntRange(0, 5), func(v any) bool {
		return false // Reject everything
	})

	defer func() {
		if r := recover(); r == nil {
			t.Fatal("Expected panic when filter rejects all values")
		} else if _, ok := r.(invalidData); !ok {
			t.Fatalf("Expected invalidData panic, got %T: %v", r, r)
		}
	}()

	gen.value(ft) // Should panic
}

func TestCustom(t *testing.T) {
	// Test Custom generator
	ft := newT(12345, false)

	type Point struct {
		X int
		Y int
	}

	gen := Custom(func(t *T) any {
		x := t.IntRange(0, 10)
		y := t.IntRange(0, 10)
		return Point{X: x, Y: y}
	})

	for i := 0; i < 20; i++ {
		v := gen.value(ft)
		p := v.(Point)
		if p.X < 0 || p.X > 10 || p.Y < 0 || p.Y > 10 {
			t.Fatalf("Custom returned invalid Point: %+v", p)
		}
	}
}

func TestDeferred(t *testing.T) {
	// Test Deferred generator (for recursive structures)
	ft := newT(12345, false)

	var treeGen *Generator
	treeGen = Deferred(func() *Generator {
		return OneOf(
			Just(0),                    // Leaf
			Map(treeGen, func(v any) any { // Node
				return v.(int) + 1
			}),
		)
	})

	for i := 0; i < 20; i++ {
		v := treeGen.value(ft)
		depth := v.(int)
		if depth < 0 || depth > 100 {
			t.Fatalf("Tree depth %d seems unreasonable", depth)
		}
	}
}

func TestPermutation(t *testing.T) {
	// Test Permutation generator
	ft := newT(12345, false)
	original := []any{1, 2, 3, 4, 5}
	gen := Permutation(original)

	for i := 0; i < 10; i++ {
		v := gen.value(ft)
		perm := v.([]any)

		// Check length
		if len(perm) != len(original) {
			t.Fatalf("Permutation length %d != original length %d", len(perm), len(original))
		}

		// Check all elements are present
		seen := make(map[int]bool)
		for _, x := range perm {
			seen[x.(int)] = true
		}

		for _, x := range original {
			if !seen[x.(int)] {
				t.Fatalf("Permutation missing element %d", x.(int))
			}
		}
	}
}

func TestPermutation_Empty(t *testing.T) {
	// Test Permutation with empty slice
	ft := newT(12345, false)
	gen := Permutation([]any{})

	v := gen.value(ft)
	perm := v.([]any)

	if len(perm) != 0 {
		t.Fatalf("Empty slice permutation should be empty, got length %d", len(perm))
	}
}

func TestPermutation_SingleElement(t *testing.T) {
	// Test Permutation with single element
	ft := newT(12345, false)
	gen := Permutation([]any{42})

	for i := 0; i < 10; i++ {
		v := gen.value(ft)
		perm := v.([]any)

		if len(perm) != 1 || perm[0].(int) != 42 {
			t.Fatalf("Single element permutation invalid: %v", perm)
		}
	}
}

func TestGenerator_String(t *testing.T) {
	// Test String representation of generators
	tests := []struct {
		name string
		gen  *Generator
	}{
		{"Just", Just(42)},
		{"SampledFrom", SampledFrom([]any{1, 2, 3})},
		{"OneOf", OneOf(Just(1), Just(2))},
		{"Map", Map(IntRange(0, 10), func(v any) any { return v })},
		{"Filter", Filter(IntRange(0, 10), func(v any) bool { return true })},
		{"Custom", Custom(func(t *T) any { return 0 })},
		{"Deferred", Deferred(func() *Generator { return Just(0) })},
		{"Permutation", Permutation([]any{1, 2, 3})},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := tc.gen.String()
			if s == "" {
				t.Fatalf("%s generator has empty String()", tc.name)
			}
		})
	}
}

func TestGenerator_Determinism(t *testing.T) {
	// Test that same seed produces same values
	ft1 := newT(12345, false)
	ft2 := newT(12345, false)

	gen := IntRange(0, 100)

	for i := 0; i < 20; i++ {
		v1 := gen.value(ft1)
		v2 := gen.value(ft2)

		if v1.(int) != v2.(int) {
			t.Fatalf("Same seed produced different values at iteration %d: %d != %d", i, v1, v2)
		}
	}
}

func TestGenerator_DifferentSeeds(t *testing.T) {
	// Test that different seeds produce different values
	ft1 := newT(12345, false)
	ft2 := newT(54321, false)

	gen := IntRange(0, 1000)

	v1 := gen.value(ft1)
	v2 := gen.value(ft2)

	// This is probabilistic, but very unlikely to be equal for large range
	if v1.(int) == v2.(int) {
		t.Log("Warning: different seeds produced same first value (probabilistic)")
	}
}
