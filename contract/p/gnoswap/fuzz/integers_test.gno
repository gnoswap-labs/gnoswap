package fuzz

import (
	"math"
	"testing"
)

// Test Bool generator
func TestIntegers_Bool(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	// Generate 100 values and verify they're all booleans
	trueCount := 0
	falseCount := 0
	for i := 0; i < 100; i++ {
		val := Bool().Draw(testT, "bool").(bool)
		if val {
			trueCount++
		} else {
			falseCount++
		}
	}

	// Both true and false should appear
	if trueCount == 0 {
		t.Errorf("Bool() never generated true")
	}
	if falseCount == 0 {
		t.Errorf("Bool() never generated false")
	}
}

// Test Int8Range generator
func TestIntegers_Int8Range(t *testing.T) {
	tests := []struct {
		name string
		min  int8
		max  int8
	}{
		{
			name: "positive range",
			min:  1,
			max:  10,
		},
		{
			name: "negative range",
			min:  -10,
			max:  -1,
		},
		{
			name: "mixed range",
			min:  -5,
			max:  5,
		},
		{
			name: "single value",
			min:  42,
			max:  42,
		},
		{
			name: "full range",
			min:  math.MinInt8,
			max:  math.MaxInt8,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(54321)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			// when & then - generate 100 values
			for i := 0; i < 100; i++ {
				val := Int8Range(tc.min, tc.max).Draw(testT, "val").(int8)
				if val < tc.min || val > tc.max {
					t.Fatalf("Int8Range(%d, %d) produced out-of-range value: %d", tc.min, tc.max, val)
				}
			}
		})
	}
}

// Test Int16Range generator
func TestIntegers_Int16Range(t *testing.T) {
	tests := []struct {
		name string
		min  int16
		max  int16
	}{
		{
			name: "positive range",
			min:  100,
			max:  1000,
		},
		{
			name: "boundary values",
			min:  math.MinInt16,
			max:  math.MaxInt16,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(11111)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			// when & then
			for i := 0; i < 100; i++ {
				val := Int16Range(tc.min, tc.max).Draw(testT, "val").(int16)
				if val < tc.min || val > tc.max {
					t.Fatalf("Int16Range(%d, %d) produced out-of-range value: %d", tc.min, tc.max, val)
				}
			}
		})
	}
}

// Test Int32Range generator
func TestIntegers_Int32Range(t *testing.T) {
	tests := []struct {
		name string
		min  int32
		max  int32
	}{
		{
			name: "small range",
			min:  1,
			max:  5,
		},
		{
			name: "large range",
			min:  -1000000,
			max:  1000000,
		},
		{
			name: "boundary values",
			min:  math.MinInt32,
			max:  math.MaxInt32,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(22222)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			// when & then
			for i := 0; i < 100; i++ {
				val := Int32Range(tc.min, tc.max).Draw(testT, "val").(int32)
				if val < tc.min || val > tc.max {
					t.Fatalf("Int32Range(%d, %d) produced out-of-range value: %d", tc.min, tc.max, val)
				}
			}
		})
	}
}

// Test Int64Range generator
func TestIntegers_Int64Range(t *testing.T) {
	tests := []struct {
		name string
		min  int64
		max  int64
	}{
		{
			name: "small positive range",
			min:  1,
			max:  10,
		},
		{
			name: "negative range",
			min:  -100,
			max:  -10,
		},
		{
			name: "mixed range",
			min:  -50,
			max:  50,
		},
		{
			name: "large range",
			min:  -1000000,
			max:  1000000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(33333)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			// when & then
			for i := 0; i < 100; i++ {
				val := Int64Range(tc.min, tc.max).Draw(testT, "val").(int64)
				if val < tc.min || val > tc.max {
					t.Fatalf("Int64Range(%d, %d) produced out-of-range value: %d", tc.min, tc.max, val)
				}
			}
		})
	}
}

