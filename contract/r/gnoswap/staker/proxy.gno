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
//   - unwrapResult: whether to unwrap WGNOT to GNOT
//
// Returns:
//   - string: collected reward details
func UnStakeToken(cur realm, positionId uint64, unwrapResult bool) string {
	return getImplementation().UnStakeToken(positionId, unwrapResult)
}

// MintAndStake creates a new position and immediately stakes it.
//
// Parameters:
//   - token0: path of the first token
//   - token1: path of the second token
//   - fee: pool fee tier
//   - tickLower: lower tick boundary
//   - tickUpper: upper tick boundary
//   - amount0Desired: desired amount of token0
//   - amount1Desired: desired amount of token1
//   - amount0Min: minimum amount of token0
//   - amount1Min: minimum amount of token1
//   - deadline: transaction deadline
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - uint64: position ID
//   - string: liquidity amount
//   - string: amount of token0 added
//   - string: amount of token1 added
//   - string: staking details
func MintAndStake(
	cur realm,
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string,
	amount1Desired string,
	amount0Min string,
	amount1Min string,
	deadline int64,
	referrer string,
) (uint64, string, string, string, string) {
	return getImplementation().MintAndStake(
		token0,
		token1,
		fee,
		tickLower,
		tickUpper,
		amount0Desired,
		amount1Desired,
		amount0Min,
		amount1Min,
		deadline,
		referrer,
	)
}

// CollectReward collects accumulated rewards from a staked position.
//
// Parameters:
//   - positionId: ID of the staked position
//   - unwrapResult: whether to unwrap WGNOT to GNOT
//
// Returns:
//   - string: pool path
//   - string: staking details
//   - map[string]int64: internal rewards
//   - map[string]int64: external rewards
func CollectReward(cur realm, positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	return getImplementation().CollectReward(positionId, unwrapResult)
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

// EndExternalIncentive terminates an external incentive early.
func EndExternalIncentive(cur realm, targetPoolPath, incentiveId string) {
	getImplementation().EndExternalIncentive(targetPoolPath, incentiveId)
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

// SetDepositGnsAmount sets the required GNS deposit amount for staking.
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

// SetUnStakingFee sets the unstaking fee percentage.
func SetUnStakingFee(cur realm, fee int64) {
	getImplementation().SetUnStakingFee(fee)
}
