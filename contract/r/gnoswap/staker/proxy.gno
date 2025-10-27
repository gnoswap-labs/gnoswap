package staker

func StakeToken(cur realm, positionId uint64, referrer string) string {
	return getImplementation().StakeToken(positionId, referrer)
}

func UnStakeToken(cur realm, positionId uint64, unwrapResult bool) string {
	return getImplementation().UnStakeToken(positionId, unwrapResult)
}

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

func CollectReward(cur realm, positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	return getImplementation().CollectReward(positionId, unwrapResult)
}

func SetPoolTier(cur realm, poolPath string, tier uint64) {
	getImplementation().SetPoolTier(poolPath, tier)
}

func ChangePoolTier(cur realm, poolPath string, tier uint64) {
	getImplementation().ChangePoolTier(poolPath, tier)
}

func RemovePoolTier(cur realm, poolPath string) {
	getImplementation().RemovePoolTier(poolPath)
}

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

func EndExternalIncentive(cur realm, targetPoolPath, incentiveId string) {
	getImplementation().EndExternalIncentive(targetPoolPath, incentiveId)
}

func AddToken(cur realm, tokenPath string) {
	getImplementation().AddToken(tokenPath)
}

func RemoveToken(cur realm, tokenPath string) {
	getImplementation().RemoveToken(tokenPath)
}

func SetWarmUp(cur realm, pct, timeDuration int64) {
	getImplementation().SetWarmUp(pct, timeDuration)
}

func SetDepositGnsAmount(cur realm, amount int64) {
	getImplementation().SetDepositGnsAmount(amount)
}

func SetMinimumRewardAmount(cur realm, amount int64) {
	getImplementation().SetMinimumRewardAmount(amount)
}

func SetTokenMinimumRewardAmount(cur realm, paramsStr string) {
	getImplementation().SetTokenMinimumRewardAmount(paramsStr)
}

func SetUnStakingFee(cur realm, fee int64) {
	getImplementation().SetUnStakingFee(fee)
}
