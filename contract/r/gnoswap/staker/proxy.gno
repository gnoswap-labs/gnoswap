package staker

// StakeToken stakes a position NFT to earn rewards.
//
// Parameters:
//   - positionId: ID of the position to stake
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - string: deposit ID
func StakeToken(cur realm, positionId uint64, referrer string) string {
	return getImplementation().StakeToken(positionId, referrer)
}

// UnStakeToken unstakes a position NFT and collects rewards.
//
// Parameters:
//   - positionId: ID of the position to unstake
//
// Returns:
//   - string: pool path of the unstaked position
func UnStakeToken(cur realm, positionId uint64) string {
	return getImplementation().UnStakeToken(positionId)
}

// CollectReward collects accumulated rewards from a staked position.
//
// Parameters:
//   - positionId: ID of the staked position
//
// Returns:
//   - string: pool path
//   - string: staking details
//   - map[string]int64: internal rewards
//   - map[string]int64: external rewards
func CollectReward(cur realm, positionId uint64) (string, string, map[string]int64, map[string]int64) {
	poolPath, stakingDetails, internalRewards, externalRewards := getImplementation().CollectReward(positionId)
	return poolPath, stakingDetails, cloneStringInt64Map(internalRewards), cloneStringInt64Map(externalRewards)
}

// SetPoolTier sets the reward tier for a pool.
func SetPoolTier(cur realm, poolPath string, tier uint64) {
	getImplementation().SetPoolTier(poolPath, tier)
}

// ChangePoolTier changes the reward tier of a pool.
func ChangePoolTier(cur realm, poolPath string, tier uint64) {
	getImplementation().ChangePoolTier(poolPath, tier)
}

// RemovePoolTier removes a pool from the tier system.
func RemovePoolTier(cur realm, poolPath string) {
	getImplementation().RemovePoolTier(poolPath)
}

// CreateExternalIncentive creates an external reward incentive for a pool.
//
// Parameters:
//   - targetPoolPath: pool to incentivize
//   - rewardToken: token to use as reward
//   - rewardAmount: total reward amount
//   - startTimestamp: incentive start time
//   - endTimestamp: incentive end time
func CreateExternalIncentive(
	cur realm,
	targetPoolPath string,
	rewardToken string,
	rewardAmount int64,
	startTimestamp int64,
	endTimestamp int64,
) {
	getImplementation().CreateExternalIncentive(
		targetPoolPath,
		rewardToken,
		rewardAmount,
		startTimestamp,
		endTimestamp,
	)
}

// EndExternalIncentive ends an external incentive after it becomes terminable and refunds remaining rewards to the provided refund address.
func EndExternalIncentive(cur realm, targetPoolPath, incentiveId string, refundAddress address) {
	getImplementation().EndExternalIncentive(targetPoolPath, incentiveId, refundAddress)
}

// CollectExternalIncentivePenalty collects accumulated warmup penalties for an ended incentive.
func CollectExternalIncentivePenalty(cur realm, targetPoolPath, incentiveId string, refundAddress address) int64 {
	return getImplementation().CollectExternalIncentivePenalty(targetPoolPath, incentiveId, refundAddress)
}

// AddToken adds a token to the reward token whitelist.
func AddToken(cur realm, tokenPath string) {
	getImplementation().AddToken(tokenPath)
}

// RemoveToken removes a token from the reward token whitelist.
func RemoveToken(cur realm, tokenPath string) {
	getImplementation().RemoveToken(tokenPath)
}

// SetWarmUp sets the warm-up period parameters for staking.
func SetWarmUp(cur realm, pct, timeDuration int64) {
	getImplementation().SetWarmUp(pct, timeDuration)
}

// SetDepositGnsAmount sets the required GNS deposit amount for creating an external incentive.
func SetDepositGnsAmount(cur realm, amount int64) {
	getImplementation().SetDepositGnsAmount(amount)
}

// SetMinimumRewardAmount sets the minimum reward amount to distribute.
func SetMinimumRewardAmount(cur realm, amount int64) {
	getImplementation().SetMinimumRewardAmount(amount)
}

// SetTokenMinimumRewardAmount sets minimum reward amounts per token.
func SetTokenMinimumRewardAmount(cur realm, paramsStr string) {
	getImplementation().SetTokenMinimumRewardAmount(paramsStr)
}

// SetUnStakingFee sets the unstaking fee percentage in basis points.
func SetUnStakingFee(cur realm, fee uint64) {
	getImplementation().SetUnStakingFee(fee)
}
