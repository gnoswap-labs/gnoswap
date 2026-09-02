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

// UnStakeToken unstakes a position NFT and settles its rewards into the claimable ledger.
//
// The settled rewards are NOT transferred here; withdraw them with ClaimRewards. Keeping
// payout out of this path is what guarantees a position can always be withdrawn, even when
// a reward transfer would fail.
//
// Parameters:
//   - positionId: ID of the position to unstake
//
// Returns:
//   - string: pool path the position was staked in
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

// ClaimRewards pays out every reward that has already been settled for the caller.
//
// Rewards are settled into the claimable ledger by CollectReward and by UnStakeToken. This
// is the withdrawal half, and it needs no staked position: a position can be unstaked
// first and its rewards claimed afterwards.
//
// Returns the amount paid per token path.
func ClaimRewards(cur realm) map[string]int64 {
	return cloneStringInt64Map(getImplementation().ClaimRewards(0, cur))
}

// ClaimRewardsFor pays out receiver's settled rewards to receiver.
//
// Permissionless: the funds only ever reach the ledger owner. It exists so anyone can flush
// the community pool's share (internal penalties and unclaimable rewards) after positions
// are unstaked without collecting.
//
// Returns the amount paid per token path.
func ClaimRewardsFor(cur realm, receiver address) map[string]int64 {
	return cloneStringInt64Map(getImplementation().ClaimRewardsFor(0, cur, receiver))
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
