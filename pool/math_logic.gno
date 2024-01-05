package pool

// get sqrtX96 from tick
func GetSqrtRatioFromTick(
	tick int32,
) bigint {
	return TickMathGetSqrtRatioAtTick(tick)
}

// get tick from sqrtX96
func GetTickFromSqrtRatio(
	sqrtX96 bigint,
) int32 {
	return TickMathGetTickAtSqrtRatio(sqrtX96)
}