// Test Uint8Range generator
func TestIntegers_Uint8Range(t *testing.T) {
	tests := []struct {
		name string
		min  uint8
		max  uint8
	}{
		{
			name: "small range",
			min:  0,
			max:  10,
		},
		{
			name: "mid range",
			min:  100,
			max:  200,
		},
		{
			name: "full range",
			min:  0,
			max:  math.MaxUint8,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(44444)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			// when & then
			for i := 0; i < 100; i++ {
				val := Uint8Range(tc.min, tc.max).Draw(testT, "val").(uint8)
				if val < tc.min || val > tc.max {
					t.Fatalf("Uint8Range(%d, %d) produced out-of-range value: %d", tc.min, tc.max, val)
				}
			}
		})
	}
}

// Test Uint16Range generator
func TestIntegers_Uint16Range(t *testing.T) {
	seed := uint64(55555)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := uint16(1000)
	max := uint16(2000)

	for i := 0; i < 100; i++ {
		val := Uint16Range(min, max).Draw(testT, "val").(uint16)
		if val < min || val > max {
			t.Fatalf("Uint16Range(%d, %d) produced out-of-range value: %d", min, max, val)
		}
	}
}

// Test Uint32Range generator
func TestIntegers_Uint32Range(t *testing.T) {
	seed := uint64(66666)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := uint32(1)
	max := uint32(1000000)

	for i := 0; i < 100; i++ {
		val := Uint32Range(min, max).Draw(testT, "val").(uint32)
		if val < min || val > max {
			t.Fatalf("Uint32Range(%d, %d) produced out-of-range value: %d", min, max, val)
		}
	}
}

// Test Uint64Range generator
func TestIntegers_Uint64Range(t *testing.T) {
	tests := []struct {
		name string
		min  uint64
		max  uint64
	}{
		{
			name: "small range",
			min:  0,
			max:  100,
		},
		{
			name: "large range",
			min:  0,
			max:  math.MaxUint32,
		},
		{
			name: "high range",
			min:  math.MaxUint32,
			max:  math.MaxUint32 + 1000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(77777)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			// when & then
			for i := 0; i < 100; i++ {
				val := Uint64Range(tc.min, tc.max).Draw(testT, "val").(uint64)
				if val < tc.min || val > tc.max {
					t.Fatalf("Uint64Range(%d, %d) produced out-of-range value: %d", tc.min, tc.max, val)
				}
			}
		})
	}
}

// Test Byte generator
func TestIntegers_Byte(t *testing.T) {
	seed := uint64(88888)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 100; i++ {
		val := Byte().Draw(testT, "val").(uint8)
		if val > math.MaxUint8 {
			t.Fatalf("Byte() produced out-of-range value: %d", val)
		}
	}
}

// Test ByteRange generator
func TestIntegers_ByteRange(t *testing.T) {
	seed := uint64(99999)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := byte('A')
	max := byte('Z')

	for i := 0; i < 100; i++ {
		val := ByteRange(min, max).Draw(testT, "val").(uint8)
		if val < min || val > max {
			t.Fatalf("ByteRange(%d, %d) produced out-of-range value: %d", min, max, val)
		}
	}
}

// Test Min/Max variants
func TestIntegers_Int64Min(t *testing.T) {
	seed := uint64(11111)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := int64(100)

	for i := 0; i < 100; i++ {
		val := Int64Min(min).Draw(testT, "val").(int64)
		if val < min {
			t.Fatalf("Int64Min(%d) produced value below minimum: %d", min, val)
		}
	}
}

func TestIntegers_Int64Max(t *testing.T) {
	seed := uint64(22222)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	max := int64(1000)

	for i := 0; i < 100; i++ {
		val := Int64Max(max).Draw(testT, "val").(int64)
		if val > max {
			t.Fatalf("Int64Max(%d) produced value above maximum: %d", max, val)
		}
	}
}

func TestIntegers_Uint64Min(t *testing.T) {
	seed := uint64(33333)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := uint64(1000)

	for i := 0; i < 100; i++ {
		val := Uint64Min(min).Draw(testT, "val").(uint64)
		if val < min {
			t.Fatalf("Uint64Min(%d) produced value below minimum: %d", min, val)
		}
	}
}

