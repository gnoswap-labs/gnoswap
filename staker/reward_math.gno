package staker

import (
	"std"
)

func StakerComputeRewardAmount(
	totalRewardUnclaimed bigdec,
	totalSecondsClaimed bigdec,
	startTime uint64,
	endTime uint64,
	liquidity bigdec,
	secondsPerLiquidityInsideInitial bigdec,
	secondsPerLiquidityInside bigdec,
	currentTime uint64,
) (bigdec, bigdec) {
	require(currentTime < endTime, "Staker: current time is after end time")

	secondsInside = (secondsPerLiquidityInside - secondsPerLiquidityInsideInitial) * liquidity
	totalSecondsUnclaimed = ((max(endTime, currentTime) - startTime) << 128) - totalSecondsClaimed

	reward := totalRewardUnclaimed * secondsInside / totalSecondsUnclaimed
}

func max(a, b bigdec) bigdec {
	if a > b {
		return a
	}
	return b
}