package gnoswap

import (
	// "math"
	"internal/big"
)

const (
	MIN_TICK bigint = -221818
	MAX_TICK bigint = 221818

	MIN_SQRT_RATIO bigint = 0
	MAX_SQRT_RATIO bigint = 65535
	// MIN_SQRT_RATIO bigint = 5.4212146321E-20
	// MAX_SQRT_RATIO bigint = 18446050711097703530.3140340022

	POINT bigdec = 1.0001
)


func TickMathGetSqrtRatioAtTick(tick bigint) (bigint) {
	// absTick := int64(math.Abs(float64(tick)))
	absTick := bigint(big.Abs(bigdec(tick)))
	require(absTick <= MAX_TICK, "Tick out of range")
	
	tickPow := big.Pow(POINT, bigdec(absTick))
	sqrtPrice := big.Sqrt(tickPow)
	
	// XXX lost precision
	return bigint(big.RoundToIntegralExact(bigdec(sqrtPrice)))
	// return bigint(sqrtPrice) // orig
}

func TickMathGetTickAtSqrtRatio(sqrtPrice bigint) (bigint) {
	require(sqrtPrice >= MIN_SQRT_RATIO || sqrtPrice <= MAX_SQRT_RATIO, "Sqrt ratio out of range")

	x := sqrtPrice * sqrtPrice
	tick := big.Log10(bigdec(x)) / big.Log10(POINT)
	return bigint(tick)
}