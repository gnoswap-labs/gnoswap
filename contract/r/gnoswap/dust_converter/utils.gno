package dust_converter

import "math"

func safeAddInt64(a, b int64) int64 {
	if (b > 0 && a > math.MaxInt64-b) || (b < 0 && a < math.MinInt64-b) {
		panic("int64 overflow")
	}
	return a + b
}

func safeSubInt64(a, b int64) int64 {
	if (b > 0 && a < math.MinInt64+b) || (b < 0 && a > math.MaxInt64+b) {
		panic("int64 overflow")
	}
	return a - b
}

func applyFee(amount int64) (netAmount, feeAmount int64) {
	if amount <= 0 || feeBps == 0 {
		return amount, 0
	}
	feeAmount = amount * int64(feeBps) / feeDenominator
	return safeSubInt64(amount, feeAmount), feeAmount
}
