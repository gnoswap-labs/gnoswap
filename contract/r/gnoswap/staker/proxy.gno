package staker

// StakeToken stakes a position.
//
// Parameters:
//   - positionId: The ID of the position to stake.
//   - referrer: The referrer address for reward tracking.
//
// Returns:
//   - poolPath: The path of the pool that the position exists.
func StakeToken(cur realm, positionId uint64, referrer string) string {
	return getImplementation().StakeToken(positionId, referrer)
}

// UnStakeToken unstakes a position.
//
// Parameters:
//   - positionId: The ID of the position to unstake.
//   - unwrapResult: Whether to unwrap WGNOT to GNOT.
//
// Returns:
//   - poolPath: The path of the pool that the position will be unstaked from.
func UnStakeToken(cur realm, positionId uint64, unwrapResult bool) string {
	return getImplementation().UnStakeToken(positionId, unwrapResult)
}

// MintAndStake mints and stakes an LP token.
//
// Parameters:
//   - token0: The path of token0.
//   - token1: The path of token1.
//   - fee: The fee tier of the pool.
//   - tickLower: The lower tick of the price range of the position.
//   - tickUpper: The upper tick of the price range of the position.
//   - amount0Desired: The maximum amount of token0 to add and stake.
//   - amount1Desired: The maximum amount of token1 to add and stake.
//   - amount0Min: The minimum amount of token0 to add and stake.
//   - amount1Min: The minimum amount of token1 to add and stake.
//   - deadline: The deadline at which the transaction will expire.
//   - referrer: The referrer address for reward tracking.
//
// Returns:
//   - positionId: The ID of the position to be created and staked.
//   - liquidity: The liquidity amount of the position.
//   - amount0: The amount of token0 to be staked.
//   - amount1: The amount of token1 to be staked.
//   - poolPath: The path of the pool that the position will be created and staked in.
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

// CollectReward collects staking rewards accrued to a position.
//
// Parameters:
//   - positionId: The ID of the position to collect incentives from.
//   - unwrapResult: (if position has wugnot fee) whether to receive reward in ugnot or not.
//
// Returns:
//   - poolPath: The path of the pool that the position exists.
//   - stakeDetail: The staking details.
//   - internalRewards: The internal rewards.
//   - externalRewards: The external rewards.
func CollectReward(cur realm, positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	return getImplementation().CollectReward(positionId, unwrapResult)
}

// SetPoolTier sets the reward tier for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//   - tier: reward tier level
func SetPoolTier(cur realm, poolPath string, tier uint64) {
	getImplementation().SetPoolTier(poolPath, tier)
}

// ChangePoolTier changes the reward tier of a pool.
//
// Parameters:
//   - poolPath: path of the pool
//   - tier: new reward tier level
func ChangePoolTier(cur realm, poolPath string, tier uint64) {
	getImplementation().ChangePoolTier(poolPath, tier)
}

// RemovePoolTier removes a pool from the tier system.
//
// Parameters:
//   - poolPath: path of the pool
func RemovePoolTier(cur realm, poolPath string) {
	getImplementation().RemovePoolTier(poolPath)
}

// CreateExternalIncentive creates an incentive program for a pool.
//
// Parameters:
//   - targetPoolPath: The path of the pool in which to add incentives.
//   - rewardToken: The path of the token to add as incentives.
//   - rewardAmount: The amount of tokens to add as incentives.
//   - startTimestamp: The time to start the incentive program.
//   - endTimestamp: The time to end the incentive program.
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

// EndExternalIncentive ends an incentive program.
//
// Parameters:
//   - targetPoolPath: The path of the pool to end the incentive program.
//   - incentiveId: The ID of the incentive program to end.
func EndExternalIncentive(cur realm, targetPoolPath, incentiveId string) {
	getImplementation().EndExternalIncentive(targetPoolPath, incentiveId)
}

// AddToken adds a token to the reward token whitelist.
//
// Parameters:
//   - tokenPath: path of the token to add
func AddToken(cur realm, tokenPath string) {
	getImplementation().AddToken(tokenPath)
}

// RemoveToken removes a token from the reward token whitelist.
//
// Parameters:
//   - tokenPath: path of the token to remove
func RemoveToken(cur realm, tokenPath string) {
	getImplementation().RemoveToken(tokenPath)
}

// SetWarmUp sets the warm-up period parameters for staking.
//
// Parameters:
//   - pct: warmup percentage
//   - timeDuration: warmup time duration in seconds
func SetWarmUp(cur realm, pct, timeDuration int64) {
	getImplementation().SetWarmUp(pct, timeDuration)
}

// SetDepositGnsAmount sets the amount of GNS to deposit when creating an external incentive.
//
// Parameters:
//   - amount: The amount of GNS needed to create an external incentive.
func SetDepositGnsAmount(cur realm, amount int64) {
	getImplementation().SetDepositGnsAmount(amount)
}

// SetMinimumRewardAmount sets the minimum reward amount to distribute.
//
// Parameters:
//   - amount: minimum reward amount
func SetMinimumRewardAmount(cur realm, amount int64) {
	getImplementation().SetMinimumRewardAmount(amount)
}

// SetTokenMinimumRewardAmount sets minimum reward amounts per token.
//
// Parameters:
//   - paramsStr: encoded parameters for token minimum amounts
func SetTokenMinimumRewardAmount(cur realm, paramsStr string) {
	getImplementation().SetTokenMinimumRewardAmount(paramsStr)
}

// SetUnStakingFee modifies the Unstaking Fee.
//
// Parameters:
//   - fee: The rate that will be set as the new Unstaking Fee. (the value should be in bps)
func SetUnStakingFee(cur realm, fee int64) {
	getImplementation().SetUnStakingFee(fee)
}
