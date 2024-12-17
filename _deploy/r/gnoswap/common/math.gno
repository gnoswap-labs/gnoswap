package common

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// I64Min returns the minimum of two int64 values
func I64Min(x, y int64) int64 {
	if x < y {
		return x
	}
	return y
}

// I64Max returns the maximum of two int64 values
func I64Max(x, y int64) int64 {
	if x > y {
		return x
	}
	return y
}

// U64Min returns the minimum of two uint64 values
func U64Min(x, y uint64) uint64 {
	if x < y {
		return x
	}
	return y
}

// U64Max returns the maximum of two uint64 values
func U64Max(x, y uint64) uint64 {
	if x > y {
		return x
	}
	return y
}

// I256Min returns the minimum of two Int256 values
func I256Min(x, y *i256.Int) *i256.Int {
	if x.Cmp(y) < 0 {
		return x
	}
	return y
}

// I256Max returns the maximum of two Int256 values
func I256Max(x, y *i256.Int) *i256.Int {
	if x.Cmp(y) > 0 {
		return x
	}
	return y
}

// U256Min returns the minimum of two Uint256 values
func U256Min(x, y *u256.Uint) *u256.Uint {
	if x.Cmp(y) < 0 {
		return x
	}
	return y
}

// U256Max returns the maximum of two Uint256 values
func U256Max(x, y *u256.Uint) *u256.Uint {
	if x.Cmp(y) > 0 {
		return x
	}
	return y
}
