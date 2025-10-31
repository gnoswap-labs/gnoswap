package v1

import "math"

// safeAddInt64 performs safe addition of int64 values, panicking on overflow or underflow
func safeAddInt64(a, b int64) int64 {
	if a > 0 && b > math.MaxInt64-a {
		panic("int64 addition overflow")
	}

	if a < 0 && b < math.MinInt64-a {
		panic("int64 addition underflow")
	}

	return a + b
}

// safeSubInt64 performs safe subtraction of int64 values, panicking on overflow or underflow
func safeSubInt64(a, b int64) int64 {
	if b > 0 && a < math.MinInt64+b {
		panic("int64 subtraction underflow")
	}

	if b < 0 && a > math.MaxInt64+b {
		panic("int64 subtraction overflow")
	}

	return a - b
}
