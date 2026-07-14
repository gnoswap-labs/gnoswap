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
	return getImplementation().StakeToken(0, cur, positionId, referrer)
}

// UnStakeToken unstakes a position NFT and collects rewards.
//
// Parameters:
//   - positionId: ID of the position to unstake
//
// Returns:
//   - string: collected reward details
func UnStakeToken(cur realm, positionId uint64) string {
	return getImplementation().UnStakeToken(0, cur, positionId)
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
	poolPath, stakingDetails, internalRewards, externalRewards := getImplementation().CollectReward(0, cur, positionId)
	return poolPath, stakingDetails, cloneStringInt64Map(internalRewards), cloneStringInt64Map(externalRewards)
}

// SetPoolTier sets the reward tier for a pool.
func SetPoolTier(cur realm, poolPath string, tier uint64) {
	getImplementation().SetPoolTier(0, cur, poolPath, tier)
}

// ChangePoolTier changes the reward tier of a pool.
func ChangePoolTier(cur realm, poolPath string, tier uint64) {
	getImplementation().ChangePoolTier(0, cur, poolPath, tier)
}

// RemovePoolTier removes a pool from the tier system.
func RemovePoolTier(cur realm, poolPath string) {
	getImplementation().RemovePoolTier(0, cur, poolPath)
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
		0,
		cur,
		targetPoolPath,
		rewardToken,
		rewardAmount,
		startTimestamp,
		endTimestamp,
	)
}

// EndExternalIncentive terminates an external incentive early.
func EndExternalIncentive(cur realm, targetPoolPath, incentiveId string, refundAddress address) {
	getImplementation().EndExternalIncentive(0, cur, targetPoolPath, incentiveId, refundAddress)
}

// CollectExternalIncentivePenalty collects accumulated warmup penalties for an ended incentive.
func CollectExternalIncentivePenalty(cur realm, targetPoolPath, incentiveId string, refundAddress address) int64 {
	return getImplementation().CollectExternalIncentivePenalty(0, cur, targetPoolPath, incentiveId, refundAddress)
}

// AddToken adds a token to the reward token whitelist.
func AddToken(cur realm, tokenPath string) {
	getImplementation().AddToken(0, cur, tokenPath)
}

// RemoveToken removes a token from the reward token whitelist.
func RemoveToken(cur realm, tokenPath string) {
	getImplementation().RemoveToken(0, cur, tokenPath)
}

// SetWarmUp sets the warm-up period parameters for staking.
func SetWarmUp(cur realm, pct, timeDuration int64) {
	getImplementation().SetWarmUp(0, cur, pct, timeDuration)
}

// SetDepositGnsAmount sets the required GNS deposit amount for staking.
func SetDepositGnsAmount(cur realm, amount int64) {
	getImplementation().SetDepositGnsAmount(0, cur, amount)
}

// SetMinimumRewardAmount sets the minimum reward amount to distribute.
func SetMinimumRewardAmount(cur realm, amount int64) {
	getImplementation().SetMinimumRewardAmount(0, cur, amount)
}

// SetTokenMinimumRewardAmount sets minimum reward amounts per token.
func SetTokenMinimumRewardAmount(cur realm, paramsStr string) {
	getImplementation().SetTokenMinimumRewardAmount(0, cur, paramsStr)
}

// SetUnStakingFee sets the unstaking fee percentage.
func SetUnStakingFee(cur realm, fee uint64) {
	getImplementation().SetUnStakingFee(0, cur, fee)
}
