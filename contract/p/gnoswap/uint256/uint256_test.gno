package uint256

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestFromDecimal(t *testing.T) {
	t.Run("valid_inputs", func(t *testing.T) {
		tests := []struct {
			name     string
			input    string
			expected string
		}{
			{"zero", "0", "0"},
			{"one", "1", "1"},
			{"max_uint64", "18446744073709551615", "18446744073709551615"},
			{"max_uint128", "340282366920938463463374607431768211455", "340282366920938463463374607431768211455"},
			{"max_uint256", MAX_UINT256, MAX_UINT256},
			{"leading_zeros", "00000000000000000000000001234567890", "1234567890"},
			{"leading_zeros_over_max_len", "00000000000000000000000000000000000000000000000000000000000000000000000000000000", "0"},
			{"plus_sign", "+12345", "12345"},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				result := MustFromDecimal(tt.input)
				uassert.Equal(t, tt.expected, result.ToString())
			})
		}
	})

	t.Run("must_from_decimal_panics", func(t *testing.T) {
		tests := []struct {
			name     string
			input    string
			panicMsg string
		}{
			{"max_uint256_plus_one", "115792089237316195423570985008687907853269984665640564039457584007913129639936", "decimal number > 256 bits"},
			{"empty_string", "", "EOF"},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					MustFromDecimal(tt.input)
				})
			})
		}

		// Tests that panic without specific message check
		panicInputs := []struct {
			name  string
			input string
		}{
			{"multiple_plus_signs", "++12345"},
			{"negative_number", "-12345"},
			{"sign_in_middle", "12-+345"},
			{"suffixed_signs", "12345+"},
			{"invalid_characters", "123abc456"},
			{"spaces_in_number", "123 456"},
			{"decimal_point", "123.456"},
		}

		for _, tt := range panicInputs {
			t.Run(tt.name, func(t *testing.T) {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic but got none")
					}
				}()
				MustFromDecimal(tt.input)
			})
		}
	})

	t.Run("from_decimal_errors", func(t *testing.T) {
		tests := []struct {
			name    string
			input   string
			wantErr error
		}{
			{"overflow", "115792089237316195423570985008687907853269984665640564039457584007913129639936", ErrBig256Range},
			{"invalid_characters", "123abc456", nil}, // expects any error
			{"empty_string", "", nil},                // expects any error
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				_, err := FromDecimal(tt.input)
				if tt.wantErr != nil {
					if err != tt.wantErr {
						t.Errorf("FromDecimal(%q) error = %v, want %v", tt.input, err, tt.wantErr)
					}
					return
				}
				if err == nil {
					t.Errorf("FromDecimal(%q) expected error, got nil", tt.input)
				}
			})
		}
	})
}

func TestByteOperation(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		n        uint64
		expected string
	}{
		{
			name:     "byte_0_of_max",
			x:        MAX_UINT256,
			n:        0,
			expected: "255",
		},
		{
			name:     "byte_31_of_max",
			x:        MAX_UINT256,
			n:        31,
			expected: "255",
		},
		{
			name:     "byte_32_out_of_range",
			x:        MAX_UINT256,
			n:        32,
			expected: "0",
		},
		{
			name:     "byte_0_of_256",
			x:        "256",
			n:        30,
			expected: "1",
		},
		{
			name:     "byte_31_of_single_byte",
			x:        "255",
			n:        31,
			expected: "255",
		},
		{
			name:     "byte_at_boundary",
			x:        "18446744073709551616", // 2^64
			n:        23,
			expected: "1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			n := NewUint(tt.n)
			result := x.Byte(n)

			uassert.Equal(t, tt.expected, result.ToString())
		})
	}
}

func TestBitLenAndByteLen(t *testing.T) {
	tests := []struct {
		name         string
		input        string
		expectedBit  int
		expectedByte int
	}{
		{
			name:         "zero",
			input:        "0",
			expectedBit:  0,
			expectedByte: 0,
		},
		{
			name:         "one",
			input:        "1",
			expectedBit:  1,
			expectedByte: 1,
		},
		{
			name:         "byte_boundary",
			input:        "255", // 2^8 - 1
			expectedBit:  8,
			expectedByte: 1,
		},
		{
			name:         "word_boundary",
			input:        "18446744073709551615", // 2^64 - 1
			expectedBit:  64,
			expectedByte: 8,
		},
		{
			name:         "max_uint256",
			input:        MAX_UINT256,
			expectedBit:  256,
			expectedByte: 32,
		},
		{
			name:         "half_max",
			input:        "57896044618658097711785492504343953926634992332820282019728792003956564819968", // 2^255
			expectedBit:  256,
			expectedByte: 32,
		},
		{
			name:         "uneven_bits",
			input:        "123456789",
			expectedBit:  27,
			expectedByte: 4,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.input)
			bitLen := x.BitLen()
			byteLen := x.ByteLen()

			uassert.Equal(t, tt.expectedBit, bitLen)
			uassert.Equal(t, tt.expectedByte, byteLen)
		})
	}
}

