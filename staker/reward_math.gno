package staker

import "gno.land/p/demo/ufmt"

func rewardMathComputeRewardAmount(
	// totalRewardUnclaimed bigint,
	// totalSecondsClaimedX128 bigint,
	startTime bigint,
	endTime bigint,
	liquidity bigint,
	secondsPerLiquidityInsideInitialX128 bigint,
	secondsPerLiquidityInsideX128 bigint,
	currentTime bigint,
) (reward, secondsInsideX128 bigint) {
	// requireUnsigned(totalRewardUnclaimed, ufmt.Sprintf("[STAKER] reward_math.gno__rewardMathComputeRewardAmount() || totalRewardUnclaimed(%s) >= 0", totalRewardUnclaimed))
	// requireUnsigned(totalSecondsClaimedX128, ufmt.Sprintf("[STAKER] reward_math.gno__rewardMathComputeRewardAmount() || totalSecondsClaimedX128(%s) >= 0", totalSecondsClaimedX128))
	requireUnsigned(startTime, ufmt.Sprintf("[STAKER] reward_math.gno__rewardMathComputeRewardAmount() || startTime(%s) >= 0", startTime))
	requireUnsigned(endTime, ufmt.Sprintf("[STAKER] reward_math.gno__rewardMathComputeRewardAmount() || endTime(%s) >= 0", endTime))
	requireUnsigned(liquidity, ufmt.Sprintf("[STAKER] reward_math.gno__rewardMathComputeRewardAmount() || liquidity(%s) >= 0", liquidity))
	requireUnsigned(secondsPerLiquidityInsideInitialX128, ufmt.Sprintf("[STAKER] reward_math.gno__rewardMathComputeRewardAmount() || secondsPerLiquidityInsideInitialX128(%s) >= 0", secondsPerLiquidityInsideInitialX128))
	requireUnsigned(secondsPerLiquidityInsideX128, ufmt.Sprintf("[STAKER] reward_math.gno__rewardMathComputeRewardAmount() || secondsPerLiquidityInsideX128(%s) >= 0", secondsPerLiquidityInsideX128))

	require(currentTime >= startTime, ufmt.Sprintf("[STAKER] reward_math.gno__rewardMathComputeRewardAmount() || current time must be after start time__currentTime(%s) >= startTime(%s)", currentTime, startTime))

	// XXX secondsInsideX128 = (secondsPerLiquidityInsideX128 - secondsPerLiquidityInsideInitialX128) * liquidity
	secondsInsideX128 = (secondsPerLiquidityInsideX128 - secondsPerLiquidityInsideInitialX128)
	// totalSecondsUnclaimedX128 := ((max(endTime, currentTime) - startTime) << 128) - totalSecondsClaimedX128
	// reward = (totalRewardUnclaimed * secondsInsideX128) / totalSecondsUnclaimedX128

	// requireUnsigned(reward, ufmt.Sprintf("[STAKER] reward_math.gno__rewardMathComputeRewardAmount() || reward(%s) >= 0", reward))
	// requireUnsigned(secondsInsideX128, ufmt.Sprintf("[STAKER] reward_math.gno__rewardMathComputeRewardAmount() || secondsInsideX128(%s) >= 0", secondsInsideX128))

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
