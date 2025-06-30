package uint256

import (
	"fmt"
	"testing"
)

func TestMulDiv(t *testing.T) {
	tests := []struct {
		name        string
		x           string
		y           string
		denominator string
		expected    string
		shouldPanic bool
	}{
		{
			name:        "reverts_if_denominator_is_0",
			x:           "340282366920938463463374607431768211456", // Q128
			y:           "5",
			denominator: "0",
			shouldPanic: true,
		},
		{
			name:        "reverts_if_denominator_is_0_and_numerator_overflows",
			x:           "340282366920938463463374607431768211456", // Q128
			y:           "340282366920938463463374607431768211456", // Q128
			denominator: "0",
			shouldPanic: true,
		},
		{
			name:        "reverts_if_output_overflows_uint256",
			x:           "340282366920938463463374607431768211456", // Q128
			y:           "340282366920938463463374607431768211456", // Q128
			denominator: "1",
			shouldPanic: true,
		},
		{
			name:        "reverts_on_overflow_with_all_max_inputs",
			x:           MAX_UINT256,
			y:           MAX_UINT256,
			denominator: "115792089237316195423570985008687907853269984665640564039457584007913129639934", // MAX - 1
			shouldPanic: true,
		},
		{
			name:        "all_max_inputs",
			x:           MAX_UINT256,
			y:           MAX_UINT256,
			denominator: MAX_UINT256,
			expected:    MAX_UINT256,
			shouldPanic: false,
		},
		{
			name:        "accurate_without_phantom_overflow",
			x:           "340282366920938463463374607431768211456", // Q128
			y:           "170141183460469231731687303715884105728", // 50 * Q128 / 100
			denominator: "510423550381407695195061911147652317184", // 150 * Q128 / 100
			expected:    "113427455640312821154458202477256070485", // Q128 / 3
			shouldPanic: false,
		},
		{
			name:        "accurate_with_phantom_overflow",
			x:           "340282366920938463463374607431768211456",  // Q128
			y:           "11918638020448045647681625305856008960",   // 35 * Q128
			denominator: "2722258935367507707098708226174313472",    // 8 * Q128
			expected:    "1489829752556005706293105552577847509729", // 4375 * Q128 / 1000 (0.12% diff)
			shouldPanic: false,
		},
		{
			name:        "accurate_with_phantom_overflow_and_repeating_decimal",
			x:           "340282366920938463463374607431768211456",     // Q128
			y:           "340282366920938463463374607431768211456000",  // 1000 * Q128
			denominator: "1020847100762815390390123822295304634368000", // 3000 * Q128
			expected:    "113427455640312821154458202477256070485",
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if (r != nil) != tt.shouldPanic {
					t.Errorf("panic = %v, shouldPanic = %v", r, tt.shouldPanic)
				}
			}()

			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			denominator := MustFromDecimal(tt.denominator)

			result := MulDiv(x, y, denominator)

			if !tt.shouldPanic && !result.Eq(MustFromDecimal(tt.expected)) {
				t.Errorf("MulDiv(%s, %s, %s) = %s, want %s",
					tt.x, tt.y, tt.denominator, result.ToString(), tt.expected)
			}
		})
	}
}