func TestIntegers_Uint64Max(t *testing.T) {
	seed := uint64(44444)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	max := uint64(10000)

	for i := 0; i < 100; i++ {
		val := Uint64Max(max).Draw(testT, "val").(uint64)
		if val > max {
			t.Fatalf("Uint64Max(%d) produced value above maximum: %d", max, val)
		}
	}
}

// Test Int8 generator
func TestIntegers_Int8(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 100; i++ {
		val := Int8().Draw(testT, "val").(int8)
		if val < math.MinInt8 || val > math.MaxInt8 {
			t.Fatalf("Int8() produced out-of-range value: %d", val)
		}
	}
}

// Test Int8Min generator
func TestIntegers_Int8Min(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := int8(-50)

	for i := 0; i < 100; i++ {
		val := Int8Min(min).Draw(testT, "val").(int8)
		if val < min {
			t.Fatalf("Int8Min(%d) produced value below minimum: %d", min, val)
		}
	}
}

// Test Int8Max generator
func TestIntegers_Int8Max(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	max := int8(50)

	for i := 0; i < 100; i++ {
		val := Int8Max(max).Draw(testT, "val").(int8)
		if val > max {
			t.Fatalf("Int8Max(%d) produced value above maximum: %d", max, val)
		}
	}
}

// Test Int16 generator
func TestIntegers_Int16(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 100; i++ {
		val := Int16().Draw(testT, "val").(int16)
		if val < math.MinInt16 || val > math.MaxInt16 {
			t.Fatalf("Int16() produced out-of-range value: %d", val)
		}
	}
}

// Test Int16Min generator
func TestIntegers_Int16Min(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := int16(-1000)

	for i := 0; i < 100; i++ {
		val := Int16Min(min).Draw(testT, "val").(int16)
		if val < min {
			t.Fatalf("Int16Min(%d) produced value below minimum: %d", min, val)
		}
	}
}

// Test Int16Max generator
func TestIntegers_Int16Max(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	max := int16(1000)

	for i := 0; i < 100; i++ {
		val := Int16Max(max).Draw(testT, "val").(int16)
		if val > max {
			t.Fatalf("Int16Max(%d) produced value above maximum: %d", max, val)
		}
	}
}

// Test Int32 generator
func TestIntegers_Int32(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 100; i++ {
		val := Int32().Draw(testT, "val").(int32)
		if val < math.MinInt32 || val > math.MaxInt32 {
			t.Fatalf("Int32() produced out-of-range value: %d", val)
		}
	}
}

// Test Int32Min generator
func TestIntegers_Int32Min(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := int32(-100000)

	for i := 0; i < 100; i++ {
		val := Int32Min(min).Draw(testT, "val").(int32)
		if val < min {
			t.Fatalf("Int32Min(%d) produced value below minimum: %d", min, val)
		}
	}
}

// Test Int32Max generator
func TestIntegers_Int32Max(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	max := int32(100000)

	for i := 0; i < 100; i++ {
		val := Int32Max(max).Draw(testT, "val").(int32)
		if val > max {
			t.Fatalf("Int32Max(%d) produced value above maximum: %d", max, val)
		}
	}
}

// Test Int generator
func TestIntegers_Int(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 100; i++ {
		_ = Int().Draw(testT, "val").(int)
		// Just verify it doesn't panic
	}
}

// Test IntMin generator
func TestIntegers_IntMin(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := -1000000

	for i := 0; i < 100; i++ {
		val := IntMin(min).Draw(testT, "val").(int)
		if val < min {
			t.Fatalf("IntMin(%d) produced value below minimum: %d", min, val)
		}
	}
}

// Test IntMax generator
func TestIntegers_IntMax(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	max := 1000000

	for i := 0; i < 100; i++ {
		val := IntMax(max).Draw(testT, "val").(int)
		if val > max {
			t.Fatalf("IntMax(%d) produced value above maximum: %d", max, val)
		}
	}
}

