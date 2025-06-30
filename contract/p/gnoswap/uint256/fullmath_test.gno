package uint256

import (
	"testing"
)

var Q128 *Uint

func init() {
	Q128 = MustFromDecimal("340282366920938463463374607431768211456") // 2**128
}

func TestFullMathMulDiv(t *testing.T) {
	tests := []struct {
		name      string
		x         string
		y         string
		denom     string
		want      string
		wantPanic bool
	}{
		// Basic cases
		{
			name:      "simple_multiplication_division",
			x:         "100",
			y:         "200",
			denom:     "50",
			want:      "400",
			wantPanic: false,
		},
		{
			name:      "exact_division",
			x:         "1000",
			y:         "3000",
			denom:     "100",
			want:      "30000",
			wantPanic: false,
		},

		// Division by zero
		{
			name:      "reverts_if_denominator_is_0",
			x:         "340282366920938463463374607431768211456", // Q128
			y:         "5",
			denom:     "0",
			want:      "",
			wantPanic: true,
		},
		{
			name:      "reverts_if_denominator_is_0_and_numerator_overflows",
			x:         "340282366920938463463374607431768211456", // Q128
			y:         "340282366920938463463374607431768211456", // Q128
			denom:     "0",
			want:      "",
			wantPanic: true,
		},

		// Overflow cases
		{
			name:      "reverts_if_output_overflows_uint256",
			x:         "340282366920938463463374607431768211456", // Q128
			y:         "340282366920938463463374607431768211456", // Q128
			denom:     "1",
			want:      "",
			wantPanic: true,
		},
		{
			name:      "reverts_on_overflow_with_all_max_inputs",
			x:         MAX_UINT256,
			y:         MAX_UINT256,
			denom:     "115792089237316195423570985008687907853269984665640564039457584007913129639934", // MAX - 1
			want:      "",
			wantPanic: true,
		},

		// Boundary cases
		{
			name:      "all_max_inputs",
			x:         MAX_UINT256,
			y:         MAX_UINT256,
			denom:     MAX_UINT256,
			want:      MAX_UINT256,
			wantPanic: false,
		},
		{
			name:      "zero_numerator",
			x:         "0",
			y:         "1000",
			denom:     "100",
			want:      "0",
			wantPanic: false,
		},

		// Q128 related calculations
		{
			name:      "q128_divided_by_3",
			x:         "340282366920938463463374607431768211456", // Q128
			y:         "1",
			denom:     "3",
			want:      "113427455640312821154458202477256070485",
			wantPanic: false,
		},
		{
			name:      "accurate_without_phantom_overflow",
			x:         "340282366920938463463374607431768211456", // Q128
			y:         "170141183460469231731687303715884105728", // 0.5 * Q128
			denom:     "510423550381407695195061911147652317184", // 1.5 * Q128
			want:      "113427455640312821154458202477256070485", // Q128 / 3
			wantPanic: false,
		},

		// Phantom overflow cases (product > 256 bits but result fits)
		{
			name:      "phantom_overflow_case_1",
			x:         "340282366920938463463374607431768211456",  // Q128
			y:         "11930464781601263584560605149792510336",   // 35 * Q128 / 1000
			denom:     "2722258935367507707706996859454145691648", // 8 * Q128
			want:      "1491308097700157948070075643724063792",    // 4375 * Q128 / 1000
			wantPanic: false,
		},
		{
			name:      "phantom_overflow_repeating_decimal",
			x:         "340282366920938463463374607431768211456",     // Q128
			y:         "340282366920938463463374607431768211456000",  // 1000 * Q128
			denom:     "1020847100762815390390123822295304634368000", // 3000 * Q128
			want:      "113427455640312821154458202477256070485",     // Q128 / 3
			wantPanic: false,
		},

		// Powers of 2 edge cases
		{
			name:      "power_of_2_division",
			x:         "57896044618658097711785492504343953926634992332820282019728792003956564819968", // 2^255
			y:         "2",
			denom:     "4",
			want:      "28948022309329048855892746252171976963317496166410141009864396001978282409984", // 2^254
			wantPanic: false,
		},
		{
			name:      "q128_minus_1_squared_divided_by_q128",
			x:         "340282366920938463463374607431768211455", // Q128 - 1
			y:         "340282366920938463463374607431768211455", // Q128 - 1
			denom:     "340282366920938463463374607431768211456", // Q128
			want:      "340282366920938463463374607431768211454", // Q128 - 2
			wantPanic: false,
		},

		// Large prime division
		{
			name:      "large_prime_division",
			x:         "115792089237316195423570985008687907853269984665640564039457584007913129639926", // prime - 1
			y:         "115792089237316195423570985008687907853269984665640564039457584007913129639927", // prime
			denom:     "115792089237316195423570985008687907853269984665640564039457584007913129639927", // prime
			want:      "115792089237316195423570985008687907853269984665640564039457584007913129639926", // prime - 1
			wantPanic: false,
		},

		// Power of 2 combinations
		{
			name:      "2_192_times_2_63_divided_by_2_255",
			x:         "6277101735386680763835789423207666416102355444464034512896",                    // 2^192
			y:         "9223372036854775808",                                                           // 2^63
			denom:     "57896044618658097711785492504343953926634992332820282019728792003956564819968", // 2^255
			want:      "1",
			wantPanic: false,
		},
		{
			name:      "2_200_times_2_55_divided_by_2_250",
			x:         "1606938044258990275541962092341162602522202993782792835301376",                // 2^200
			y:         "36028797018963968",                                                            // 2^55
			denom:     "1809251394333065553493296640760748560207343510400633813116524750123642650624", // 2^250
			want:      "32",
			wantPanic: false,
		},

		// sqrt(MAX) cases
		{
			name:      "sqrt_max_squared_divided_by_max",
			x:         "340282366920938463463374607431768211455", // ~sqrt(MAX)
			y:         "340282366920938463463374607431768211455",
			denom:     MAX_UINT256,
			want:      "0",
			wantPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			x := MustFromDecimal(tc.x)
			y := MustFromDecimal(tc.y)
			denom := MustFromDecimal(tc.denom)

			if tc.wantPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("MulDiv(%s, %s, %s) expected panic but got none", tc.x, tc.y, tc.denom)
					}
				}()
				MulDiv(x, y, denom)
				return
			}

			got := MulDiv(x, y, denom)
			want := MustFromDecimal(tc.want)

			if !got.Eq(want) {
				t.Errorf("MulDiv(%s, %s, %s) = %s, want %s", tc.x, tc.y, tc.denom, got.ToString(), tc.want)
			}
		})
	}
}