func TestMulDivRoundingUpSimple(t *testing.T) {
	tests := []struct {
		name        string
		x           string
		y           string
		denominator string
		expected    string
		shouldPanic bool
	}{
		{
			name:        "reverts_if_denominator_is_0",
			x:           "340282366920938463463374607431768211456", // Q128
			y:           "5",
			denominator: "0",
			shouldPanic: true,
		},
		{
			name:        "reverts_if_denominator_is_0_and_numerator_overflows",
			x:           "340282366920938463463374607431768211456", // Q128
			y:           "340282366920938463463374607431768211456", // Q128
			denominator: "0",
			shouldPanic: true,
		},
		{
			name:        "reverts_if_output_overflows_uint256",
			x:           "340282366920938463463374607431768211456", // Q128
			y:           "340282366920938463463374607431768211456", // Q128
			denominator: "1",
			shouldPanic: true,
		},
		{
			name:        "reverts_on_overflow_with_all_max_inputs",
			x:           MAX_UINT256,
			y:           MAX_UINT256,
			denominator: "115792089237316195423570985008687907853269984665640564039457584007913129639934", // MAX - 1
			shouldPanic: true,
		},
		{
			name:        "reverts_if_mulDiv_overflows_256_bits_after_rounding_up",
			x:           "535006138814359",
			y:           "432862656469423142931042426214547535783388063929571229938474969",
			denominator: "2",
			shouldPanic: true,
		},
		{
			name:        "reverts_if_mulDiv_overflows_256_bits_after_rounding_up_case_2",
			x:           "115792089237316195423570985008687907853269984659341747863450311749907997002549",
			y:           "115792089237316195423570985008687907853269984659341747863450311749907997002550",
			denominator: "115792089237316195423570985008687907853269984653042931687443039491902864365164",
			shouldPanic: true,
		},
		{
			name:        "all_max_inputs",
			x:           MAX_UINT256,
			y:           MAX_UINT256,
			denominator: MAX_UINT256,
			expected:    MAX_UINT256,
			shouldPanic: false,
		},
		{
			name:        "accurate_without_phantom_overflow",
			x:           "340282366920938463463374607431768211456",   // Q128
			y:           "17014118346046923173168730371588410572800", // 50 * Q128
			denominator: "51042355038140769519506191114765231718400", // 150 * Q128
			expected:    "113427455640312821154458202477256070486",   // Q128/3 + 1
			shouldPanic: false,
		},
		{
			name:        "accurate_with_phantom_overflow",
			x:           "340282366920938463463374607431768211456",  // Q128
			y:           "11918638020448045647681625305856008960",   // 35 * Q128
			denominator: "2722258935367507707098708226174313472",    // 8 * Q128
			expected:    "1489829752556005706293105552577847509730", // 4375 * Q128 / 1000 (0.12% diff)
			shouldPanic: false,
		},
		{
			name:        "accurate_with_phantom_overflow_and_repeating_decimal",
			x:           "340282366920938463463374607431768211456",     // Q128
			y:           "340282366920938463463374607431768211456000",  // 1000 * Q128
			denominator: "1020847100762815390390123822295304634368000", // 3000 * Q128
			expected:    "113427455640312821154458202477256070486",     // Q128/3 + 1
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if (r != nil) != tt.shouldPanic {
					t.Errorf("panic = %v, shouldPanic = %v", r, tt.shouldPanic)
				}
			}()

			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			denominator := MustFromDecimal(tt.denominator)

			result := MulDivRoundingUp(x, y, denominator)

			if !tt.shouldPanic && !result.Eq(MustFromDecimal(tt.expected)) {
				t.Errorf("MulDivRoundingUp(%s, %s, %s) = %s, want %s",
					tt.x, tt.y, tt.denominator, result.ToString(), tt.expected)
			}
		})
	}
}

func TestFromDecimal(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
		wantErr  bool
	}{
		// basic
		{
			name:     "zero",
			input:    "0",
			expected: "0",
			wantErr:  false,
		},
		{
			name:     "one",
			input:    "1",
			expected: "1",
			wantErr:  false,
		},
		{
			name:     "max_uint64",
			input:    "18446744073709551615",
			expected: "18446744073709551615",
			wantErr:  false,
		},
		{
			name:     "max_uint128",
			input:    "340282366920938463463374607431768211455",
			expected: "340282366920938463463374607431768211455",
			wantErr:  false,
		},
		{
			name:     "max_uint256",
			input:    MAX_UINT256,
			expected: MAX_UINT256,
			wantErr:  false,
		},
		// overflow cases
		{
			name:     "max_uint256_plus_one",
			input:    "115792089237316195423570985008687907853269984665640564039457584007913129639936",
			expected: "",
			wantErr:  true,
		},
		{
			name:     "all_nines_76_digits",
			input:    "9999999999999999999999999999999999999999999999999999999999999999999999999999",
			expected: "9999999999999999999999999999999999999999999999999999999999999999999999999999",
			wantErr:  false,
		},
		{
			name:     "all_nines_77_digits_valid",
			input:    "99999999999999999999999999999999999999999999999999999999999999999999999999999",
			expected: "99999999999999999999999999999999999999999999999999999999999999999999999999999",
			wantErr:  false,
		},
		{
			name:     "all_nines_78_digits_overflow",
			input:    "999999999999999999999999999999999999999999999999999999999999999999999999999999",
			expected: "",
			wantErr:  true,
		},
		{
			name:     "max_uint256_with_leading_digit_overflow",
			input:    "1115792089237316195423570985008687907853269984665640564039457584007913129639935",
			expected: "",
			wantErr:  true,
		},
		// format tests
		{
			name:     "leading_zeros",
			input:    "00000000000000000000000001234567890",
			expected: "1234567890",
			wantErr:  false,
		},
		{
			name:     "plus_sign",
			input:    "+12345",
			expected: "12345",
			wantErr:  false,
		},
		{
			name:     "multiple_plus_signs",
			input:    "++12345",
			expected: "",
			wantErr:  true,
		},
		{
			name:     "negative_number",
			input:    "-12345",
			expected: "",
			wantErr:  true,
		},
		{
			name:     "empty_string",
			input:    "",
			expected: "",
			wantErr:  true,
		},
		{
			name:     "invalid_characters",
			input:    "123abc456",
			expected: "",
			wantErr:  true,
		},
		// edge cases
		{
			name:     "all_nines_19_digits",
			input:    "9999999999999999999",
			expected: "9999999999999999999",
			wantErr:  false,
		},
		{
			name:     "all_nines_38_digits",
			input:    "99999999999999999999999999999999999999",
			expected: "99999999999999999999999999999999999999",
			wantErr:  false,
		},
		{
			name:     "near_overflow_76_digits",
			input:    "9999999999999999999999999999999999999999999999999999999999999999999999999999",
			expected: "9999999999999999999999999999999999999999999999999999999999999999999999999999",
			wantErr:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := FromDecimal(tt.input)
			if (err != nil) != tt.wantErr {
				t.Errorf("FromDecimal() error = %v, wantErr %v", err, tt.wantErr)
			}
			if !tt.wantErr && result.ToString() != tt.expected {
				t.Errorf("FromDecimal() = %v, want %v", result.ToString(), tt.expected)
			}
		})
	}
}