// Test IntRange generator
func TestIntegers_IntRange(t *testing.T) {
	tests := []struct {
		name string
		min  int
		max  int
	}{
		{
			name: "positive range",
			min:  1,
			max:  100,
		},
		{
			name: "negative range",
			min:  -100,
			max:  -1,
		},
		{
			name: "crossing zero",
			min:  -50,
			max:  50,
		},
		{
			name: "single value",
			min:  42,
			max:  42,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			seed := uint64(12345)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			for i := 0; i < 100; i++ {
				val := IntRange(tc.min, tc.max).Draw(testT, "val").(int)
				if val < tc.min || val > tc.max {
					t.Fatalf("IntRange(%d, %d) produced out-of-range value: %d", tc.min, tc.max, val)
				}
			}
		})
	}
}

// Test Uint16 generator
func TestIntegers_Uint16(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 100; i++ {
		val := Uint16().Draw(testT, "val").(uint16)
		if val > math.MaxUint16 {
			t.Fatalf("Uint16() produced out-of-range value: %d", val)
		}
	}
}

// Test Uint16Min generator
func TestIntegers_Uint16Min(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := uint16(1000)

	for i := 0; i < 100; i++ {
		val := Uint16Min(min).Draw(testT, "val").(uint16)
		if val < min {
			t.Fatalf("Uint16Min(%d) produced value below minimum: %d", min, val)
		}
	}
}

// Test Uint16Max generator
func TestIntegers_Uint16Max(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	max := uint16(10000)

	for i := 0; i < 100; i++ {
		val := Uint16Max(max).Draw(testT, "val").(uint16)
		if val > max {
			t.Fatalf("Uint16Max(%d) produced value above maximum: %d", max, val)
		}
	}
}

// Test Uint32 generator
func TestIntegers_Uint32(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 100; i++ {
		val := Uint32().Draw(testT, "val").(uint32)
		if val > math.MaxUint32 {
			t.Fatalf("Uint32() produced out-of-range value: %d", val)
		}
	}
}

// Test Uint32Min generator
func TestIntegers_Uint32Min(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := uint32(100000)

	for i := 0; i < 100; i++ {
		val := Uint32Min(min).Draw(testT, "val").(uint32)
		if val < min {
			t.Fatalf("Uint32Min(%d) produced value below minimum: %d", min, val)
		}
	}
}

// Test Uint32Max generator
func TestIntegers_Uint32Max(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	max := uint32(1000000)

	for i := 0; i < 100; i++ {
		val := Uint32Max(max).Draw(testT, "val").(uint32)
		if val > max {
			t.Fatalf("Uint32Max(%d) produced value above maximum: %d", max, val)
		}
	}
}

// Test Uint32Range generator
// Test Uint generator
func TestIntegers_Uint(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 100; i++ {
		_ = Uint().Draw(testT, "val").(uint)
		// Just verify it doesn't panic
	}
}

// Test UintMin generator
func TestIntegers_UintMin(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := uint(1000000)

	for i := 0; i < 100; i++ {
		val := UintMin(min).Draw(testT, "val").(uint)
		if val < min {
			t.Fatalf("UintMin(%d) produced value below minimum: %d", min, val)
		}
	}
}

// Test UintMax generator
func TestIntegers_UintMax(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	max := uint(10000000)

	for i := 0; i < 100; i++ {
		val := UintMax(max).Draw(testT, "val").(uint)
		if val > max {
			t.Fatalf("UintMax(%d) produced value above maximum: %d", max, val)
		}
	}
}

// Test UintRange generator
func TestIntegers_UintRange(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	min := uint(1000)
	max := uint(100000)

	for i := 0; i < 100; i++ {
		val := UintRange(min, max).Draw(testT, "val").(uint)
		if val < min || val > max {
			t.Fatalf("UintRange(%d, %d) produced out-of-range value: %d", min, max, val)
		}
	}
}
