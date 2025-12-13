package int256

import (
	"math"
	"testing"

	"gno.land/p/nt/uassert"
)

func TestNewInt(t *testing.T) {
	tests := []struct {
		name string
		v    int64
	}{
		{
			name: "positive",
			v:    int64(math.MaxInt64),
		},
		{
			name: "negative",
			v:    int64(math.MinInt64),
		},
		{
			name: "zero",
			v:    int64(0),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			z := NewInt(tt.v)
			uassert.True(t, z.IsInt64())
			uassert.Equal(t, tt.v, z.Int64())
		})
	}
}

func TestIsMinI256(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		expected bool
	}{
		{
			name:     "exact min",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: true,
		},
		{
			name:     "min plus one",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: false,
		},
		{
			name:     "negative but not min",
			x:        "-1",
			expected: false,
		},
		{
			name:     "zero",
			x:        "0",
			expected: false,
		},
		{
			name:     "max int",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			uassert.Equal(t, tt.expected, x.IsMinI256())
		})
	}
}

func TestGetSetInt64(t *testing.T) {
	tests := []struct {
		name string
		v    int64
	}{
		{
			name: "positive",
			v:    int64(math.MaxInt64),
		},
		{
			name: "negative",
			v:    int64(math.MinInt64),
		},
		{
			name: "zero",
			v:    int64(0),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			z := new(Int).SetInt64(tt.v)
			uassert.Equal(t, tt.v, z.Int64())
		})
	}
}

func TestIsInt64(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		expected bool
	}{
		{
			name:     "max int64",
			x:        "9223372036854775807",
			expected: true,
		},
		{
			name:     "min int64",
			x:        "-9223372036854775808",
			expected: true,
		},
		{
			name:     "max int64 + 1",
			x:        "9223372036854775808",
			expected: false,
		},
		{
			name:     "min int64 - 1",
			x:        "-9223372036854775809",
			expected: false,
		},
		{
			name:     "zero",
			x:        "0",
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			uassert.Equal(t, tt.expected, x.IsInt64())
		})
	}
}

func TestIsUint64(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		expected bool
	}{
		{
			name:     "max uint64",
			x:        "18446744073709551615",
			expected: true,
		},
		{
			name:     "max uint64 + 1",
			x:        "18446744073709551616",
			expected: false,
		},
		{
			name:     "zero",
			x:        "0",
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			uassert.Equal(t, tt.expected, x.IsUint64())
		})
	}
}

func TestRem(t *testing.T) {
	tests := []struct {
		name        string
		x           string
		y           string
		expected    string
		shouldPanic bool
	}{
		{
			name:     "positive % negative",
			x:        "3",
			y:        "-2",
			expected: "1",
		},
		{
			name:     "positive % positive",
			x:        "13",
			y:        "3",
			expected: "1",
		},
		{
			name:     "negative % positive",
			x:        "-13",
			y:        "3",
			expected: "-1",
		},
		{
			name:     "positive % negative (truncated)",
			x:        "13",
			y:        "-3",
			expected: "1",
		},
		{
			name:     "negative % negative",
			x:        "-13",
			y:        "-3",
			expected: "-1",
		},
		{
			name:     "min negative % positive",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "35719473219571942749314729421",
			expected: "-34167184328512991083512640217",
		},
		{
			name:     "max positive % negative",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "-35719473219571942749314729421",
			expected: "34167184328512991083512640216",
		},
		{
			name:     "large negative % large negative",
			x:        "-43179374921751324719573491471294",
			y:        "-43127519734921524",
			expected: "-22155214380278890",
		},
		{
			name:     "zero % negative",
			x:        "0",
			y:        "-2",
			expected: "0",
		},
		{
			name:     "large positive % smaller positive",
			x:        "4372195701247205721942146816424",
			y:        "1974924792517421647328142",
			expected: "549633341738318150337156",
		},
		{
			name:     "same values",
			x:        "1974924792517421647328142",
			y:        "1974924792517421647328142",
			expected: "0",
		},
		{
			name:     "max positive % small positive",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "2",
			expected: "1",
		},
		{
			name:        "remainder by zero",
			x:           "1",
			y:           "0",
			expected:    "",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Error("Rem should panic on division by zero")
					}
				}()
			}

			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z := new(Int).Rem(x, y)
			if !tt.shouldPanic {
				uassert.Equal(t, tt.expected, z.ToString())
			}
		})
	}
}

func TestIsPositive(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		expected bool
	}{
		{
			name:     "positive number",
			x:        "100",
			expected: true,
		},
		{
			name:     "smallest positive",
			x:        "1",
			expected: true,
		},
		{
			name:     "max positive",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: true,
		},
		{
			name:     "negative number",
			x:        "-100",
			expected: false,
		},
		{
			name:     "negative one",
			x:        "-1",
			expected: false,
		},
		{
			name:     "zero",
			x:        "0",
			expected: false,
		},
		{
			name:     "min int256",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			uassert.Equal(t, tt.expected, x.IsPositive())
		})
	}
}

func TestLte(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		y        string
		expected bool
	}{
		{
			name:     "min negative <= max positive",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: true,
		},
		{
			name:     "equal values",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: true,
		},
		{
			name:     "max positive > min negative",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			uassert.Equal(t, tt.expected, x.Lte(y))
		})
	}
}

func TestGte(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		y        string
		expected bool
	}{
		{
			name:     "min negative < max positive",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: false,
		},
		{
			name:     "equal values",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: true,
		},
		{
			name:     "max positive >= min negative",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			uassert.Equal(t, tt.expected, x.Gte(y))
		})
	}
}

func TestXor(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		y        string
		expected string
	}{
		{
			name:     "min negative ^ negative",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "-100",
			expected: "57896044618658097711785492504343953926634992332820282019728792003956564819868",
		},
		{
			name:     "max positive ^ positive",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "41457129491534261876432718654783265437285638275",
			expected: "57896044618658097711785492504302496797143458070943849301074008738519279181692",
		},
		{
			name:     "min negative ^ max positive",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: "-1",
		},
		{
			name:     "min negative ^ zero",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "0",
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z := new(Int).Xor(x, y)
			uassert.Equal(t, tt.expected, z.ToString())
		})
	}
}

func TestNot(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		expected string
	}{
		{
			name:     "positive number",
			x:        "100",
			expected: "-101",
		},
		{
			name:     "negative number",
			x:        "-100",
			expected: "99",
		},
		{
			name:     "zero",
			x:        "0",
			expected: "-1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			z := new(Int).Not(x)
			uassert.Equal(t, tt.expected, z.ToString())
		})
	}
}