func TestFromDecimalEdgeCases(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantErr bool
		errMsg  string
	}{
		{
			name:    "only_plus_sign",
			input:   "+",
			wantErr: true,
			errMsg:  "single plus sign should fail",
		},
		{
			name:    "multiple_zeros",
			input:   "00000",
			wantErr: false,
			errMsg:  "multiple zeros should parse to 0",
		},
		{
			name:    "plus_zero",
			input:   "+0",
			wantErr: false,
			errMsg:  "plus zero should parse to 0",
		},
		{
			name:    "spaces_in_number",
			input:   "123 456",
			wantErr: true,
			errMsg:  "spaces should not be allowed",
		},
		{
			name:    "decimal_point",
			input:   "123.456",
			wantErr: true,
			errMsg:  "decimal points should not be allowed",
		},
		{
			name:    "scientific_notation",
			input:   "1e18",
			wantErr: true,
			errMsg:  "scientific notation should not be allowed",
		},
		{
			name:    "unicode_digits",
			input:   "१२३", // Unicode digits
			wantErr: true,
			errMsg:  "unicode digits should not be allowed",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := FromDecimal(tt.input)
			if (err != nil) != tt.wantErr {
				t.Errorf("%s: error = %v, wantErr %v", tt.errMsg, err, tt.wantErr)
			}
		})
	}
}

func TestFromHex(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
		wantErr  bool
	}{
		// basic
		{
			name:     "zero",
			input:    "0x0",
			expected: "0",
			wantErr:  false,
		},
		{
			name:     "one",
			input:    "0x1",
			expected: "1",
			wantErr:  false,
		},
		{
			name:     "max_uint256",
			input:    "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
			expected: MAX_UINT256,
			wantErr:  false,
		},
		// overflow
		{
			name:     "hex_overflow_67_chars",
			input:    "0x10000000000000000000000000000000000000000000000000000000000000000",
			expected: "",
			wantErr:  true,
		},
		// format error
		{
			name:     "no_0x_prefix",
			input:    "ffffffff",
			expected: "",
			wantErr:  true,
		},
		{
			name:     "empty_string",
			input:    "",
			expected: "",
			wantErr:  true,
		},
		{
			name:     "only_0x",
			input:    "0x",
			expected: "",
			wantErr:  true,
		},
		{
			name:     "invalid_hex_chars",
			input:    "0xgg",
			expected: "",
			wantErr:  true,
		},
		{
			name:     "uppercase_0X",
			input:    "0Xff",
			expected: "255",
			wantErr:  false,
		},
		{
			name:     "mixed_case",
			input:    "0xAbCdEf",
			expected: "11259375",
			wantErr:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := FromHex(tt.input)
			if (err != nil) != tt.wantErr {
				t.Errorf("FromHex() error = %v, wantErr %v", err, tt.wantErr)
			}
			if !tt.wantErr && result.ToString() != tt.expected {
				t.Errorf("FromHex() = %v, want %v", result.ToString(), tt.expected)
			}
		})
	}
}

