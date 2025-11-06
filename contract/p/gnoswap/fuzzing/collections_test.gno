package fuzzing

import (
	"testing"
)

// Test SliceOf generator
func TestCollections_SliceOf(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	// Generate slices of integers
	for i := 0; i < 30; i++ {
		val := SliceOf(Int64Range(1, 100)).Draw(testT, "slice").([]any)

		// Verify all elements are in range
		for j, elem := range val {
			intVal := elem.(int64)
			if intVal < 1 || intVal > 100 {
				t.Fatalf("SliceOf(Int64Range(1, 100)) produced out-of-range element at index %d: %d", j, intVal)
			}
		}
	}
}

// Test SliceOfN with length constraints
func TestCollections_SliceOfN(t *testing.T) {
	tests := []struct {
		name   string
		minLen int
		maxLen int
	}{
		{
			name:   "empty allowed",
			minLen: 0,
			maxLen: 10,
		},
		{
			name:   "fixed length",
			minLen: 5,
			maxLen: 5,
		},
		{
			name:   "small range",
			minLen: 1,
			maxLen: 20,
		},
		{
			name:   "larger range",
			minLen: 10,
			maxLen: 30,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(54321)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			// when & then
			for i := 0; i < 30; i++ {
				val := SliceOfN(Int64Range(1, 10), tc.minLen, tc.maxLen).Draw(testT, "slice").([]any)

				if len(val) < tc.minLen || len(val) > tc.maxLen {
					t.Fatalf("SliceOfN(..., %d, %d) produced slice with length %d",
						tc.minLen, tc.maxLen, len(val))
				}

				// Verify all elements are in range
				for j, elem := range val {
					intVal := elem.(int64)
					if intVal < 1 || intVal > 10 {
						t.Fatalf("SliceOfN produced out-of-range element at index %d: %d", j, intVal)
					}
				}
			}
		})
	}
}

// Test slice of booleans
func TestCollections_SliceOfBool(t *testing.T) {
	seed := uint64(11111)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 30; i++ {
		val := SliceOfN(Bool(), 5, 15).Draw(testT, "bools").([]any)

		if len(val) < 5 || len(val) > 15 {
			t.Fatalf("SliceOfN(Bool(), 5, 15) produced slice with length %d", len(val))
		}

		// Verify all elements are booleans
		for j, elem := range val {
			_, ok := elem.(bool)
			if !ok {
				t.Fatalf("SliceOfN(Bool(), ...) produced non-bool element at index %d", j)
			}
		}
	}
}

// Test slice of strings
func TestCollections_SliceOfString(t *testing.T) {
	seed := uint64(22222)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 30; i++ {
		val := SliceOfN(StringN(1, 10, -1), 0, 10).Draw(testT, "strings").([]any)

		// Verify all elements are strings
		for j, elem := range val {
			str, ok := elem.(string)
			if !ok {
				t.Fatalf("SliceOfN(StringN(...), ...) produced non-string element at index %d", j)
			}

			runeCount := len([]rune(str))
			if runeCount < 1 || runeCount > 10 {
				t.Fatalf("String element at index %d has invalid length %d: %q", j, runeCount, str)
			}
		}
	}
}

// Test MapOf generator
func TestCollections_MapOf(t *testing.T) {
	seed := uint64(33333)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	// Generate maps with int keys and string values
	for i := 0; i < 30; i++ {
		val := MapOf(Int64Range(1, 100), StringN(1, 5, -1)).Draw(testT, "map").(map[any]any)

		// Verify all keys and values are valid
		for k, v := range val {
			keyInt := k.(int64)
			if keyInt < 1 || keyInt > 100 {
				t.Fatalf("MapOf produced out-of-range key: %d", keyInt)
			}

			valStr := v.(string)
			runeCount := len([]rune(valStr))
			if runeCount < 1 || runeCount > 5 {
				t.Fatalf("MapOf produced invalid value length %d: %q", runeCount, valStr)
			}
		}
	}
}

