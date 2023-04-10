package gnoswap

import (
	"internal/big"
)

const (
	MIN_TICK bigint = -887272
	MAX_TICK bigint = 887272

	// MIN_SQRT_RATIO bigdec = 4295128739
	MIN_SQRT_RATIO bigdec = 5.4212146321E-20
	// MAX_SQRT_RATIO bigdec = 1461446703485210103287273052203988822378723970342
	MAX_SQRT_RATIO bigdec = 18446050711097703530.3140340022

	POINT bigdec = 1.001
)


func TickMathGetSqrtRatioAtTick(tick bigint) (bigdec) {
	var absTick = big.Abs(tick)
	require(absTick <= MAX_TICK, "T")
	
	var tickPow bigdec = big.Pow(POINT, bigdec(tick))
	sqrtPrice := big.Sqrt(tickPow)
	return bigdec(sqrtPrice)
}

func TickMathGetTickAtSqrtRatio(sqrtPrice bigdec) (tick bigdec) {
	require(sqrtPrice >= MIN_SQRT_RATIO && sqrtPrice < MAX_SQRT_RATIO, "R")

	x := sqrtPrice * sqrtPrice
	tick = big.Log10(x) / big.Log10(POINT)
	return tick
}