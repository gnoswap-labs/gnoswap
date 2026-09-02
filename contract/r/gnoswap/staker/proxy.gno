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

// CollectReward collects both the GNS emission and the external incentive rewards of a staked position.
//
// Parameters:
//   - positionId: ID of the staked position
//
// Returns:
//   - string: GNS emission amount sent to the user
//   - string: GNS emission penalty amount sent to the community pool
//   - map[string]int64: external reward amount per reward token
//   - map[string]int64: external penalty amount per reward token
func CollectReward(cur realm, positionId uint64) (string, string, map[string]int64, map[string]int64) {
	emissionToUser, emissionPenalty, externalRewards, externalPenalties := getImplementation().CollectReward(0, cur, positionId)
	return emissionToUser, emissionPenalty, cloneStringInt64Map(externalRewards), cloneStringInt64Map(externalPenalties)
}

// CollectEmissionReward collects only the GNS emission reward of a staked position.
//
// External incentive rewards keep accruing; collect them with CollectExternalIncentiveReward.
//
// Parameters:
//   - positionId: ID of the staked position
//
// Returns:
//   - int64: GNS emission amount sent to the user
//   - int64: GNS emission penalty amount sent to the community pool
func CollectEmissionReward(cur realm, positionId uint64) (int64, int64) {
	return getImplementation().CollectEmissionReward(0, cur, positionId)
}

// CollectExternalIncentiveReward collects one external incentive reward of a staked position.
//
// The GNS emission reward and every other incentive keep accruing; collect the emission reward with
// CollectEmissionReward and the other incentives by calling this with their own incentive id.
//
// Parameters:
//   - positionId: ID of the staked position
//   - incentiveId: ID of the external incentive to collect
//
// Returns:
//   - int64: reward amount sent to the user
//   - int64: penalty amount kept by the incentive
func CollectExternalIncentiveReward(cur realm, positionId uint64, incentiveId string) (int64, int64) {
	return getImplementation().CollectExternalIncentiveReward(0, cur, positionId, incentiveId)
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

// EndExternalIncentive finalizes an external incentive once its end timestamp
// has passed, refunding unclaimable rewards and the GNS deposit.
func EndExternalIncentive(cur realm, targetPoolPath, incentiveId string, refundAddress address) {
	getImplementation().EndExternalIncentive(0, cur, targetPoolPath, incentiveId, refundAddress)
}

// CancelExternalIncentive cancels an external incentive that has not started yet,
// removing it and refunding the reward tokens and the GNS deposit to the creator.
// Callable by admin, governance, or the incentive creator.
func CancelExternalIncentive(cur realm, targetPoolPath, incentiveId string) {
	getImplementation().CancelExternalIncentive(0, cur, targetPoolPath, incentiveId)
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