func TestBitOperations(t *testing.T) {
	tests := []struct {
		name      string
		operation string
		x         string
		y         string
		n         uint
		expected  string
	}{
		// Left shift
		{
			name:      "lsh_zero",
			operation: "lsh",
			x:         "0",
			n:         100,
			expected:  "0",
		},
		{
			name:      "lsh_one_by_zero",
			operation: "lsh",
			x:         "1",
			n:         0,
			expected:  "1",
		},
		{
			name:      "lsh_one_by_one",
			operation: "lsh",
			x:         "1",
			n:         1,
			expected:  "2",
		},
		{
			name:      "lsh_one_by_64",
			operation: "lsh",
			x:         "1",
			n:         64,
			expected:  "18446744073709551616",
		},
		{
			name:      "lsh_one_by_128",
			operation: "lsh",
			x:         "1",
			n:         128,
			expected:  "340282366920938463463374607431768211456",
		},
		{
			name:      "lsh_one_by_192",
			operation: "lsh",
			x:         "1",
			n:         192,
			expected:  "6277101735386680763835789423207666416102355444464034512896",
		},
		{
			name:      "lsh_one_by_255",
			operation: "lsh",
			x:         "1",
			n:         255,
			expected:  "57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
		{
			name:      "lsh_one_by_256_overflow",
			operation: "lsh",
			x:         "1",
			n:         256,
			expected:  "0",
		},
		{
			name:      "lsh_max_by_one_overflow",
			operation: "lsh",
			x:         MAX_UINT256,
			n:         1,
			expected:  "115792089237316195423570985008687907853269984665640564039457584007913129639934",
		},
		// Right shift
		{
			name:      "rsh_zero",
			operation: "rsh",
			x:         "0",
			n:         100,
			expected:  "0",
		},
		{
			name:      "rsh_by_64",
			operation: "rsh",
			x:         "340282366920938463463374607431768211456", // 2^128
			n:         64,
			expected:  "18446744073709551616",
		},
		{
			name:      "rsh_max_by_one",
			operation: "rsh",
			x:         MAX_UINT256,
			n:         1,
			expected:  "57896044618658097711785492504343953926634992332820282019728792003956564819967",
		},
		{
			name:      "rsh_max_by_255",
			operation: "rsh",
			x:         MAX_UINT256,
			n:         255,
			expected:  "1",
		},
		{
			name:      "rsh_max_by_256",
			operation: "rsh",
			x:         MAX_UINT256,
			n:         256,
			expected:  "0",
		},
		{
			name:      "rsh_power_of_two",
			operation: "rsh",
			x:         "57896044618658097711785492504343953926634992332820282019728792003956564819968", // 2^255
			n:         255,
			expected:  "1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			var result *Uint

			switch tt.operation {
			case "lsh":
				result = new(Uint).Lsh(x, tt.n)
			case "rsh":
				result = new(Uint).Rsh(x, tt.n)
			}

			if result.ToString() != tt.expected {
				t.Errorf("%s(%s, %d) = %s, want %s", tt.operation, tt.x, tt.n, result.ToString(), tt.expected)
			}
		})
	}
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
			name:     "byte_7_of_max",
			x:        MAX_UINT256,
			n:        7,
			expected: "255",
		},
		{
			name:     "byte_8_of_max",
			x:        MAX_UINT256,
			n:        8,
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
			name:     "byte_100_out_of_range",
			x:        MAX_UINT256,
			n:        100,
			expected: "0",
		},
		{
			name:     "byte_0_of_256",
			x:        "256",
			n:        30,
			expected: "1",
		},
		{
			name:     "byte_31_of_255",
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

			if result.ToString() != tt.expected {
				t.Errorf("Byte(%s, %d) = %s, want %s", tt.x, tt.n, result.ToString(), tt.expected)
			}
		})
	}
}

func TestInPlaceSafety(t *testing.T) {
	// Original values should not be mutated
	t.Run("add_no_mutation", func(t *testing.T) {
		a := MustFromDecimal("1234567890")
		b := MustFromDecimal("9876543210")
		original_a := a.Clone()
		original_b := b.Clone()

		c := new(Uint).Add(a, b)

		if !a.Eq(original_a) {
			t.Error("Add mutated first operand")
		}
		if !b.Eq(original_b) {
			t.Error("Add mutated second operand")
		}
		if c.Eq(a) || c.Eq(b) {
			t.Error("Result shares memory with operands")
		}
	})

	// Chain operations
	t.Run("chain_operations", func(t *testing.T) {
		a := MustFromDecimal("1000000")
		b := MustFromDecimal("2000000")
		c := MustFromDecimal("3000000")

		// (a + b) * c
		temp := new(Uint).Add(a, b)
		result := new(Uint).Mul(temp, c)

		expected := MustFromDecimal("9000000000000")
		if !result.Eq(expected) {
			t.Errorf("Chain operation failed: got %s, want %s",
				result.ToString(), expected.ToString())
		}

		// Original values unchanged
		if !a.Eq(MustFromDecimal("1000000")) {
			t.Error("a was mutated")
		}
	})
}