func TestMulDivRoundingUp(t *testing.T) {
	tests := []struct {
		name      string
		x         string
		y         string
		denom     string
		want      string
		wantPanic bool
	}{
		// Basic cases with rounding
		{
			name:      "no_rounding_needed",
			x:         "100",
			y:         "200",
			denom:     "50",
			want:      "400",
			wantPanic: false,
		},
		{
			name:      "rounding_up_needed",
			x:         "100",
			y:         "201",
			denom:     "50",
			want:      "402", // 201*100/50 = 402
			wantPanic: false,
		},

		// Division by zero
		{
			name:      "reverts_if_denominator_is_0",
			x:         "340282366920938463463374607431768211456", // Q128
			y:         "5",
			denom:     "0",
			want:      "",
			wantPanic: true,
		},
		{
			name:      "reverts_if_denominator_is_0_and_numerator_overflows",
			x:         "340282366920938463463374607431768211456", // Q128
			y:         "340282366920938463463374607431768211456", // Q128
			denom:     "0",
			want:      "",
			wantPanic: true,
		},

		// Overflow cases
		{
			name:      "reverts_if_output_overflows_uint256",
			x:         "340282366920938463463374607431768211456", // Q128
			y:         "340282366920938463463374607431768211456", // Q128
			denom:     "1",
			want:      "",
			wantPanic: true,
		},
		{
			name:      "reverts_if_mulDiv_overflows_256_bits_after_rounding_up",
			x:         "535006138814359",
			y:         "432862656469423142931042426214547535783388063929571229938474969",
			denom:     "2",
			want:      "",
			wantPanic: true,
		},
		{
			name:      "reverts_if_mulDiv_overflows_256_bits_after_rounding_up_case_2",
			x:         "115792089237316195423570985008687907853269984659341747863450311749907997002549",
			y:         "115792089237316195423570985008687907853269984659341747863450311749907997002550",
			denom:     "115792089237316195423570985008687907853269984653042931687443039491902864365164",
			want:      "",
			wantPanic: true,
		},

		// Boundary cases
		{
			name:      "all_max_inputs",
			x:         MAX_UINT256,
			y:         MAX_UINT256,
			denom:     MAX_UINT256,
			want:      MAX_UINT256,
			wantPanic: false,
		},
		{
			name:      "max_result_no_overflow",
			x:         MAX_UINT256,
			y:         "1",
			denom:     "1",
			want:      MAX_UINT256,
			wantPanic: false,
		},

		// Q128 calculations with rounding
		{
			name:      "q128_divided_by_3_rounded_up",
			x:         "340282366920938463463374607431768211456", // Q128
			y:         "1",
			denom:     "3",
			want:      "113427455640312821154458202477256070486", // (Q128 / 3) + 1
			wantPanic: false,
		},
		{
			name:      "accurate_without_phantom_overflow_rounded_up",
			x:         "340282366920938463463374607431768211456", // Q128
			y:         "170141183460469231731687303715884105728", // 0.5 * Q128
			denom:     "510423550381407695195061911147652317184", // 1.5 * Q128
			want:      "113427455640312821154458202477256070486", // (Q128 / 3) + 1
			wantPanic: false,
		},

		// Phantom overflow cases
		{
			name:      "phantom_overflow_with_rounding",
			x:         "340282366920938463463374607431768211456",  // Q128
			y:         "11930464781601263584560605149792510336",   // 35 * Q128 / 1000
			denom:     "2722258935367507707706996859454145691648", // 8 * Q128
			want:      "1491308097700157948070075643724063792",    // 4375 * Q128 / 1000 (exact)
			wantPanic: false,
		},
		{
			name:      "phantom_overflow_repeating_decimal_rounded_up",
			x:         "340282366920938463463374607431768211456",     // Q128
			y:         "340282366920938463463374607431768211456000",  // 1000 * Q128
			denom:     "1020847100762815390390123822295304634368000", // 3000 * Q128
			want:      "113427455640312821154458202477256070486",     // (Q128 / 3) + 1
			wantPanic: false,
		},

		// Edge cases for rounding
		{
			name:      "max_minus_1_divided_by_max_rounded_up",
			x:         "115792089237316195423570985008687907853269984665640564039457584007913129639934", // MAX - 1
			y:         "1",
			denom:     MAX_UINT256,
			want:      "1", // 0 + 1
			wantPanic: false,
		},
		{
			name:      "exact_division_no_rounding",
			x:         "1000",
			y:         "2000",
			denom:     "100",
			want:      "20000",
			wantPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			x := MustFromDecimal(tc.x)
			y := MustFromDecimal(tc.y)
			denom := MustFromDecimal(tc.denom)

			if tc.wantPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("MulDivRoundingUp(%s, %s, %s) expected panic but got none", tc.x, tc.y, tc.denom)
					}
				}()
				MulDivRoundingUp(x, y, denom)
				return
			}

			got := MulDivRoundingUp(x, y, denom)
			want := MustFromDecimal(tc.want)

			if !got.Eq(want) {
				t.Errorf("MulDivRoundingUp(%s, %s, %s) = %s, want %s", tc.x, tc.y, tc.denom, got.ToString(), tc.want)
			}
		})
	}
}