func TestInPlaceSafety(t *testing.T) {
	// Testing that operations don't mutate their inputs
	t.Run("original_values_preserved", func(t *testing.T) {
		a := MustFromDecimal("1234567890")
		b := MustFromDecimal("9876543210")

		original_a := a.Clone()
		original_b := b.Clone()

		_ = new(Uint).Add(a, b)

		uassert.True(t, a.Eq(original_a))
		uassert.True(t, b.Eq(original_b))
	})

	// Testing that chained operations work correctly
	t.Run("chained_operations", func(t *testing.T) {
		a := MustFromDecimal("1000000")
		b := MustFromDecimal("2000000")
		c := MustFromDecimal("3000000")

		// (a + b) * c
		temp := new(Uint).Add(a, b)
		result := new(Uint).Mul(temp, c)

		expected := MustFromDecimal("9000000000000")
		uassert.True(t, result.Eq(expected))
	})
}

func TestOperationConsistency(t *testing.T) {
	// Testing mathematical properties
	t.Run("addition_associativity", func(t *testing.T) {
		a := NewUint(12345)
		b := NewUint(67890)
		c := NewUint(11111)

		// (a + b) + c
		path1 := new(Uint).Add(a, b)
		path1 = new(Uint).Add(path1, c)

		// a + (b + c)
		path2 := new(Uint).Add(b, c)
		path2 = new(Uint).Add(a, path2)

		uassert.True(t, path1.Eq(path2))
	})

	t.Run("distributive_property", func(t *testing.T) {
		a := NewUint(12345)
		b := NewUint(67)
		c := NewUint(89)

		// a * (b + c)
		sum := new(Uint).Add(b, c)
		dist1 := new(Uint).Mul(a, sum)

		// (a * b) + (a * c)
		prod1 := new(Uint).Mul(a, b)
		prod2 := new(Uint).Mul(a, c)
		dist2 := new(Uint).Add(prod1, prod2)

		uassert.True(t, dist1.Eq(dist2))
	})

	t.Run("inverse_operations", func(t *testing.T) {
		x := MustFromDecimal("123456789012345678901234567890")

		// x + y - y = x
		y := MustFromDecimal("999999999999999999999999999999")
		result := new(Uint).Add(x, y)
		result = new(Uint).Sub(result, y)
		uassert.True(t, result.Eq(x))

		// x * y / y = x (when no remainder)
		y = NewUint(12345)
		result = new(Uint).Mul(x, y)
		result = new(Uint).Div(result, y)
		uassert.True(t, result.Eq(x))

		// x << n >> n = x (when n < bitlen(x))
		n := uint(10)
		result = new(Uint).Lsh(x, n)
		result = new(Uint).Rsh(result, n)
		uassert.True(t, result.Eq(x))
	})
}

func TestInt64Conversion(t *testing.T) {
	t.Run("Int64", func(t *testing.T) {
		tests := []struct {
			name string
			x    string
			want int64
		}{
			{"zero", "0", 0},
			{"small positive", "42", 42},
			{"max int64", "9223372036854775807", 9223372036854775807},
			{"max int64 plus one wraps", "9223372036854775808", -9223372036854775808},
			{"2^64 wraps to zero", "18446744073709551616", 0},
			{"all ones becomes -1", MAX_UINT256, -1},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				x := MustFromDecimal(tt.x)
				if got := x.Int64(); got != tt.want {
					t.Errorf("Int64(%s) = %d, want %d", tt.x, got, tt.want)
				}
			})
		}
	})

	t.Run("NewUintFromInt64", func(t *testing.T) {
		t.Run("positive", func(t *testing.T) {
			uassert.Equal(t, uint64(123), NewUintFromInt64(123)[0])
		})

		t.Run("zero", func(t *testing.T) {
			uassert.Equal(t, uint64(0), NewUintFromInt64(0)[0])
		})

		t.Run("negative panics", func(t *testing.T) {
			uassert.PanicsContains(t, "val is negative", func() {
				NewUintFromInt64(-1)
			})
		})
	})
}
