package fuzz

import (
	"math"
	"testing"
)

func TestFloats_Float32(t *testing.T) {
	// given
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)
	gen := Float32()

	// when
	val := gen.Draw(testT, "float32").(float32)

	// then
	if math.IsNaN(float64(val)) {
		t.Fatalf("Float32() produced NaN")
	}
	if val < -math.MaxFloat32 || val > math.MaxFloat32 {
		t.Fatalf("Float32() produced out-of-range value: %v", val)
	}
}

func TestFloats_Float32Min(t *testing.T) {
	tests := []struct {
		name string
		min  float32
	}{
		{
			name: "positive min",
			min:  100.5,
		},
		{
			name: "zero min",
			min:  0,
		},
		{
			name: "negative min",
			min:  -100.5,
		},
		{
			name: "small positive min",
			min:  math.SmallestNonzeroFloat32,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(12345)
			s := newRandomBitStream(seed, false)
			testT := newT(s)
			gen := Float32Min(tc.min)

			// when & then
			for i := 0; i < 100; i++ {
				val := gen.Draw(testT, "float32min").(float32)

				if math.IsNaN(float64(val)) {
					t.Fatalf("Float32Min(%v) produced NaN", tc.min)
				}
				if val < tc.min {
					t.Fatalf("Float32Min(%v) produced value below min: %v", tc.min, val)
				}
			}
		})
	}
}

func TestFloats_Float32Max(t *testing.T) {
	tests := []struct {
		name string
		max  float32
	}{
		{
			name: "positive max",
			max:  100.5,
		},
		{
			name: "zero max",
			max:  0,
		},
		{
			name: "negative max",
			max:  -100.5,
		},
		{
			name: "small positive max",
			max:  math.SmallestNonzeroFloat32,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(12345)
			s := newRandomBitStream(seed, false)
			testT := newT(s)
			gen := Float32Max(tc.max)

			// when & then
			for i := 0; i < 100; i++ {
				val := gen.Draw(testT, "float32max").(float32)

				if math.IsNaN(float64(val)) {
					t.Fatalf("Float32Max(%v) produced NaN", tc.max)
				}
				if val > tc.max {
					t.Fatalf("Float32Max(%v) produced value above max: %v", tc.max, val)
				}
			}
		})
	}
}

func TestFloats_Float32Range(t *testing.T) {
	tests := []struct {
		name string
		min  float32
		max  float32
	}{
		{
			name: "positive range",
			min:  1.0,
			max:  100.0,
		},
		{
			name: "negative range",
			min:  -100.0,
			max:  -1.0,
		},
		{
			name: "crossing zero",
			min:  -50.0,
			max:  50.0,
		},
		{
			name: "single value",
			min:  42.0,
			max:  42.0,
		},
		{
			name: "small range",
			min:  0.0,
			max:  math.SmallestNonzeroFloat32,
		},
		{
			name: "full range",
			min:  -math.MaxFloat32,
			max:  math.MaxFloat32,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(12345)
			s := newRandomBitStream(seed, false)
			testT := newT(s)
			gen := Float32Range(tc.min, tc.max)

			// when & then
			for i := 0; i < 100; i++ {
				val := gen.Draw(testT, "float32range").(float32)

				if math.IsNaN(float64(val)) {
					t.Fatalf("Float32Range(%v, %v) produced NaN", tc.min, tc.max)
				}
				if val < tc.min || val > tc.max {
					t.Fatalf("Float32Range(%v, %v) produced out-of-range value: %v", tc.min, tc.max, val)
				}
			}
		})
	}
}

func TestFloats_Float64(t *testing.T) {
	// given
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)
	gen := Float64()

	// when
	val := gen.Draw(testT, "float64").(float64)

	// then
	if math.IsNaN(val) {
		t.Fatalf("Float64() produced NaN")
	}
	if val < -math.MaxFloat64 || val > math.MaxFloat64 {
		t.Fatalf("Float64() produced out-of-range value: %v", val)
	}
}

func TestFloats_Float64Min(t *testing.T) {
	tests := []struct {
		name string
		min  float64
	}{
		{
			name: "positive min",
			min:  100.5,
		},
		{
			name: "zero min",
			min:  0,
		},
		{
			name: "negative min",
			min:  -100.5,
		},
		{
			name: "small positive min",
			min:  math.SmallestNonzeroFloat64,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(12345)
			s := newRandomBitStream(seed, false)
			testT := newT(s)
			gen := Float64Min(tc.min)

			// when & then
			for i := 0; i < 100; i++ {
				val := gen.Draw(testT, "float64min").(float64)

				if math.IsNaN(val) {
					t.Fatalf("Float64Min(%v) produced NaN", tc.min)
				}
				if val < tc.min {
					t.Fatalf("Float64Min(%v) produced value below min: %v", tc.min, val)
				}
			}
		})
	}
}

func TestFloats_Float64Max(t *testing.T) {
	tests := []struct {
		name string
		max  float64
	}{
		{
			name: "positive max",
			max:  100.5,
		},
		{
			name: "zero max",
			max:  0,
		},
		{
			name: "negative max",
			max:  -100.5,
		},
		{
			name: "small positive max",
			max:  math.SmallestNonzeroFloat64,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(12345)
			s := newRandomBitStream(seed, false)
			testT := newT(s)
			gen := Float64Max(tc.max)

			// when & then
			for i := 0; i < 100; i++ {
				val := gen.Draw(testT, "float64max").(float64)

				if math.IsNaN(val) {
					t.Fatalf("Float64Max(%v) produced NaN", tc.max)
				}
				if val > tc.max {
					t.Fatalf("Float64Max(%v) produced value above max: %v", tc.max, val)
				}
			}
		})
	}
}

func TestFloats_Float64Range(t *testing.T) {
	tests := []struct {
		name string
		min  float64
		max  float64
	}{
		{
			name: "positive range",
			min:  1.0,
			max:  100.0,
		},
		{
			name: "negative range",
			min:  -100.0,
			max:  -1.0,
		},
		{
			name: "crossing zero",
			min:  -50.0,
			max:  50.0,
		},
		{
			name: "single value",
			min:  42.0,
			max:  42.0,
		},
		{
			name: "small range",
			min:  0.0,
			max:  math.SmallestNonzeroFloat64,
		},
		{
			name: "full range",
			min:  -math.MaxFloat64,
			max:  math.MaxFloat64,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(12345)
			s := newRandomBitStream(seed, false)
			testT := newT(s)
			gen := Float64Range(tc.min, tc.max)

			// when & then
			for i := 0; i < 100; i++ {
				val := gen.Draw(testT, "float64range").(float64)

				if math.IsNaN(val) {
					t.Fatalf("Float64Range(%v, %v) produced NaN", tc.min, tc.max)
				}
				if val < tc.min || val > tc.max {
					t.Fatalf("Float64Range(%v, %v) produced out-of-range value: %v", tc.min, tc.max, val)
				}
			}
		})
	}
}