// Essential test to add to uint256_test.gno

func TestFromDecimalInvalidFormat(t *testing.T) {
	// Current tests only cover valid number formats,
	// but lack tests for malformed inputs
	invalidCases := []string{
		"12 34",     // spaces in number
		"12.34",     // decimal point
		"0b1010",    // binary notation
		"1_000_000", // underscores
		"abc",       // letters
		"1e10",      // scientific notation
		"--1",       // double sign
		"+-1",       // mixed signs
		"+",         // sign only
		"1+2",       // expression
		"০১২৩",      // non-ASCII digits (Bengali numerals)
	}

	for _, input := range invalidCases {
		t.Run(fmt.Sprintf("invalid_%s", input), func(t *testing.T) {
			_, err := FromDecimal(input)
			if err == nil {
				t.Errorf("FromDecimal(%q) should fail but didn't", input)
			}
		})
	}
}

func TestOperationConsistency(t *testing.T) {
	t.Run("different_paths_same_result", func(t *testing.T) {
		a := NewUint(12345)
		b := NewUint(67890)
		c := NewUint(11111)

		// (a + b) + c
		path1 := new(Uint).Add(a, b)
		path1.Add(path1, c)

		// a + (b + c)
		path2 := new(Uint).Add(b, c)
		path2.Add(a, path2)

		if !path1.Eq(path2) {
			t.Error("Addition associativity failed")
		}

		// a * (b + c) vs (a * b) + (a * c)
		sum := new(Uint).Add(b, c)
		dist1 := new(Uint).Mul(a, sum)

		prod1 := new(Uint).Mul(a, b)
		prod2 := new(Uint).Mul(a, c)
		dist2 := new(Uint).Add(prod1, prod2)

		if !dist1.Eq(dist2) {
			t.Error("Multiplication distributivity failed")
		}
	})

	t.Run("inverse_operations", func(t *testing.T) {
		x := MustFromDecimal("123456789012345678901234567890")

		// x + y - y = x
		y := MustFromDecimal("999999999999999999999999999999")
		result := new(Uint).Add(x, y)
		result.Sub(result, y)
		if !result.Eq(x) {
			t.Error("Add/Sub inverse failed")
		}

		// x * y / y = x (when no remainder)
		y = NewUint(12345)
		result = new(Uint).Mul(x, y)
		result, _ = new(Uint).Div(result, y)
		if !result.Eq(x) {
			t.Error("Mul/Div inverse failed")
		}

		// x << n >> n = x (when n < bitlen(x))
		n := uint(10)
		result = new(Uint).Lsh(x, n)
		result = new(Uint).Rsh(result, n)
		if !result.Eq(x) {
			t.Error("Lsh/Rsh inverse failed")
		}
	})
}

func TestBoundaryStress(t *testing.T) {
	maxUint256 := MustFromDecimal(MAX_UINT256)
	maxUint128 := MustFromDecimal("340282366920938463463374607431768211455") // 2^128 - 1
	maxUint64 := NewUint(18446744073709551615)                               // 2^64 - 1

	boundaries := []*Uint{
		Zero(),
		One(),
		NewUint(255),
		NewUint(256),
		NewUint(65535),
		NewUint(65536),
		maxUint64,
		new(Uint).Add(maxUint64, one),
		maxUint128,
		new(Uint).Add(maxUint128, one),
		new(Uint).Sub(maxUint256, one),
		maxUint256,
	}

	// boundary tests
	for i, a := range boundaries {
		for j, b := range boundaries {
			testName := fmt.Sprintf("boundary_%d_%d", i, j)

			// Addition overflow check
			_, overflow := new(Uint).AddOverflow(a, b)
			sum := new(Uint).Add(a, b)
			if overflow && !sum.Lt(a) && !sum.Lt(b) {
				t.Errorf("%s: Add overflow not detected correctly", testName)
			}

			// Subtraction underflow check
			if a.Gte(b) {
				result := new(Uint).Sub(a, b)
				// result + b should equal a
				check := new(Uint).Add(result, b)
				if !check.Eq(a) {
					t.Errorf("%s: Sub failed", testName)
				}
			}

			// Division by zero check
			if !b.IsZero() {
				_, err := new(Uint).Div(a, b)
				if err != nil {
					t.Errorf("%s: Unexpected division error: %v", testName, err)
				}
			}
		}
	}
}
