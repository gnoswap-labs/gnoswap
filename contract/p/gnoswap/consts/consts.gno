package consts

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// u256.Uint and i256.Int are little-endian [4]uint64:
// {arr[0]=least significant, arr[1], arr[2], arr[3]=most significant}.

// MaxUint256 returns 2^256 - 1.
func MaxUint256() *u256.Uint {
	return &u256.Uint{18446744073709551615, 18446744073709551615, 18446744073709551615, 18446744073709551615}
}

// MaxUint128 returns 2^128 - 1, the maximum uint128 value.
func MaxUint128() *u256.Uint {
	return &u256.Uint{18446744073709551615, 18446744073709551615, 0, 0}
}

// MaxInt256 returns 2^255 - 1, the maximum int256 value, as an unsigned u256.
func MaxInt256() *u256.Uint {
	return &u256.Uint{18446744073709551615, 18446744073709551615, 18446744073709551615, 9223372036854775807}
}

// Q96 returns 2^96, the Q64.96 fixed-point scaling factor.
func Q96() *u256.Uint {
	return &u256.Uint{0, 4294967296, 0, 0}
}

// Q128 returns 2^128, the Q128.128 fixed-point scaling factor.
func Q128() *u256.Uint {
	return &u256.Uint{0, 0, 1, 0}
}

// Q192 returns 2^192.
func Q192() *u256.Uint {
	return &u256.Uint{0, 0, 0, 1}
}

// Max160 returns 2^160 - 1, the maximum value representable in 160 bits.
func Max160() *u256.Uint {
	return &u256.Uint{18446744073709551615, 18446744073709551615, 4294967295, 0}
}

// MinSqrtRatio returns the minimum valid sqrt price ratio (4295128739),
// equal to TickMathGetSqrtRatioAtTick(minTick).
func MinSqrtRatio() *u256.Uint {
	return &u256.Uint{4295128739, 0, 0, 0}
}

// MaxSqrtRatio returns the maximum valid sqrt price ratio
// (1461446703485210103287273052203988822378723970342),
// equal to TickMathGetSqrtRatioAtTick(maxTick).
func MaxSqrtRatio() *u256.Uint {
	return &u256.Uint{6743328256752651558, 17280870778742802505, 4294805859, 0}
}

// MaxInt128I256 returns 2^127 - 1, the maximum int128 value, as a signed i256.
func MaxInt128I256() *i256.Int {
	return &i256.Int{18446744073709551615, 9223372036854775807, 0, 0}
}

// MaxInt64I256 returns 2^63 - 1, the maximum int64 value, as a signed i256.
func MaxInt64I256() *i256.Int {
	return &i256.Int{9223372036854775807, 0, 0, 0}
}

// MinInt64I256 returns -2^63, the minimum int64 value, as a signed i256.
func MinInt64I256() *i256.Int {
	return &i256.Int{9223372036854775808, 18446744073709551615, 18446744073709551615, 18446744073709551615}
}