func TestDivRoundingUp(t *testing.T) {
	tests := []struct {
		name      string
		x         string
		y         string
		want      string
		wantPanic bool
	}{
		// Basic cases
		{
			name:      "exact_division",
			x:         "100",
			y:         "10",
			want:      "10",
			wantPanic: false,
		},
		{
			name:      "division_with_remainder",
			x:         "101",
			y:         "10",
			want:      "11", // 10 + 1
			wantPanic: false,
		},
		{
			name:      "zero_dividend",
			x:         "0",
			y:         "10",
			want:      "0",
			wantPanic: false,
		},

		// Division by zero
		{
			name:      "division_by_zero",
			x:         "100",
			y:         "0",
			want:      "",
			wantPanic: true,
		},

		// Boundary cases
		{
			name:      "max_divided_by_max",
			x:         MAX_UINT256,
			y:         MAX_UINT256,
			want:      "1",
			wantPanic: false,
		},
		{
			name:      "max_minus_1_divided_by_max",
			x:         "115792089237316195423570985008687907853269984665640564039457584007913129639934",
			y:         MAX_UINT256,
			want:      "1", // 0 + 1
			wantPanic: false,
		},
		{
			name:      "one_divided_by_two",
			x:         "1",
			y:         "2",
			want:      "1", // 0 + 1
			wantPanic: false,
		},
		{
			name:      "large_number_exact_division",
			x:         "1000000000000000000000000000000000000000",
			y:         "1000000000000000000",
			want:      "1000000000000000000000",
			wantPanic: false,
		},
		{
			name:      "large_number_with_remainder",
			x:         "1000000000000000000000000000000000000001",
			y:         "1000000000000000000",
			want:      "1000000000000000000001", // rounded up
			wantPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			x := MustFromDecimal(tc.x)
			y := MustFromDecimal(tc.y)

			if tc.wantPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("DivRoundingUp(%s, %s) expected panic but got none", tc.x, tc.y)
					}
				}()
				DivRoundingUp(x, y)
				return
			}

			got := DivRoundingUp(x, y)
			want := MustFromDecimal(tc.want)

			if !got.Eq(want) {
				t.Errorf("DivRoundingUp(%s, %s) = %s, want %s", tc.x, tc.y, got.ToString(), tc.want)
			}
		})
	}
}

// Helper function
func TwoToThe255() *Uint {
	u := &Uint{arr: [4]uint64{0, 0, 0, 1 << 63}}
	return u
}

// Benchmarks
func BenchmarkMulDiv(b *testing.B) {
	x := MustFromDecimal("123456789012345678901234567890")
	y := MustFromDecimal("987654321098765432109876543210")
	z := MustFromDecimal("111111111111111111111111111111")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		MulDiv(x, y, z)
	}
}

func BenchmarkMulDivRoundingUp(b *testing.B) {
	x := MustFromDecimal("123456789012345678901234567890")
	y := MustFromDecimal("987654321098765432109876543210")
	z := MustFromDecimal("111111111111111111111111111111")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		MulDivRoundingUp(x, y, z)
	}
}

func BenchmarkDivRoundingUp(b *testing.B) {
	x := MustFromDecimal("123456789012345678901234567890123456789012345678901234567890")
	y := MustFromDecimal("123456789012345678901234567890")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		DivRoundingUp(x, y)
	}
}
