package staker

func RewardMathComputeRewardAmount(
	// totalRewardUnclaimed bigint,
	// totalSecondsClaimedX128 bigint,
	startTime bigint,
	endTime bigint,
	liquidity bigint,
	secondsPerLiquidityInsideInitialX128 bigint,
	secondsPerLiquidityInsideX128 bigint,
	currentTime bigint,
) (reward, secondsInsideX128 bigint) {
	// requireUnsigned(totalRewardUnclaimed, "GnoswapStaker::computeRewardAmount: total reward unclaimed is not unsigned")
	// requireUnsigned(totalSecondsClaimedX128, "GnoswapStaker::computeRewardAmount: total seconds claimed is not unsigned")
	requireUnsigned(startTime, "GnoswapStaker::computeRewardAmount: start time is not unsigned")
	requireUnsigned(endTime, "GnoswapStaker::computeRewardAmount: end time is not unsigned")
	requireUnsigned(liquidity, "GnoswapStaker::computeRewardAmount: liquidity is not unsigned")
	requireUnsigned(secondsPerLiquidityInsideInitialX128, "GnoswapStaker::computeRewardAmount: seconds per liquidity inside initial is not unsigned")
	requireUnsigned(secondsPerLiquidityInsideX128, "GnoswapStaker::computeRewardAmount: seconds per liquidity inside is not unsigned")

	require(currentTime >= startTime, "GnoswapStaker::computeRewardAmount: current time must be after start time")

	// XXX secondsInsideX128 = (secondsPerLiquidityInsideX128 - secondsPerLiquidityInsideInitialX128) * liquidity
	secondsInsideX128 = (secondsPerLiquidityInsideX128 - secondsPerLiquidityInsideInitialX128)
	// totalSecondsUnclaimedX128 := ((max(endTime, currentTime) - startTime) << 128) - totalSecondsClaimedX128
	// reward = (totalRewardUnclaimed * secondsInsideX128) / totalSecondsUnclaimedX128

	// requireUnsigned(reward, "GnoswapStaker::computeRewardAmount: reward is not unsigned")
	// requireUnsigned(secondsInsideX128, "GnoswapStaker::computeRewardAmount: seconds inside is not unsigned")

	// secondsInsideX128 not used here
	reward = liquidity
	return reward, secondsInsideX128
}

func max(a, b bigint) bigint {
	if a > b {
		return a
	}
	return b
}
