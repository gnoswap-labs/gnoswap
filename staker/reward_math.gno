package staker

import "gno.land/p/demo/ufmt"

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
	// requireUnsigned(totalRewardUnclaimed, ufmt.Sprintf("[STAKER] reward_math.gno__RewardMathComputeRewardAmount() || totalRewardUnclaimed(%s) must be positive", totalRewardUnclaimed))
	// requireUnsigned(totalSecondsClaimedX128, ufmt.Sprintf("[STAKER] reward_math.gno__RewardMathComputeRewardAmount() || totalSecondsClaimedX128(%s) must be positive", totalSecondsClaimedX128))
	requireUnsigned(startTime, ufmt.Sprintf("[STAKER] reward_math.gno__RewardMathComputeRewardAmount() || startTime(%s) must be positive", startTime))
	requireUnsigned(endTime, ufmt.Sprintf("[STAKER] reward_math.gno__RewardMathComputeRewardAmount() || endTime(%s) must be positive", endTime))
	requireUnsigned(liquidity, ufmt.Sprintf("[STAKER] reward_math.gno__RewardMathComputeRewardAmount() || liquidity(%s) must be positive", liquidity))
	requireUnsigned(secondsPerLiquidityInsideInitialX128, ufmt.Sprintf("[STAKER] reward_math.gno__RewardMathComputeRewardAmount() || secondsPerLiquidityInsideInitialX128(%s) must be positive", secondsPerLiquidityInsideInitialX128))
	requireUnsigned(secondsPerLiquidityInsideX128, ufmt.Sprintf("[STAKER] reward_math.gno__RewardMathComputeRewardAmount() || secondsPerLiquidityInsideX128(%s) must be positive", secondsPerLiquidityInsideX128))

	require(currentTime >= startTime, ufmt.Sprintf("[STAKER] reward_math.gno__RewardMathComputeRewardAmount() || current time must be after start time__currentTime(%s) >= startTime(%s)", currentTime, startTime))

	// XXX secondsInsideX128 = (secondsPerLiquidityInsideX128 - secondsPerLiquidityInsideInitialX128) * liquidity
	secondsInsideX128 = (secondsPerLiquidityInsideX128 - secondsPerLiquidityInsideInitialX128)
	// totalSecondsUnclaimedX128 := ((max(endTime, currentTime) - startTime) << 128) - totalSecondsClaimedX128
	// reward = (totalRewardUnclaimed * secondsInsideX128) / totalSecondsUnclaimedX128

	// requireUnsigned(reward, ufmt.Sprintf("[STAKER] reward_math.gno__RewardMathComputeRewardAmount() || reward(%s) must be positive", reward))
	// requireUnsigned(secondsInsideX128, ufmt.Sprintf("[STAKER] reward_math.gno__RewardMathComputeRewardAmount() || secondsInsideX128(%s) must be positive", secondsInsideX128))

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
