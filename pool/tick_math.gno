package gnoswap

import (
	// "math"
	"internal/big"
)

const (
	// MIN_TICK bigint = -221818
	// MAX_TICK bigint = 221818

	// MIN_SQRT_RATIO bigint = 0
	// MAX_SQRT_RATIO bigint = 65535


	MIN_TICK bigint = -887272
	MAX_TICK bigint = 887272

  _MIN_SQRT_RATIO bigdec = 5.421214632141317e-20 
	_MAX_SQRT_RATIO bigdec = 1.8446050711097704e+19

	MIN_SQRT_RATIO bigint = big.RoundToIntegralExact(_MIN_SQRT_RATIO) // 0
	MAX_SQRT_RATIO bigint = big.RoundToIntegralExact(_MAX_SQRT_RATIO) // 18446050711097704000

	// US ORIG WITH Q96
	// MIN_SQRT_RATIO bigint = 4295128739 // same as TickMathGetSqrtRatioAtTick(MIN_TICK)
	// MAX_SQRT_RATIO bigint = 1461446703485210103287273052203988822378723970342 // same as TickMathGetSqrtRatioAtTick(MAX_TICK)

	POINT bigdec = 1.0001
)


func TickMathGetSqrtRatioAtTick(tick bigint) (bigint) {
	// absTick := int64(math.Abs(float64(tick)))
	absTick := bigint(big.Abs(bigdec(tick)))
	require(absTick <= MAX_TICK, "Tick out of range")
	
	// tickPow := big.Pow(POINT, bigdec(absTick))
	tickPow := big.Pow(POINT, bigdec(tick))
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