// Test MapOfN with length constraints
func TestCollections_MapOfN(t *testing.T) {
	tests := []struct {
		name   string
		minLen int
		maxLen int
	}{
		{
			name:   "empty allowed",
			minLen: 0,
			maxLen: 5,
		},
		{
			name:   "fixed length",
			minLen: 3,
			maxLen: 3,
		},
		{
			name:   "small range",
			minLen: 1,
			maxLen: 10,
		},
		{
			name:   "larger range",
			minLen: 5,
			maxLen: 20,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(44444)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			// when & then
			for i := 0; i < 30; i++ {
				val := MapOfN(Int64Range(1, 1000), Bool(), tc.minLen, tc.maxLen).Draw(testT, "map").(map[any]any)

				if len(val) < tc.minLen || len(val) > tc.maxLen {
					t.Fatalf("MapOfN(..., %d, %d) produced map with length %d",
						tc.minLen, tc.maxLen, len(val))
				}

				// Verify all keys and values
				for k, v := range val {
					keyInt := k.(int64)
					if keyInt < 1 || keyInt > 1000 {
						t.Fatalf("MapOfN produced out-of-range key: %d", keyInt)
					}

					_, ok := v.(bool)
					if !ok {
						t.Fatalf("MapOfN produced non-bool value")
					}
				}
			}
		})
	}
}

// Test map with string keys
func TestCollections_MapStringKeys(t *testing.T) {
	seed := uint64(55555)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 30; i++ {
		val := MapOfN(StringN(1, 5, -1), Int64Range(1, 100), 0, 10).Draw(testT, "map").(map[any]any)

		// Verify all keys are strings and values are ints
		for k, v := range val {
			str, ok := k.(string)
			if !ok {
				t.Fatalf("MapOfN(StringN(...), ...) produced non-string key")
			}

			runeCount := len([]rune(str))
			if runeCount < 1 || runeCount > 5 {
				t.Fatalf("String key has invalid length %d: %q", runeCount, str)
			}

			intVal := v.(int64)
			if intVal < 1 || intVal > 100 {
				t.Fatalf("MapOfN produced out-of-range value: %d", intVal)
			}
		}
	}
}

// Test empty slice can be generated
func TestCollections_EmptySlice(t *testing.T) {
	seed := uint64(66666)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	foundEmpty := false
	for i := 0; i < 100; i++ {
		val := SliceOfN(Int64Range(1, 10), 0, 5).Draw(testT, "slice").([]any)
		if len(val) == 0 {
			foundEmpty = true
			break
		}
	}

	if !foundEmpty {
		t.Errorf("SliceOfN(..., 0, 5) never generated empty slice in 100 attempts")
	}
}

// Test empty map can be generated
func TestCollections_EmptyMap(t *testing.T) {
	seed := uint64(77777)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	foundEmpty := false
	for i := 0; i < 100; i++ {
		val := MapOfN(Int64Range(1, 10), Bool(), 0, 5).Draw(testT, "map").(map[any]any)
		if len(val) == 0 {
			foundEmpty = true
			break
		}
	}

	if !foundEmpty {
		t.Errorf("MapOfN(..., 0, 5) never generated empty map in 100 attempts")
	}
}

// Test map key uniqueness
func TestCollections_MapKeyUniqueness(t *testing.T) {
	seed := uint64(88888)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 30; i++ {
		val := MapOfN(Int64Range(1, 10), Bool(), 5, 10).Draw(testT, "map").(map[any]any)

		// Count unique keys (should equal map length)
		keySet := make(map[int64]bool)
		for k := range val {
			keyInt := k.(int64)
			keySet[keyInt] = true
		}

		if len(keySet) != len(val) {
			t.Fatalf("MapOfN produced non-unique keys: %d unique keys but %d map entries", len(keySet), len(val))
		}
	}
}

// Test nested slices
func TestCollections_NestedSlices(t *testing.T) {
	seed := uint64(99999)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	innerSlice := SliceOfN(Int64Range(1, 10), 1, 5)

	for i := 0; i < 20; i++ {
		val := SliceOfN(innerSlice, 1, 5).Draw(testT, "nested").([]any)

		// Verify structure
		for j, elem := range val {
			innerVal, ok := elem.([]any)
			if !ok {
				t.Fatalf("Nested slice element at index %d is not a slice", j)
			}

			if len(innerVal) < 1 || len(innerVal) > 5 {
				t.Fatalf("Inner slice at index %d has invalid length: %d", j, len(innerVal))
			}

			// Verify inner elements
			for k, innerElem := range innerVal {
				intVal := innerElem.(int64)
				if intVal < 1 || intVal > 10 {
					t.Fatalf("Inner element [%d][%d] out of range: %d", j, k, intVal)
				}
			}
		}
	}
}
