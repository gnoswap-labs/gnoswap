package fuzzing

import (
	"gno.land/p/gnoswap/int256"
	"gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// Uint256 Generators

type uint256Gen struct {
	min *uint256.Uint
	max *uint256.Uint
}

func (g *uint256Gen) String() string {
	return ufmt.Sprintf("Uint256(%s, %s)", g.min.ToString(), g.max.ToString())
}

func (g *uint256Gen) value(t *T) any {
	// If min >= max, return min
	if g.min.Cmp(g.max) >= 0 {
		return g.min.Clone()
	}

	// Calculate range = max - min
	rangeVal := new(uint256.Uint).Sub(g.max, g.min)

	// For small ranges that fit in uint64
	if rangeVal.IsUint64() {
		rangeU64 := rangeVal.Uint64()
		if rangeU64 == 0 {
			return g.min.Clone()
		}
		randomOffset := Uint64Range(0, rangeU64).Draw(t, "offset").(uint64)
		result := new(uint256.Uint).Add(g.min, uint256.NewUint(randomOffset))
		return result
	}

	// For larger ranges, generate a random value using digit-based approach
	minDigits := len(g.min.ToString())
	maxDigits := len(g.max.ToString())

	numDigits := IntRange(minDigits, maxDigits).Draw(t, "numDigits").(int)

	// Build random decimal string
	firstDigit := IntRange(1, 9).Draw(t, "firstDigit").(int)
	result := ufmt.Sprintf("%d", firstDigit)

	for i := 1; i < numDigits; i++ {
		digit := IntRange(0, 9).Draw(t, ufmt.Sprintf("digit%d", i)).(int)
		result += ufmt.Sprintf("%d", digit)
	}

	val, err := uint256.FromDecimal(result)
	if err != nil || val.Cmp(g.min) < 0 || val.Cmp(g.max) > 0 {
		// If out of range, return min
		return g.min.Clone()
	}

	return val
}

// Uint256 generates random uint256 values across the full uint256 range [0, 2^256-1]
//
// Example:
//   Uint256() generates values from 0 to max uint256
func Uint256() *Generator {
	// Max uint256: 2^256 - 1
	maxStr := "115792089237316195423570985008687907853269984665640564039457584007913129639935"
	max, _ := uint256.FromDecimal(maxStr)
	return newGenerator(&uint256Gen{
		min: uint256.NewUint(0),
		max: max,
	})
}

// Uint256Max generates uint256 values from 0 to the specified max
// max: maximum value as decimal string
//
// Example:
//   Uint256Max("1000000") generates values from 0 to 1000000
func Uint256Max(max string) *Generator {
	maxVal, err := uint256.FromDecimal(max)
	if err != nil {
		maxVal = uint256.NewUint(1000000)
	}
	return newGenerator(&uint256Gen{
		min: uint256.NewUint(0),
		max: maxVal,
	})
}

// Uint256Range generates uint256 values within a specified range [min, max]
// min and max are decimal strings
//
// Example:
//   Uint256Range("1000", "999999") generates values between 1000 and 999999
func Uint256Range(minStr, maxStr string) *Generator {
	min, err := uint256.FromDecimal(minStr)
	if err != nil {
		min = uint256.NewUint(0)
	}

	max, err := uint256.FromDecimal(maxStr)
	if err != nil {
		max = uint256.NewUint(1000000)
	}

	return newGenerator(&uint256Gen{
		min: min,
		max: max,
	})
}

// Uint256Min generates uint256 values from the specified min to uint256 max
// min: minimum value as decimal string
//
// Example:
//   Uint256Min("1000") generates values from 1000 to max uint256
func Uint256Min(min string) *Generator {
	minVal, err := uint256.FromDecimal(min)
	if err != nil {
		minVal = uint256.NewUint(0)
	}
	maxStr := "115792089237316195423570985008687907853269984665640564039457584007913129639935"
	maxVal, _ := uint256.FromDecimal(maxStr)
	return newGenerator(&uint256Gen{
		min: minVal,
		max: maxVal,
	})
}

// Int256 Generators

type int256Gen struct {
	min *int256.Int
	max *int256.Int
}

func (g *int256Gen) String() string {
	return ufmt.Sprintf("Int256(%s, %s)", g.min.ToString(), g.max.ToString())
}

func (g *int256Gen) value(t *T) any {
	// If min >= max, return min
	if g.min.Cmp(g.max) >= 0 {
		return g.min.Clone()
	}

	// Calculate range = max - min
	rangeVal := new(int256.Int).Sub(g.max, g.min)

	// Get absolute value for range calculation
	rangeAbs := rangeVal.Abs()

	// For small ranges that fit in uint64
	if rangeAbs.IsUint64() {
		rangeU64 := rangeAbs.Uint64()
		if rangeU64 == 0 {
			return g.min.Clone()
		}
		randomOffset := Uint64Range(0, rangeU64).Draw(t, "offset").(uint64)
		result := new(int256.Int).Add(g.min, int256.FromUint256(uint256.NewUint(randomOffset)))
		return result
	}

	// For larger ranges, use digit-based approach
	minStr := g.min.ToString()
	maxStr := g.max.ToString()

	// Determine if result should be positive or negative
	minNeg := g.min.Sign() < 0
	maxPos := g.max.Sign() > 0

	var isNegative bool
	if minNeg && maxPos {
		// Range spans zero, randomly choose
		isNegative = Bool().Draw(t, "isNegative").(bool)
	} else {
		isNegative = minNeg
	}

	// Calculate digit range based on sign
	var minDigits, maxDigits int
	if isNegative {
		// For negative, use min's digits (or 1 if positive min)
		if minNeg {
			minDigits = len(minStr) - 1 // subtract '-'
		} else {
			minDigits = 1
		}
		// For max digits, use max if it's negative
		if maxPos {
			// Range crosses zero, so pick moderate size
			maxDigits = minDigits + 10
		} else {
			maxDigits = len(maxStr) - 1 // subtract '-'
		}
	} else {
		// For positive, use min's digits (or 1 if negative min)
		if maxPos {
			maxDigits = len(maxStr)
		} else {
			maxDigits = 1
		}
		if minPos := g.min.Sign() > 0; minPos {
			minDigits = len(minStr)
		} else {
			minDigits = 1
		}
	}

	// Ensure minDigits <= maxDigits
	if minDigits > maxDigits {
		minDigits, maxDigits = maxDigits, minDigits
	}
	if minDigits < 1 {
		minDigits = 1
	}

	numDigits := IntRange(minDigits, maxDigits).Draw(t, "numDigits").(int)

	// Build random decimal string
	firstDigit := IntRange(1, 9).Draw(t, "firstDigit").(int)
	result := ufmt.Sprintf("%d", firstDigit)

	for i := 1; i < numDigits; i++ {
		digit := IntRange(0, 9).Draw(t, ufmt.Sprintf("digit%d", i)).(int)
		result += ufmt.Sprintf("%d", digit)
	}

	if isNegative {
		result = "-" + result
	}

	val, err := int256.FromDecimal(result)
	if err != nil || val.Cmp(g.min) < 0 || val.Cmp(g.max) > 0 {
		// If out of range, return min
		return g.min.Clone()
	}

	return val
}

// Int256 generates random int256 values across the full int256 range [-2^255, 2^255-1]
//
// Example:
//   Int256() generates values from min int256 to max int256
func Int256() *Generator {
	// Max int256: 2^255 - 1
	// Min int256: -2^255
	minStr := "-57896044618658097711785492504343953926634992332820282019728792003956564819968"
	maxStr := "57896044618658097711785492504343953926634992332820282019728792003956564819967"
	min, _ := int256.FromDecimal(minStr)
	max, _ := int256.FromDecimal(maxStr)
	return newGenerator(&int256Gen{
		min: min,
		max: max,
	})
}

// Int256Max generates int256 values from min int256 to the specified max
// max: maximum value as decimal string
//
// Example:
//   Int256Max("1000000") generates values from min int256 to 1000000
func Int256Max(max string) *Generator {
	maxVal, err := int256.FromDecimal(max)
	if err != nil {
		maxVal = int256.NewInt(1000000)
	}
	minStr := "-57896044618658097711785492504343953926634992332820282019728792003956564819968"
	minVal, _ := int256.FromDecimal(minStr)
	return newGenerator(&int256Gen{
		min: minVal,
		max: maxVal,
	})
}

// Int256Range generates int256 values within a specified range [min, max]
// min and max are decimal strings
//
// Example:
//   Int256Range("-1000", "999999") generates values between -1000 and 999999
func Int256Range(minStr, maxStr string) *Generator {
	min, err := int256.FromDecimal(minStr)
	if err != nil {
		min = int256.NewInt(0)
	}

	max, err := int256.FromDecimal(maxStr)
	if err != nil {
		max = int256.NewInt(1000000)
	}

	return newGenerator(&int256Gen{
		min: min,
		max: max,
	})
}

// Int256Min generates int256 values from the specified min to max int256
// min: minimum value as decimal string
//
// Example:
//   Int256Min("-1000") generates values from -1000 to max int256
func Int256Min(min string) *Generator {
	minVal, err := int256.FromDecimal(min)
	if err != nil {
		minVal = int256.NewInt(0)
	}
	maxStr := "57896044618658097711785492504343953926634992332820282019728792003956564819967"
	maxVal, _ := int256.FromDecimal(maxStr)
	return newGenerator(&int256Gen{
		min: minVal,
		max: maxVal,
	})
}
