package staker

// StakeToken stakes a position NFT to earn rewards.
//
// Parameters:
//   - positionId: ID of the position to stake
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - string: pool path where the position was staked
func StakeToken(cur realm, positionId uint64, referrer string) string {
	return getImplementation().StakeToken(0, cur, positionId, referrer)
}

// UnStakeToken unstakes a position NFT and creates an exit checkpoint for its rewards.
//
// The NFT is returned to its owner without calculating or paying rewards. Use a Collect* entry
// point afterward; collection of an exit checkpoint is permissionless and pays its pinned owner.
//
// Parameters:
//   - positionId: ID of the position to unstake
//
// Returns:
//   - string: pool path where the position was staked
func UnStakeToken(cur realm, positionId uint64) string {
	return getImplementation().UnStakeToken(0, cur, positionId)
}

// CollectReward collects both the GNS emission and external incentive rewards for a live staked
// deposit or an exit checkpoint left by UnStakeToken.
//
// A live-deposit collect requires the depositor/owner. An exit-checkpoint collect is permissionless
// and pays the owner pinned in the checkpoint.
//
// Parameters:
//   - positionId: staked position NFT token ID or position with an exit checkpoint
//
// Returns:
//   - string: GNS emission amount sent to the user
//   - string: GNS emission penalty amount sent to the community pool
//   - map[string]int64: gross external reward amount per reward token, before the staking-reward fee
//   - map[string]int64: external penalty amount per reward token
func CollectReward(cur realm, positionId uint64) (string, string, map[string]int64, map[string]int64) {
	emissionToUser, emissionPenalty, externalRewards, externalPenalties := getImplementation().CollectReward(0, cur, positionId)
	return emissionToUser, emissionPenalty, cloneStringInt64Map(externalRewards), cloneStringInt64Map(externalPenalties)
}

// CollectEmissionReward collects only the GNS emission reward for a live staked deposit or an exit
// checkpoint left by UnStakeToken.
//
// A live-deposit collect requires the depositor/owner. An exit-checkpoint collect is permissionless
// and pays the owner pinned in the checkpoint.
//
// External incentive rewards keep accruing; collect them with CollectExternalIncentiveReward.
//
// Parameters:
//   - positionId: staked position NFT token ID or position with an exit checkpoint
//
// Returns:
//   - int64: GNS emission amount sent to the user
//   - int64: GNS emission penalty amount sent to the community pool
func CollectEmissionReward(cur realm, positionId uint64) (int64, int64) {
	return getImplementation().CollectEmissionReward(0, cur, positionId)
}

// CollectExternalIncentiveReward collects one external incentive reward for a live staked deposit
// or an exit checkpoint left by UnStakeToken.
//
// A live-deposit collect requires the depositor/owner. An exit-checkpoint collect is permissionless
// and pays the owner pinned in the checkpoint.
//
// The GNS emission reward and every other incentive keep accruing; collect the emission reward with
// CollectEmissionReward and the other incentives by calling this with their own incentive id.
//
// Parameters:
//   - positionId: staked position NFT token ID or position with an exit checkpoint
//   - incentiveId: ID of the external incentive to collect
//
// Returns:
//   - int64: gross reward amount before the staking-reward fee
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
//   - rewardAmount: total reward amount in token units
//   - startTimestamp: incentive start time in Unix seconds
//   - endTimestamp: incentive end time in Unix seconds
//
// Any caller may create an incentive after satisfying the token, duration, start-time,
// reward-minimum, and GNS-deposit checks.
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

// EndExternalIncentive finalizes an external incentive once its end timestamp has passed,
// sending the unclaimable/remainder reward portion and GNS deposit to the explicit refundAddress.
// Only the incentive creator or admin may call it; an outstanding exit checkpoint for this
// incentive must be collected or forfeited first.
func EndExternalIncentive(cur realm, targetPoolPath, incentiveId string, refundAddress address) {
	getImplementation().EndExternalIncentive(0, cur, targetPoolPath, incentiveId, refundAddress)
}

// CancelExternalIncentive cancels an external incentive that has not started yet,
// removing it and refunding the reward tokens and the GNS deposit to the creator.
// Callable by admin, governance, or the incentive creator.
func CancelExternalIncentive(cur realm, targetPoolPath, incentiveId string) {
	getImplementation().CancelExternalIncentive(0, cur, targetPoolPath, incentiveId)
}

// CollectExternalIncentivePenalty collects accumulated warmup penalties after
// EndExternalIncentive has finalized the incentive, sending them to refundAddress.
// Only the incentive creator or admin may call it.
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

// SetDeniedRewardToken sets or clears the operational deny flag for an external
// incentive reward token. Pool-pair tokens qualify as reward tokens without the
// governance allowlist (by design), so this flag is the only lever to stop NEW
// incentives in a pair token whose issuer turned hostile. Existing incentives
// and their collection are deliberately unaffected; the ledger-level delivery
// guard in the implementation bounds their blast radius instead.
func SetDeniedRewardToken(cur realm, tokenPath string, denied bool) {
	getImplementation().SetDeniedRewardToken(0, cur, tokenPath, denied)
}

// SetWarmUp configures the duration for the warm-up tier selected by its fixed ratio.
// Finite tiers are capped at 365 days; the final 100% tier must retain math.MaxInt64.
func SetWarmUp(cur realm, pct, timeDuration int64) {
	getImplementation().SetWarmUp(0, cur, pct, timeDuration)
}

// SetDepositGnsAmount sets the GNS deposit required for each external incentive.
func SetDepositGnsAmount(cur realm, amount int64) {
	getImplementation().SetDepositGnsAmount(0, cur, amount)
}

// SetMinimumRewardAmount sets the default minimum reward amount required to create an external
// incentive. A token-specific override may apply.
func SetMinimumRewardAmount(cur realm, amount int64) {
	getImplementation().SetMinimumRewardAmount(0, cur, amount)
}

// SetTokenMinimumRewardAmount sets minimum reward amounts per token.
func SetTokenMinimumRewardAmount(cur realm, paramsStr string) {
	getImplementation().SetTokenMinimumRewardAmount(0, cur, paramsStr)
}

// SetUnStakingFee sets the unstaking fee rate in basis points (0-1,000; 100 = 1%).
func SetUnStakingFee(cur realm, fee uint64) {
	getImplementation().SetUnStakingFee(0, cur, fee)
}
